package bills

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct{ DB *pgxpool.Pool }

func (r Repo) Create(ctx context.Context, b *Bill) error {
	const q = `
INSERT INTO public.bills
(id, type, title, amount, billing_period_start, billing_period_end, due_date, status, note, created_by)
VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, 'unpaid', $7, $8)
RETURNING id, status, created_at, updated_at`
	return r.DB.QueryRow(ctx, q,
		b.Type, b.Title, b.Amount,
		b.BillingPeriodStart, b.BillingPeriodEnd, b.DueDate,
		b.Note, b.CreatedBy,
	).Scan(&b.ID, &b.Status, &b.CreatedAt, &b.UpdatedAt)
}

func (r Repo) MarkPaid(ctx context.Context, id string) (Bill, error) {
	const q = `
UPDATE public.bills
SET status='paid', paid_at=now(), updated_at=now()
WHERE id=$1
RETURNING id, type, title, amount, status, paid_at, created_by, created_at, updated_at`
	var b Bill
	err := r.DB.QueryRow(ctx, q, id).
		Scan(&b.ID, &b.Type, &b.Title, &b.Amount, &b.Status, &b.PaidAt, &b.CreatedBy, &b.CreatedAt, &b.UpdatedAt)
	return b, err
}

func (r Repo) List(ctx context.Context, limit int) ([]Bill, error) {
	const q = `
SELECT id, type, title, amount, status, due_date, paid_at, created_by, created_at, updated_at
FROM public.bills
ORDER BY created_at DESC
LIMIT $1`
	rows, err := r.DB.Query(ctx, q, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Bill
	for rows.Next() {
		var b Bill
		var due *time.Time
		err = rows.Scan(&b.ID, &b.Type, &b.Title, &b.Amount, &b.Status, &due, &b.PaidAt, &b.CreatedBy, &b.CreatedAt, &b.UpdatedAt)
		if err != nil {
			return nil, err
		}
		b.DueDate = due
		out = append(out, b)
	}
	return out, rows.Err()
}
