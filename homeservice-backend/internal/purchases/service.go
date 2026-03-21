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
	Title           string   `json:"title"`
	Note            string   `json:"note"`
	Items           []Item   `json:"items"`
	AmountEstimated *float64 `json:"amount_estimated"`
	Currency        string   `json:"currency"`
	Category        string   `json:"category"`
	Store           string   `json:"store"`
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

func (s *Service) CanTransition(from, to Status) bool {
	switch from {
	case StatusPlanned:
		return to == StatusOrdered || to == StatusCancelled
	case StatusOrdered:
		return to == StatusBought || to == StatusCancelled
	case StatusBought:
		return to == StatusDelivered
	default:
		return false
	}
}

func (s *Service) List(ctx context.Context, f ListFilter) ([]Purchase, error) {
	return s.Repo.List(ctx, f)
}

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

func (s *Service) Get(ctx context.Context, id string) (*Purchase, error) {
	return s.Repo.Get(ctx, id)
}

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

func (s *Service) UpdateByRequester(ctx context.Context, uid, id string, patch UpdateRequesterPayload) (*Purchase, error) {
	p, err := s.Repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if p.RequesterID != uid {
		return nil, ErrForbidden
	}
	if s.Now().After(p.EditableUntil) {
		return nil, ErrConflict
	}

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
		p.AmountEstimated = patch.AmountEstimated
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
	if in.NextStatus == StatusBought && in.AmountPaid == nil {
		return nil, ErrBadRequest
	}

	if in.AmountPaid != nil {
		p.AmountPaid = in.AmountPaid
	}
	p.Status = in.NextStatus
	if err := s.Repo.Update(ctx, p); err != nil {
		return nil, err
	}
	return p, nil
}