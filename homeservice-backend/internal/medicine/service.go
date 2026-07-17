package medicine

import (
	"context"
	"errors"
	"time"
)

type Service struct {
	Repo *Repo
	Now  func() time.Time
}

func NewService(repo *Repo) *Service {
	return &Service{Repo: repo, Now: time.Now}
}

func parseDate(s *string) (*time.Time, error) {
	if s == nil || *s == "" {
		return nil, nil
	}
	t, err := time.Parse("2006-01-02", *s)
	if err != nil {
		return nil, errors.New("invalid date format, expected YYYY-MM-DD")
	}
	return &t, nil
}

func (s *Service) ListItems(ctx context.Context, f ListItemFilter) ([]MedicineItem, error) {
	return s.Repo.List(ctx, f)
}

func (s *Service) GetItem(ctx context.Context, id string) (*MedicineItem, error) {
	return s.Repo.GetByID(ctx, id)
}

func (s *Service) CreateItem(ctx context.Context, p CreateItemPayload) (*MedicineItem, error) {
	if p.Name == "" {
		return nil, errors.New("name is required")
	}
	location := p.Location
	if location == nil {
		location = p.LocationID
	}
	ed, err := parseDate(p.ExpiryDate)
	if err != nil {
		return nil, err
	}
	it := &MedicineItem{
		Name:       p.Name,
		Form:       p.Form,
		Unit:       p.Unit,
		Category:   p.Category,
		StockQty:   p.StockQty,
		ExpiryDate: ed,
		Location:   location,
		Note:       p.Note,
	}
	if err := s.Repo.Create(ctx, it); err != nil {
		return nil, err
	}
	return it, nil
}

func (s *Service) UpdateItem(ctx context.Context, id string, p UpdateItemPayload) (*MedicineItem, error) {
	ed, err := parseDate(p.ExpiryDate)
	if err != nil {
		return nil, err
	}
	return s.Repo.Update(ctx, id, p, ed)
}

func (s *Service) DeleteItem(ctx context.Context, id string) error {
	return s.Repo.Delete(ctx, id)
}

func (s *Service) AdjustStock(ctx context.Context, id string, delta float64) (*MedicineItem, error) {
	if delta == 0 {
		return nil, errors.New("delta cannot be zero")
	}
	return s.Repo.AdjustStock(ctx, id, delta)
}

func (s *Service) GetAlert(ctx context.Context, itemID string) (*MedicineAlert, error) {
	return s.Repo.GetAlert(ctx, itemID)
}

func (s *Service) UpsertAlert(ctx context.Context, a *MedicineAlert) error {
	if a.ItemID == "" {
		return errors.New("item_id is required")
	}
	return s.Repo.UpsertAlert(ctx, a)
}

func (s *Service) ListLowStock(ctx context.Context) ([]MedicineItem, error) {
	return s.Repo.ListLowStock(ctx)
}

func (s *Service) ListExpiringSoon(ctx context.Context) ([]MedicineItem, error) {
	return s.Repo.ListExpiringSoon(ctx)
}

func (s *Service) ListExpired(ctx context.Context) ([]MedicineItem, error) {
	return s.Repo.ListExpired(ctx)
}
