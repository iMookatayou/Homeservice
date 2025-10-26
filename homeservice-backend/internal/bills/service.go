package bills

import "context"

type Service struct {
	repo Repo
}

func NewService(r Repo) Service {
	return Service{repo: r}
}

func (s Service) CreateBill(ctx context.Context, b *Bill) error {
	return s.repo.CreateBill(ctx, b)
}

func (s Service) ListBills(ctx context.Context) ([]Bill, error) {
	return s.repo.ListBills(ctx)
}

func (s Service) Summarize(ctx context.Context) ([]Summary, error) {
	return s.repo.Summarize(ctx)
}
