package chores

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct{ DB *pgxpool.Pool }

func (r Repo) Create(ctx context.Context, c *Chore) error {
	const q = `
INSERT INTO public.chores (id, title, category, status, note, created_by)
VALUES (gen_random_uuid(), $1, $2, 'open', $3, $4)
RETURNING id, status, created_at, updated_at`
	return r.DB.QueryRow(ctx, q, c.Title, c.Category, c.Note, c.CreatedBy).
		Scan(&c.ID, &c.Status, &c.CreatedAt, &c.UpdatedAt)
}

func (r Repo) Claim(ctx context.Context, id, userID string) (Chore, error) {
	const q = `
UPDATE public.chores
SET status='claimed', claimed_by=$2, claimed_at=now(), updated_at=now()
WHERE id=$1 AND status='open'
RETURNING id, title, category, status, claimed_by, claimed_at, created_by, created_at, updated_at`
	var c Chore
	err := r.DB.QueryRow(ctx, q, id, userID).
		Scan(&c.ID, &c.Title, &c.Category, &c.Status, &c.ClaimedBy, &c.ClaimedAt, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt)
	return c, err
}

func (r Repo) Complete(ctx context.Context, id, userID string) (Chore, error) {
	const q = `
UPDATE public.chores
SET status='completed', completed_by=$2, completed_at=now(), updated_at=now()
WHERE id=$1 AND status IN ('open','claimed')
RETURNING id, title, category, status, completed_by, completed_at, created_by, created_at, updated_at`
	var c Chore
	err := r.DB.QueryRow(ctx, q, id, userID).
		Scan(&c.ID, &c.Title, &c.Category, &c.Status, &c.CompletedBy, &c.CompletedAt, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt)
	return c, err
}

func (r Repo) List(ctx context.Context, limit int) ([]Chore, error) {
	const q = `
SELECT id, title, category, status, claimed_by, claimed_at, completed_by, completed_at, created_by, created_at, updated_at
FROM public.chores
ORDER BY created_at DESC
LIMIT $1`
	rows, err := r.DB.Query(ctx, q, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Chore
	for rows.Next() {
		var c Chore
		err = rows.Scan(&c.ID, &c.Title, &c.Category, &c.Status, &c.ClaimedBy, &c.ClaimedAt, &c.CompletedBy, &c.CompletedAt, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}
