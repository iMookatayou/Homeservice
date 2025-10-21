package files

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("file not found")

type Repo struct {
	DB *pgxpool.Pool
}

func (r Repo) Create(ctx context.Context, f *File) error {
	const q = `
	INSERT INTO files (id, owner_id, filename, mimetype, size, storage_url, created_at)
	VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, now())
	RETURNING id, created_at`
	return r.DB.QueryRow(ctx, q, f.OwnerID, f.Filename, f.MIME, f.Size, f.StorageURL).
		Scan(&f.ID, &f.CreatedAt)
}

func (r Repo) Get(ctx context.Context, id string) (*File, error) {
	const q = `SELECT id, owner_id, filename, mimetype, size, storage_url, created_at FROM files WHERE id=$1`
	var f File
	if err := r.DB.QueryRow(ctx, q, id).Scan(&f.ID, &f.OwnerID, &f.Filename, &f.MIME, &f.Size, &f.StorageURL, &f.CreatedAt); err != nil {
		return nil, ErrNotFound
	}
	return &f, nil
}

func (r Repo) Delete(ctx context.Context, ownerID, id string) error {
	const q = `DELETE FROM files WHERE id=$1 AND owner_id=$2`
	ct, err := r.DB.Exec(ctx, q, id, ownerID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
