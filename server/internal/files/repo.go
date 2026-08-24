package files

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")

type Repo struct {
	DB *pgxpool.Pool
}

func (r Repo) Create(ctx context.Context, f *File) error {
	return r.DB.QueryRow(ctx, `
		INSERT INTO files (owner_id, filename, mime, size, url)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at
	`, f.OwnerID, f.Filename, f.MIME, f.Size, f.URL).
		Scan(&f.ID, &f.CreatedAt)
}

func (r Repo) Get(ctx context.Context, id string) (*File, error) {
	var f File
	if err := r.DB.QueryRow(ctx, `
		SELECT id, owner_id, filename, mime, size, url, created_at
		FROM files WHERE id=$1
	`, id).Scan(&f.ID, &f.OwnerID, &f.Filename, &f.MIME, &f.Size, &f.URL, &f.CreatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &f, nil
}

func (r Repo) Delete(ctx context.Context, ownerID, id string) error {
	ct, err := r.DB.Exec(ctx, `
		DELETE FROM files WHERE id=$1 AND owner_id=$2
	`, id, ownerID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}