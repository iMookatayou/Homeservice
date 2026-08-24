package chores

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("not found")
	ErrConflict = errors.New("conflict")
	ErrForbidden = errors.New("forbidden")
)

type Repo struct {
	DB *pgxpool.Pool
}

const selectCols = `
	id, title, category, status, note,
	claimed_by, claimed_at, completed_by, completed_at,
	created_by, created_at, updated_at
`

func scanChore(row pgx.Row) (Chore, error) {
	var c Chore
	if err := row.Scan(
		&c.ID, &c.Title, &c.Category, &c.Status, &c.Note,
		&c.ClaimedBy, &c.ClaimedAt, &c.CompletedBy, &c.CompletedAt,
		&c.CreatedBy, &c.CreatedAt, &c.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Chore{}, ErrNotFound
		}
		return Chore{}, err
	}
	return c, nil
}

func (r Repo) Create(ctx context.Context, c *Chore) error {
	row := r.DB.QueryRow(ctx, `
		INSERT INTO chores (title, category, note, created_by)
		VALUES ($1, $2, $3, $4)
		RETURNING `+selectCols,
		c.Title, c.Category, c.Note, c.CreatedBy,
	)
	ch, err := scanChore(row)
	if err != nil {
		return err
	}
	*c = ch
	return nil
}

func (r Repo) List(ctx context.Context, limit, offset int) ([]Chore, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT `+selectCols+`
		FROM chores
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Chore
	for rows.Next() {
		c, err := scanChore(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r Repo) Claim(ctx context.Context, id, userID string) (Chore, error) {
	row := r.DB.QueryRow(ctx, `
		UPDATE chores
		SET status='claimed', claimed_by=$2, claimed_at=now(), updated_at=now()
		WHERE id=$1 AND status='open'
		RETURNING `+selectCols,
		id, userID,
	)
	c, err := scanChore(row)
	if errors.Is(err, ErrNotFound) {
		return Chore{}, ErrConflict
	}
	return c, err
}

func (r Repo) Complete(ctx context.Context, id, userID string) (Chore, error) {
	row := r.DB.QueryRow(ctx, `
		UPDATE chores
		SET status='completed', completed_by=$2, completed_at=now(), updated_at=now()
		WHERE id=$1 AND status IN ('open','claimed')
		RETURNING `+selectCols,
		id, userID,
	)
	return scanChore(row)
}

func (r Repo) Delete(ctx context.Context, id, userID string) error {
	ct, err := r.DB.Exec(ctx, `
		DELETE FROM chores WHERE id=$1 AND created_by=$2
	`, id, userID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}