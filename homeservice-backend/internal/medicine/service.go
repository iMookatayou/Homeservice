// internal/medicine/service.go
package medicine

import (
	"context"
	"sort"
	"time"
)

// Service หุ้ม business logic ทั้งหมดของโมดูลยา
type Service struct {
	Repo Repo
	Now  func() time.Time
}

// ---------- Item ----------

func (s *Service) CreateItem(ctx context.Context, it *MedicineItem) error {
	if it == nil || it.Name == "" || it.Unit == "" || it.HouseholdID == "" {
		return ErrBadInput
	}
	// normalize เบื้องต้น
	it.IsArchived = false
	if it.CreatedAt.IsZero() {
		it.CreatedAt = s.Now()
	}
	it.UpdatedAt = it.CreatedAt
	return s.Repo.CreateItem(ctx, it)
}

func (s *Service) ListItems(ctx context.Context, householdID string, f ListItemFilter) ([]ItemSummary, error) {
	items, err := s.Repo.ListItems(ctx, householdID, f)
	if err != nil {
		return nil, err
	}
	// ติด flag low_stock / expiring ตาม alert (คำนวณฝั่ง service)
	for i := range items {
		al, _ := s.Repo.GetAlert(ctx, items[i].Item.ID)
		if al == nil || !al.IsEnabled {
			continue
		}
		if al.MinQty != nil && items[i].TotalQty < *al.MinQty {
			items[i].LowStock = true
		}
		if al.ExpiryWindowDays != nil && items[i].NextExpiry != nil {
			ddl := s.Now().AddDate(0, 0, *al.ExpiryWindowDays)
			if !items[i].NextExpiry.After(ddl) {
				items[i].Expiring = true
			}
		}
	}
	return items, nil
}

func (s *Service) GetItemFull(ctx context.Context, householdID, itemID string) (*ItemDetail, error) {
	it, err := s.Repo.GetItem(ctx, householdID, itemID)
	if err != nil {
		return nil, err
	}
	bs, err := s.Repo.GetBatchesByItem(ctx, itemID)
	if err != nil {
		return nil, err
	}
	var total float64
	var next *time.Time
	for _, b := range bs {
		total += b.Qty
		if b.Expiry != nil {
			if next == nil || b.Expiry.Before(*next) {
				nb := *b.Expiry
				next = &nb
			}
		}
	}
	al, _ := s.Repo.GetAlert(ctx, itemID)
	return &ItemDetail{
		Item:       *it,
		Batches:    bs,
		TotalQty:   total,
		NextExpiry: next,
		Alert:      al,
	}, nil
}

func (s *Service) UpdateItemPartial(ctx context.Context, householdID, id string, patch map[string]any) error {
	it, err := s.Repo.GetItem(ctx, householdID, id)
	if err != nil {
		return err
	}
	if v, ok := patch["name"].(string); ok && v != "" {
		it.Name = v
	}
	if v, ok := patch["generic_name"].(string); ok {
		it.GenericName = &v
	}
	if v, ok := patch["form"].(string); ok && v != "" {
		it.Form = Form(v)
	}
	if v, ok := patch["strength"].(string); ok {
		it.Strength = &v
	}
	if v, ok := patch["category"].(string); ok {
		it.Category = &v
	}
	if v, ok := patch["location_id"].(string); ok {
		it.LocationID = &v
	}
	if v, ok := patch["gtin"].(string); ok {
		it.GTIN = &v
	}
	if v, ok := patch["notes"].(string); ok {
		it.Notes = &v
	}
	it.UpdatedAt = s.Now()
	return s.Repo.UpdateItem(ctx, it)
}

func (s *Service) ArchiveItem(ctx context.Context, householdID, id string) error {
	return s.Repo.ArchiveItem(ctx, householdID, id)
}

// ---------- Batch ----------

func (s *Service) AddBatch(ctx context.Context, householdID string, b *MedicineBatch) error {
	if b == nil || b.ItemID == "" {
		return ErrBadInput
	}
	it, err := s.Repo.GetItem(ctx, householdID, b.ItemID)
	if err != nil {
		return err
	}
	if b.Unit == "" {
		b.Unit = it.Unit
	}
	if b.Unit != it.Unit {
		return ErrBadInput // ไม่ให้ unit ไม่ตรงกับ item
	}
	if b.Qty < 0 {
		return ErrBadInput
	}
	if b.CreatedAt.IsZero() {
		b.CreatedAt = s.Now()
	}
	b.UpdatedAt = b.CreatedAt
	return s.Repo.CreateBatch(ctx, b)
}

// ---------- Transactions ----------

// ReceiveIn: รับเข้าแบบชี้ batch ตรง ๆ
func (s *Service) ReceiveIn(ctx context.Context, itemID, batchID string, qty float64, reason *string, actor string) (map[string]any, error) {
	if qty <= 0 {
		return nil, ErrBadInput
	}
	t := &MedicineTxn{
		ItemID:    itemID,
		BatchID:   &batchID,
		ActorID:   actor,
		Type:      TxnIn,
		QtyChange: qty, // บวกเข้า
		Reason:    reason,
		CreatedAt: s.Now(),
	}
	if err := s.Repo.ApplyTxnAdjustQty(ctx, t); err != nil {
		return nil, err
	}
	return map[string]any{"txn": t}, nil
}

// Adjust: ปรับยอดจากการตรวจนับ (±delta) แบบชี้ batch
func (s *Service) Adjust(ctx context.Context, itemID, batchID string, delta float64, reason *string, actor string) (map[string]any, error) {
	if delta == 0 {
		return nil, ErrBadInput
	}
	t := &MedicineTxn{
		ItemID:    itemID,
		BatchID:   &batchID,
		ActorID:   actor,
		Type:      TxnAdjust,
		QtyChange: delta, // อาจเป็นบวกหรือลบ
		Reason:    reason,
		CreatedAt: s.Now(),
	}
	if err := s.Repo.ApplyTxnAdjustQty(ctx, t); err != nil {
		return nil, err
	}
	return map[string]any{"txn": t}, nil
}

// UseOut: เบิก/ใช้ โดยไม่ต้องชี้ batch -> FEFO (First-Expire-First-Out)
func (s *Service) UseOut(ctx context.Context, itemID string, qty float64, reason *string, actor string) (map[string]any, error) {
	if qty <= 0 {
		return nil, ErrBadInput
	}
	batches, err := s.Repo.GetBatchesByItem(ctx, itemID)
	if err != nil {
		return nil, err
	}
	if len(batches) == 0 {
		return nil, ErrNoStock
	}

	// เรียง FEFO: วันหมดอายุใกล้สุดก่อน, ถ้าไม่มีวันหมดอายุให้ไปท้าย
	sort.SliceStable(batches, func(i, j int) bool {
		if batches[i].Expiry == nil && batches[j].Expiry == nil {
			return batches[i].CreatedAt.Before(batches[j].CreatedAt)
		}
		if batches[i].Expiry == nil {
			return false
		}
		if batches[j].Expiry == nil {
			return true
		}
		return batches[i].Expiry.Before(*batches[j].Expiry)
	})

	need := qty
	affected := make([]map[string]any, 0, 3)

	for i := range batches {
		if need <= 0 {
			break
		}
		if batches[i].Qty <= 0 {
			continue
		}

		use := batches[i].Qty
		if use > need {
			use = need
		}
		delta := -use // ออกเป็นค่าลบ

		t := &MedicineTxn{
			ItemID:    itemID,
			BatchID:   &batches[i].ID,
			ActorID:   actor,
			Type:      TxnOut,
			QtyChange: delta,
			Reason:    reason,
			CreatedAt: s.Now(),
		}
		if err := s.Repo.ApplyTxnAdjustQty(ctx, t); err != nil {
			return nil, err
		}
		affected = append(affected, map[string]any{
			"batch_id":  batches[i].ID,
			"qty_delta": delta,
		})
		need -= use
	}

	if need > 0 {
		// ยังคงต้องการอีก แสดงว่า stock รวมไม่พอ → ย้อนกลับยากเพราะคอมมิตทีละ batch ไปแล้ว
		// ใน production อาจหุ้มทั้งหมดด้วยกลไกระดับ service transaction แยกอีกชั้น
		return nil, ErrNoStock
	}

	return map[string]any{"affected_batches": affected}, nil
}

// ---------- Alerts ----------

func (s *Service) SetAlert(ctx context.Context, itemID string, minQty *float64, expiryDays *int, enabled *bool) error {
	al := &MedicineAlert{
		ItemID:           itemID,
		MinQty:           minQty,
		ExpiryWindowDays: expiryDays,
		IsEnabled:        true,
		UpdatedAt:        s.Now(),
	}
	if enabled != nil {
		al.IsEnabled = *enabled
	}
	return s.Repo.UpsertAlert(ctx, al)
}
