// internal/medicine/repo.go
package medicine

import (
	"context"
	"fmt"
	"time"

	"github.com/iMookatayou/homeservice-backend/internal/db"
	"github.com/jackc/pgx/v5"
)

// Repo interface PostgreSQL
type Repo interface {
	CreateItem(ctx context.Context, it *MedicineItem) error
	GetItem(ctx context.Context, householdID, itemID string) (*MedicineItem, error)
	ListItems(ctx context.Context, householdID string, f ListItemFilter) ([]ItemSummary, error)
	UpdateItem(ctx context.Context, it *MedicineItem) error
	ArchiveItem(ctx context.Context, householdID, itemID string) error

	CreateBatch(ctx context.Context, b *MedicineBatch) error
	GetBatchesByItem(ctx context.Context, itemID string) ([]MedicineBatch, error)

	CreateTxn(ctx context.Context, t *MedicineTxn) error
	ApplyTxnAdjustQty(ctx context.Context, t *MedicineTxn) error

	CreateLocation(ctx context.Context, loc *MedicineLocation) error
	ListLocations(ctx context.Context, householdID string) ([]MedicineLocation, error)

	UpsertAlert(ctx context.Context, a *MedicineAlert) error
	GetAlert(ctx context.Context, itemID string) (*MedicineAlert, error)
}

type pgRepo struct {
	db *db.Pool
}

func NewPGRepo(pool *db.Pool) Repo {
	return &pgRepo{db: pool}
}

// ---------- Items ----------

func (r *pgRepo) CreateItem(ctx context.Context, it *MedicineItem) error {
	const q = `
	INSERT INTO medicine_items 
	(id, household_id, name, generic_name, form, strength, category, unit, location_id, gtin, photo_file_id, notes, is_archived)
	VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,false)`
	_, err := r.db.Exec(ctx, q,
		it.ID, it.HouseholdID, it.Name, it.GenericName, it.Form, it.Strength,
		it.Category, it.Unit, it.LocationID, it.GTIN, it.PhotoFileID, it.Notes)
	return err
}

func (r *pgRepo) GetItem(ctx context.Context, householdID, itemID string) (*MedicineItem, error) {
	const q = `
	SELECT id, household_id, name, generic_name, form, strength, category, unit,
	       location_id, gtin, photo_file_id, notes, is_archived, created_at, updated_at
	FROM medicine_items
	WHERE id=$1 AND household_id=$2 AND is_archived=false`
	row := r.db.QueryRow(ctx, q, itemID, householdID)

	var it MedicineItem
	if err := row.Scan(
		&it.ID, &it.HouseholdID, &it.Name, &it.GenericName, &it.Form, &it.Strength,
		&it.Category, &it.Unit, &it.LocationID, &it.GTIN, &it.PhotoFileID,
		&it.Notes, &it.IsArchived, &it.CreatedAt, &it.UpdatedAt,
	); err != nil {
		if err == pgx.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &it, nil
}

func (r *pgRepo) ListItems(ctx context.Context, householdID string, f ListItemFilter) ([]ItemSummary, error) {
	q := `
	SELECT i.id, i.household_id, i.name, i.generic_name, i.form, i.strength, i.category,
	       i.unit, i.location_id, i.gtin, i.photo_file_id, i.notes, i.is_archived,
	       i.created_at, i.updated_at,
	       COALESCE(s.total_qty,0), ne.next_expiry
	FROM medicine_items i
	LEFT JOIN v_medicine_item_stock s ON s.item_id=i.id
	LEFT JOIN v_medicine_item_next_expiry ne ON ne.item_id=i.id
	WHERE i.household_id=$1 AND i.is_archived=false
	ORDER BY i.name`

	rows, err := r.db.Query(ctx, q, householdID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []ItemSummary
	for rows.Next() {
		var it MedicineItem
		var total float64
		var nextExpiry *time.Time
		if err := rows.Scan(
			&it.ID, &it.HouseholdID, &it.Name, &it.GenericName, &it.Form, &it.Strength,
			&it.Category, &it.Unit, &it.LocationID, &it.GTIN, &it.PhotoFileID, &it.Notes,
			&it.IsArchived, &it.CreatedAt, &it.UpdatedAt, &total, &nextExpiry,
		); err != nil {
			return nil, err
		}
		items = append(items, ItemSummary{Item: it, TotalQty: total, NextExpiry: nextExpiry})
	}
	return items, rows.Err()
}

func (r *pgRepo) UpdateItem(ctx context.Context, it *MedicineItem) error {
	const q = `
	UPDATE medicine_items
	SET name=$1, generic_name=$2, form=$3, strength=$4, category=$5, location_id=$6,
	    gtin=$7, photo_file_id=$8, notes=$9, updated_at=now()
	WHERE id=$10 AND household_id=$11`
	ct, err := r.db.Exec(ctx, q,
		it.Name, it.GenericName, it.Form, it.Strength, it.Category, it.LocationID,
		it.GTIN, it.PhotoFileID, it.Notes, it.ID, it.HouseholdID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *pgRepo) ArchiveItem(ctx context.Context, householdID, itemID string) error {
	const q = `UPDATE medicine_items SET is_archived=true, updated_at=now() WHERE id=$1 AND household_id=$2`
	ct, err := r.db.Exec(ctx, q, itemID, householdID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ---------- Batches ----------

func (r *pgRepo) CreateBatch(ctx context.Context, b *MedicineBatch) error {
	const q = `
	INSERT INTO medicine_batches (id, item_id, lot_no, expiry_date, qty, unit)
	VALUES ($1,$2,$3,$4,$5,$6)`
	_, err := r.db.Exec(ctx, q, b.ID, b.ItemID, b.LotNo, b.Expiry, b.Qty, b.Unit)
	return err
}

func (r *pgRepo) GetBatchesByItem(ctx context.Context, itemID string) ([]MedicineBatch, error) {
	const q = `
	SELECT id, item_id, lot_no, expiry_date, qty, unit, created_at, updated_at
	FROM medicine_batches
	WHERE item_id=$1
	ORDER BY expiry_date NULLS LAST, created_at`
	rows, err := r.db.Query(ctx, q, itemID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var batches []MedicineBatch
	for rows.Next() {
		var b MedicineBatch
		if err := rows.Scan(&b.ID, &b.ItemID, &b.LotNo, &b.Expiry, &b.Qty, &b.Unit, &b.CreatedAt, &b.UpdatedAt); err != nil {
			return nil, err
		}
		batches = append(batches, b)
	}
	return batches, rows.Err()
}

// ---------- Txn ----------

func (r *pgRepo) CreateTxn(ctx context.Context, t *MedicineTxn) error {
	const q = `
	INSERT INTO medicine_txns (id, item_id, batch_id, actor_user_id, type, qty_change, reason)
	VALUES ($1,$2,$3,$4,$5,$6,$7)`
	_, err := r.db.Exec(ctx, q, t.ID, t.ItemID, t.BatchID, t.ActorID, t.Type, t.QtyChange, t.Reason)
	return err
}

func (r *pgRepo) ApplyTxnAdjustQty(ctx context.Context, t *MedicineTxn) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	switch t.Type {
	case TxnIn:
		if t.BatchID == nil {
			return fmt.Errorf("batch_id required for IN")
		}
		if _, err := tx.Exec(ctx,
			`UPDATE medicine_batches SET qty=qty+$1, updated_at=now() WHERE id=$2`,
			t.QtyChange, *t.BatchID,
		); err != nil {
			return err
		}

	case TxnOut, TxnAdjust:
		if t.BatchID == nil {
			return fmt.Errorf("batch_id required for OUT/ADJUST")
		}
		row := tx.QueryRow(ctx, `SELECT qty FROM medicine_batches WHERE id=$1 FOR UPDATE`, *t.BatchID)
		var qty float64
		if err := row.Scan(&qty); err != nil {
			return err
		}
		newQty := qty + t.QtyChange
		if newQty < 0 {
			return ErrNoStock
		}
		if _, err := tx.Exec(ctx,
			`UPDATE medicine_batches SET qty=$1, updated_at=now() WHERE id=$2`,
			newQty, *t.BatchID,
		); err != nil {
			return err
		}

	default:
		return ErrBadInput
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO medicine_txns (id, item_id, batch_id, actor_user_id, type, qty_change, reason)
		VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		t.ID, t.ItemID, t.BatchID, t.ActorID, t.Type, t.QtyChange, t.Reason,
	); err != nil {
		return err
	}

	return tx.Commit(ctx)
}

// ---------- Locations ----------

func (r *pgRepo) CreateLocation(ctx context.Context, loc *MedicineLocation) error {
	const q = `
	INSERT INTO medicine_locations (id, household_id, name, notes, is_active)
	VALUES ($1,$2,$3,$4,true)`
	_, err := r.db.Exec(ctx, q, loc.ID, loc.HouseholdID, loc.Name, loc.Notes)
	return err
}

func (r *pgRepo) ListLocations(ctx context.Context, householdID string) ([]MedicineLocation, error) {
	const q = `
	SELECT id, household_id, name, notes, is_active, created_at, updated_at
	FROM medicine_locations
	WHERE household_id=$1 AND is_active=true
	ORDER BY name`
	rows, err := r.db.Query(ctx, q, householdID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []MedicineLocation
	for rows.Next() {
		var l MedicineLocation
		if err := rows.Scan(&l.ID, &l.HouseholdID, &l.Name, &l.Notes, &l.IsActive, &l.CreatedAt, &l.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

// ---------- Alerts ----------

func (r *pgRepo) UpsertAlert(ctx context.Context, a *MedicineAlert) error {
	const q = `
	INSERT INTO medicine_alerts (item_id, min_qty, expiry_window_days, is_enabled, updated_at)
	VALUES ($1,$2,$3,$4,now())
	ON CONFLICT (item_id)
	DO UPDATE SET 
		min_qty=EXCLUDED.min_qty,
		expiry_window_days=EXCLUDED.expiry_window_days,
		is_enabled=EXCLUDED.is_enabled,
		updated_at=now()`
	_, err := r.db.Exec(ctx, q, a.ItemID, a.MinQty, a.ExpiryWindowDays, a.IsEnabled)
	return err
}

func (r *pgRepo) GetAlert(ctx context.Context, itemID string) (*MedicineAlert, error) {
	const q = `
	SELECT item_id, min_qty, expiry_window_days, is_enabled, updated_at
	FROM medicine_alerts
	WHERE item_id=$1`
	row := r.db.QueryRow(ctx, q, itemID)

	var a MedicineAlert
	if err := row.Scan(&a.ItemID, &a.MinQty, &a.ExpiryWindowDays, &a.IsEnabled, &a.UpdatedAt); err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &a, nil
}
