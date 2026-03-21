package contractors

import (
	"context"
	"errors"
)

type Service struct {
	Repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{Repo: repo}
}

func (s *Service) List(ctx context.Context, onlyFavorites bool, limit, offset int) ([]Contractor, error) {
	return s.Repo.List(ctx, onlyFavorites, limit, offset)
}

func (s *Service) GetByID(ctx context.Context, id string) (*Contractor, error) {
	return s.Repo.GetByID(ctx, id)
}

func (s *Service) Create(ctx context.Context, userID string, p CreateContractorPayload) (*Contractor, error) {
	if p.Name == "" {
		return nil, errors.New("name is required")
	}
	c := &Contractor{
		Name:          p.Name,
		Types:         p.Types,
		Phone:         p.Phone,
		Address:       p.Address,
		Lat:           p.Lat,
		Lng:           p.Lng,
		GoogleMapsURL: p.GoogleMapsURL,
		Note:          p.Note,
		IsFavorite:    p.IsFavorite,
		CreatedBy:     userID,
	}
	if err := s.Repo.Create(ctx, c); err != nil {
		return nil, err
	}
	return c, nil
}

func (s *Service) Update(ctx context.Context, id string, p UpdateContractorPayload) (*Contractor, error) {
	return s.Repo.Update(ctx, id, p)
}

func (s *Service) Delete(ctx context.Context, id string) error {
	return s.Repo.Delete(ctx, id)
}

func (s *Service) ToggleFavorite(ctx context.Context, id string) (*Contractor, error) {
	return s.Repo.ToggleFavorite(ctx, id)
}