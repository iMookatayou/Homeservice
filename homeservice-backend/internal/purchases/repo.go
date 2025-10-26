package purchases

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

type ListFilter struct {
	Query    string
	Status   *Status
	Category string
	Mine     string // "requester" | "buyer" | ""
	UserID   string // จาก auth
	Limit    int
	Offset   int
}

type Repo interface {
	List(ctx context.Context, f ListFilter) ([]Purchase, error)
	Get(ctx context.Context, id string) (*Purchase, error)
	Create(ctx context.Context, p *Purchase) error
	Update(ctx context.Context, p *Purchase) error
	Delete(ctx context.Context, id string) error

	LinkAttachment(ctx context.Context, purchaseID, fileID string) error
	UnlinkAttachment(ctx context.Context, purchaseID, fileID string) error
}

type repo struct {
	DB *pgxpool.Pool
}

func NewRepo(db *pgxpool.Pool) Repo {
	return &repo{DB: db}
}

// --- helpers ---
func jsonBytes(v any) []byte {
	if v == nil {
		return nil
	}
	b, _ := json.Marshal(v)
	return b
}

const selectCols = `
  id, title, note, items, amount_estimated, amount_paid,
  currency, category, store, status, requester_id, buyer_id,
  editable_until, created_at, updated_at
`

// List with filters / search / pagination
func (r *repo) List(ctx context.Context, f ListFilter) ([]Purchase, error) {
	var sb strings.Builder
	var args []any
	arg := 1

	sb.WriteString(`SELECT ` + selectCols + ` FROM purchases WHERE 1=1`)

	if f.Query != "" {
		sb.WriteString(fmt.Sprintf(` AND (title ILIKE $%d OR note ILIKE $%d OR items::text ILIKE $%d)`, arg, arg, arg))
		args = append(args, "%"+f.Query+"%")
		arg++
	}

	if f.Status != nil && *f.Status != "" {
		sb.WriteString(fmt.Sprintf(` AND status = $%d`, arg))
		args = append(args, *f.Status)
		arg++
	}

	if f.Category != "" {
		sb.WriteString(fmt.Sprintf(` AND category = $%d`, arg))
		args = append(args, f.Category)
		arg++
	}

	if f.Mine == "requester" && f.UserID != "" {
		sb.WriteString(fmt.Sprintf(` AND requester_id = $%d`, arg))
		args = append(args, f.UserID)
		arg++
	}
	if f.Mine == "buyer" && f.UserID != "" {
		sb.WriteString(fmt.Sprintf(` AND buyer_id = $%d`, arg))
		args = append(args, f.UserID)
		arg++
	}

	sb.WriteString(` ORDER BY created_at DESC`)

	limit := f.Limit
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	offset := f.Offset
	if offset < 0 {
		offset = 0
	}
	sb.WriteString(fmt.Sprintf(` LIMIT %d OFFSET %d`, limit, offset))

	rows, err := r.DB.Query(ctx, sb.String(), args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Purchase, 0, limit)
	for rows.Next() {
		var p Purchase
		if err := rows.Scan(
			&p.ID, &p.Title, &p.Note, &p.Items, &p.AmountEstimated, &p.AmountPaid,
			&p.Currency, &p.Category, &p.Store, &p.Status, &p.RequesterID, &p.BuyerID,
			&p.EditableUntil, &p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r *repo) Get(ctx context.Context, id string) (*Purchase, error) {
	row := r.DB.QueryRow(ctx, `SELECT `+selectCols+` FROM purchases WHERE id=$1`, id)
	var p Purchase
	if err := row.Scan(
		&p.ID, &p.Title, &p.Note, &p.Items, &p.AmountEstimated, &p.AmountPaid,
		&p.Currency, &p.Category, &p.Store, &p.Status, &p.RequesterID, &p.BuyerID,
		&p.EditableUntil, &p.CreatedAt, &p.UpdatedAt,
	); err != nil {
		return nil, err
	}
	return &p, nil
}

// Create returns the filled Purchase (id/timestamps/editable_until)
func (r *repo) Create(ctx context.Context, p *Purchase) error {
	// defaults (เผื่อ service ยังไม่ได้เติม)
	if p.Currency == "" {
		p.Currency = "THB"
	}
	if p.Status == "" {
		p.Status = StatusPlanned
	}

	row := r.DB.QueryRow(ctx, `
		INSERT INTO purchases (
		  title, note, items, amount_estimated, amount_paid, currency,
		  category, store, status, requester_id, buyer_id
		) VALUES (
		  $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11
		)
		RETURNING `+selectCols,
		p.Title, p.Note, jsonBytes(p.Items), p.AmountEstimated, p.AmountPaid, p.Currency,
		p.Category, p.Store, p.Status, p.RequesterID, p.BuyerID,
	)
	return row.Scan(
		&p.ID, &p.Title, &p.Note, &p.Items, &p.AmountEstimated, &p.AmountPaid,
		&p.Currency, &p.Category, &p.Store, &p.Status, &p.RequesterID, &p.BuyerID,
		&p.EditableUntil, &p.CreatedAt, &p.UpdatedAt,
	)
}

// Update updates all mutable columns (service จะเป็นผู้คุมกติกา)
func (r *repo) Update(ctx context.Context, p *Purchase) error {
	_, err := r.DB.Exec(ctx, `
		UPDATE purchases
		SET
		  title=$2, note=$3, items=$4, amount_estimated=$5, amount_paid=$6,
		  currency=$7, category=$8, store=$9, status=$10, requester_id=$11, buyer_id=$12,
		  updated_at=now()
		WHERE id=$1
	`, p.ID, p.Title, p.Note, jsonBytes(p.Items), p.AmountEstimated, p.AmountPaid,
		p.Currency, p.Category, p.Store, p.Status, p.RequesterID, p.BuyerID)
	return err
}

func (r *repo) Delete(ctx context.Context, id string) error {
	_, err := r.DB.Exec(ctx, `DELETE FROM purchases WHERE id=$1`, id)
	return err
}

// attachments
func (r *repo) LinkAttachment(ctx context.Context, purchaseID, fileID string) error {
	_, err := r.DB.Exec(ctx, `
		INSERT INTO purchase_attachments (purchase_id, file_id)
		VALUES ($1, $2)
		ON CONFLICT DO NOTHING
	`, purchaseID, fileID)
	return err
}

func (r *repo) UnlinkAttachment(ctx context.Context, purchaseID, fileID string) error {
	_, err := r.DB.Exec(ctx, `
		DELETE FROM purchase_attachments WHERE purchase_id=$1 AND file_id=$2
	`, purchaseID, fileID)
	return err
}
