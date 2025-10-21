package purchases

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	DB *pgxpool.Pool
}

var ErrNotFound = errors.New("not found")

/* ===== Requests ===== */

func (r Repo) CreateRequest(ctx context.Context, userID string, in CreateRequestInput) (Request, error) {
	q := `
		INSERT INTO purchase_requests (user_id, title, description, priority, price_estimate, media_urls)
		VALUES ($1::uuid, $2, $3, COALESCE($4,'medium')::purchase_priority, $5, COALESCE($6,'{}'))
		RETURNING id, user_id, title, description, priority, status, price_estimate, media_urls, notes_admin, created_at, updated_at
	`
	row := r.DB.QueryRow(ctx, q, userID, in.Title, in.Description, in.Priority, in.PriceEstimate, nullArray(in.MediaURLs))
	var out Request
	err := row.Scan(
		&out.ID, &out.UserID, &out.Title, &out.Description, &out.Priority, &out.Status,
		&out.PriceEstimate, &out.MediaURLs, &out.NotesAdmin, &out.CreatedAt, &out.UpdatedAt,
	)
	return out, err
}

func (r Repo) GetRequest(ctx context.Context, id string) (Request, error) {
	q := `
		SELECT id, user_id, title, description, priority, status, price_estimate, media_urls, notes_admin, created_at, updated_at
		FROM purchase_requests WHERE id=$1::uuid
	`
	var out Request
	err := r.DB.QueryRow(ctx, q, id).Scan(
		&out.ID, &out.UserID, &out.Title, &out.Description, &out.Priority, &out.Status,
		&out.PriceEstimate, &out.MediaURLs, &out.NotesAdmin, &out.CreatedAt, &out.UpdatedAt,
	)
	if err != nil {
		return Request{}, ErrNotFound
	}
	return out, nil
}

func (r Repo) ListMyRequests(ctx context.Context, userID string, limit int, cursor string) ([]Request, *string, error) {
	q := `
		SELECT id, user_id, title, description, priority, status, price_estimate, media_urls, notes_admin, created_at, updated_at
		FROM purchase_requests
		WHERE user_id=$1::uuid AND ($2 = '' OR id::text < $2)
		ORDER BY id DESC
		LIMIT $3
	`
	rows, err := r.DB.Query(ctx, q, userID, cursor, limit+1)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	var list []Request
	for rows.Next() {
		var rec Request
		if err := rows.Scan(
			&rec.ID, &rec.UserID, &rec.Title, &rec.Description, &rec.Priority, &rec.Status,
			&rec.PriceEstimate, &rec.MediaURLs, &rec.NotesAdmin, &rec.CreatedAt, &rec.UpdatedAt,
		); err != nil {
			return nil, nil, err
		}
		list = append(list, rec)
	}
	var next *string
	if len(list) > limit {
		last := list[limit-1].ID
		next = &last
		list = list[:limit]
	}
	return list, next, nil
}

func (r Repo) UpdateRequest(ctx context.Context, id string, in UpdateRequestInput) (Request, error) {
	q := `
		UPDATE purchase_requests SET
			title          = COALESCE($2, title),
			description    = COALESCE($3, description),
			priority       = COALESCE($4, priority),
			status         = COALESCE($5, status),
			price_estimate = COALESCE($6, price_estimate),
			media_urls     = COALESCE($7, media_urls),
			notes_admin    = COALESCE($8, notes_admin)
		WHERE id=$1::uuid
		RETURNING id, user_id, title, description, priority, status, price_estimate, media_urls, notes_admin, created_at, updated_at
	`
	var media interface{}
	if in.MediaURLs != nil {
		media = nullArray(*in.MediaURLs)
	}
	row := r.DB.QueryRow(ctx, q, id, in.Title, in.Description, in.Priority, in.Status, in.PriceEstimate, media, in.NotesAdmin)

	var out Request
	err := row.Scan(
		&out.ID, &out.UserID, &out.Title, &out.Description, &out.Priority, &out.Status,
		&out.PriceEstimate, &out.MediaURLs, &out.NotesAdmin, &out.CreatedAt, &out.UpdatedAt,
	)
	if err != nil {
		return Request{}, ErrNotFound
	}
	return out, nil
}

func (r Repo) DeleteRequest(ctx context.Context, id string) error {
	tag, err := r.DB.Exec(ctx, `DELETE FROM purchase_requests WHERE id=$1::uuid`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

/* ===== Items ===== */

func (r Repo) AddItem(ctx context.Context, requestID string, in CreateItemInput) (Item, error) {
	q := `
		INSERT INTO purchase_items (request_id, name, qty, unit, price_estimate)
		VALUES ($1::uuid, $2, COALESCE($3,1), COALESCE($4,'item'), $5)
		RETURNING id, request_id, name, qty, unit, price_estimate, created_at, updated_at
	`
	row := r.DB.QueryRow(ctx, q, requestID, in.Name, in.Qty, in.Unit, in.PriceEstimate)
	var out Item
	err := row.Scan(&out.ID, &out.RequestID, &out.Name, &out.Qty, &out.Unit, &out.PriceEstimate, &out.CreatedAt, &out.UpdatedAt)
	return out, err
}

func (r Repo) ListItems(ctx context.Context, requestID string) ([]Item, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT id, request_id, name, qty, unit, price_estimate, created_at, updated_at
		FROM purchase_items WHERE request_id=$1::uuid ORDER BY created_at ASC
	`, requestID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []Item
	for rows.Next() {
		var it Item
		if err := rows.Scan(&it.ID, &it.RequestID, &it.Name, &it.Qty, &it.Unit, &it.PriceEstimate, &it.CreatedAt, &it.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, it)
	}
	return list, nil
}

/* ===== Messages ===== */

func (r Repo) AddMessage(ctx context.Context, requestID, userID string, in CreateMessageInput) (Message, error) {
	q := `
		INSERT INTO purchase_messages (request_id, user_id, body, media_urls)
		VALUES ($1::uuid, $2::uuid, $3, COALESCE($4,'{}'))
		RETURNING id, request_id, user_id, body, media_urls, created_at, updated_at
	`
	row := r.DB.QueryRow(ctx, q, requestID, userID, in.Body, nullArray(in.MediaURLs))
	var out Message
	err := row.Scan(&out.ID, &out.RequestID, &out.UserID, &out.Body, &out.MediaURLs, &out.CreatedAt, &out.UpdatedAt)
	return out, err
}

func (r Repo) ListMessages(ctx context.Context, requestID string) ([]Message, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT id, request_id, user_id, body, media_urls, created_at, updated_at
		FROM purchase_messages WHERE request_id=$1::uuid ORDER BY created_at ASC
	`, requestID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []Message
	for rows.Next() {
		var m Message
		if err := rows.Scan(&m.ID, &m.RequestID, &m.UserID, &m.Body, &m.MediaURLs, &m.CreatedAt, &m.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, m)
	}
	return list, nil
}

/* ===== helpers ===== */

func nullArray(s []string) interface{} {
	if len(s) == 0 {
		return nil
	}
	return s
}
