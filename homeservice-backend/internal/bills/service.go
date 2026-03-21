package bills

import "context"

type Service struct {
	repo Repo
}

func NewService(r Repo) Service {
	return Service{repo: r}
}

func (s Service) GetBill(ctx context.Context, id string) (*Bill, error) {
	return s.repo.GetByID(ctx, id)
}

func (s Service) CreateBill(ctx context.Context, userID string, p CreateBillPayload) (*Bill, error) {
	return s.repo.CreateBill(ctx, userID, p)
}

func (s Service) ListBills(ctx context.Context, limit, offset int) ([]Bill, error) {
	return s.repo.ListBills(ctx, limit, offset)
}

func (s Service) UpdateBill(ctx context.Context, id string, p UpdateBillPayload) (*Bill, error) {
	return s.repo.UpdateBill(ctx, id, p)
}

func (s Service) DeleteBill(ctx context.Context, id string) error {
	return s.repo.DeleteBill(ctx, id)
}

func (s Service) MarkPaid(ctx context.Context, id string) (*Bill, error) {
	return s.repo.MarkPaid(ctx, id)
}

func (s Service) Summarize(ctx context.Context) ([]Summary, error) {
	return s.repo.Summarize(ctx)
}