package purchases

import (
	"context"
	"time"
)

type Service struct {
	Repo Repo
	Now  func() time.Time
}

func NewService(r Repo) *Service { return &Service{Repo: r, Now: time.Now} }

type CreatePayload struct {
	Title           string  `json:"title"`
	Note            string  `json:"note"`
	Items           []Item  `json:"items"`
	AmountEstimated float64 `json:"amount_estimated"`
	Currency        string  `json:"currency"`
	Category        string  `json:"category"`
	Store           string  `json:"store"`
}

type UpdateRequesterPayload struct {
	Title           *string  `json:"title"`
	Note            *string  `json:"note"`
	Items           *[]Item  `json:"items"`
	AmountEstimated *float64 `json:"amount_estimated"`
	Category        *string  `json:"category"`
	Store           *string  `json:"store"`
}

type ProgressPayload struct {
	NextStatus Status   `json:"next_status"`
	AmountPaid *float64 `json:"amount_paid"`
}

// กติกาเปลี่ยนสถานะ
func (s *Service) CanTransition(from, to Status) bool {
	switch from {
	case StatusPlanned:
		return to == StatusOrdered || to == StatusCancelled
	case StatusOrdered:
		return to == StatusBought || to == StatusCancelled
	case StatusBought:
		return to == StatusDelivered
		// ถ้ามี StatusDone ให้เปิดคอมเมนต์นี้:
		// case StatusDelivered:
		// 	return to == StatusDone
	default:
		return false
	}
}

/*************** methods ที่ handler เรียก ***************/

// List passthrough
func (s *Service) List(ctx context.Context, f ListFilter) ([]Purchase, error) {
	return s.Repo.List(ctx, f)
}

// Create (requester เป็นคนสร้าง)
func (s *Service) Create(ctx context.Context, uid string, in CreatePayload) (*Purchase, error) {
	p := &Purchase{
		Title:           in.Title,
		Note:            in.Note,
		Items:           in.Items,
		AmountEstimated: in.AmountEstimated,
		Currency:        in.Currency,
		Category:        in.Category,
		Store:           in.Store,
		Status:          StatusPlanned,
		RequesterID:     uid,
	}
	if p.Currency == "" {
		p.Currency = "THB"
	}
	if err := s.Repo.Create(ctx, p); err != nil {
		return nil, err
	}
	return p, nil
}

// Get
func (s *Service) Get(ctx context.Context, id string) (*Purchase, error) {
	return s.Repo.Get(ctx, id)
}

// Delete: requester เท่านั้น และต้องยังแก้ไขได้อยู่ + ยัง planned
func (s *Service) Delete(ctx context.Context, uid, id string) error {
	p, err := s.Repo.Get(ctx, id)
	if err != nil {
		return err
	}
	if p.RequesterID != uid {
		return ErrForbidden
	}
	if s.Now().After(p.EditableUntil) || p.Status != StatusPlanned {
		return ErrConflict
	}
	return s.Repo.Delete(ctx, id)
}

// Cancel: requester หรือ buyer ยกเลิกได้ ถ้า transition อนุญาต
func (s *Service) Cancel(ctx context.Context, uid, id string) (*Purchase, error) {
	p, err := s.Repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if !(p.RequesterID == uid || p.BuyerID == uid) {
		return nil, ErrForbidden
	}
	if !s.CanTransition(p.Status, StatusCancelled) {
		return nil, ErrConflict
	}
	p.Status = StatusCancelled
	if err := s.Repo.Update(ctx, p); err != nil {
		return nil, err
	}
	return p, nil
}

// AddAttachment: requester หรือ buyer เท่านั้น
func (s *Service) AddAttachment(ctx context.Context, uid, id, fileID string) error {
	p, err := s.Repo.Get(ctx, id)
	if err != nil {
		return err
	}
	if !(p.RequesterID == uid || p.BuyerID == uid) {
		return ErrForbidden
	}
	return s.Repo.LinkAttachment(ctx, id, fileID)
}

// RemoveAttachment: requester หรือ buyer เท่านั้น
func (s *Service) RemoveAttachment(ctx context.Context, uid, id, fileID string) error {
	p, err := s.Repo.Get(ctx, id)
	if err != nil {
		return err
	}
	if !(p.RequesterID == uid || p.BuyerID == uid) {
		return ErrForbidden
	}
	return s.Repo.UnlinkAttachment(ctx, id, fileID)
}

// UpdateByRequester: requester แก้ไขได้ภายใน 10 นาทีแรก
func (s *Service) UpdateByRequester(ctx context.Context, uid, id string, patch UpdateRequesterPayload) (*Purchase, error) {
	p, err := s.Repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if p.RequesterID != uid {
		return nil, ErrForbidden
	}
	if s.Now().After(p.EditableUntil) {
		return nil, ErrConflict // หมด 10 นาที
	}

	// apply allowed fields
	if patch.Title != nil {
		p.Title = *patch.Title
	}
	if patch.Note != nil {
		p.Note = *patch.Note
	}
	if patch.Items != nil {
		p.Items = *patch.Items
	}
	if patch.AmountEstimated != nil {
		p.AmountEstimated = *patch.AmountEstimated
	}
	if patch.Category != nil {
		p.Category = *patch.Category
	}
	if patch.Store != nil {
		p.Store = *patch.Store
	}

	if err := s.Repo.Update(ctx, p); err != nil {
		return nil, err
	}
	return p, nil
}

// Claim: ใครก็ claim ได้ถ้ายังไม่มี buyer และยัง planned
func (s *Service) Claim(ctx context.Context, uid, id string) (*Purchase, error) {
	p, err := s.Repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if p.BuyerID != "" || p.Status != StatusPlanned {
		return nil, ErrConflict
	}
	p.BuyerID = uid
	p.Status = StatusOrdered
	if err := s.Repo.Update(ctx, p); err != nil {
		return nil, err
	}
	return p, nil
}

// Progress: buyer เท่านั้น และต้องเปลี่ยนตามลำดับ
func (s *Service) Progress(ctx context.Context, uid, id string, in ProgressPayload) (*Purchase, error) {
	p, err := s.Repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if p.BuyerID != uid {
		return nil, ErrForbidden
	}
	if !s.CanTransition(p.Status, in.NextStatus) {
		return nil, ErrConflict
	}
	// ถ้าไป "bought" แล้วต้องมี amount_paid
	if in.NextStatus == StatusBought && in.AmountPaid == nil {
		return nil, ErrBadRequest
	}

	if in.AmountPaid != nil {
		p.AmountPaid = *in.AmountPaid
	}
	p.Status = in.NextStatus
	if err := s.Repo.Update(ctx, p); err != nil {
		return nil, err
	}
	return p, nil
}
