package purchases

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type AdminRepo struct {
	DB *pgxpool.Pool
}

type RequestRow struct {
	ID        string `json:"id"`
	UserID    string `json:"user_id"`
	Title     string `json:"title"`
	Status    string `json:"status"`
	Priority  string `json:"priority"`
	CreatedAt string `json:"created_at"`
}

func (r AdminRepo) List(ctx context.Context, status *string, limit, offset int) ([]RequestRow, error) {
	q := `
	SELECT id, user_id, title, status::text, priority::text, to_char(created_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
	FROM purchase_requests`
	var rows pgx.Rows
	var err error
	if status != nil && *status != "" {
		q += ` WHERE status = $1::purchase_status ORDER BY created_at DESC LIMIT $2 OFFSET $3`
		rows, err = r.DB.Query(ctx, q, *status, limit, offset)
	} else {
		q += ` ORDER BY created_at DESC LIMIT $1 OFFSET $2`
		rows, err = r.DB.Query(ctx, q, limit, offset)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []RequestRow
	for rows.Next() {
		var rr RequestRow
		if err := rows.Scan(&rr.ID, &rr.UserID, &rr.Title, &rr.Status, &rr.Priority, &rr.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, rr)
	}
	return out, rows.Err()
}

func (r AdminRepo) UpdateStatus(ctx context.Context, id string, new Status, reason string, adminID string) error {
	const q = `
	UPDATE purchase_requests
	SET status=$2::purchase_status, notes_admin = NULLIF($3,'') , updated_at=now()
	WHERE id=$1::uuid`
	ct, err := r.DB.Exec(ctx, q, id, string(new), reason)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
