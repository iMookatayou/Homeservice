package bills

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	DB *pgxpool.Pool
}

func (r Repo) GetByID(ctx context.Context, id string) (*Bill, error) {
	row := r.DB.QueryRow(ctx, `
		SELECT id, type, title, amount, due_date, status, paid_at, note, created_by, created_at, updated_at
		FROM bills WHERE id=$1
	`, id)

	var b Bill
	if err := row.Scan(
		&b.ID, &b.Type, &b.Title, &b.Amount, &b.DueDate,
		&b.Status, &b.PaidAt, &b.Note, &b.CreatedBy, &b.CreatedAt, &b.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &b, nil
}

func (r Repo) CreateBill(ctx context.Context, userID string, p CreateBillPayload) (*Bill, error) {
	createdBy, err := uuid.Parse(userID)
	if err != nil {
		return nil, err
	}

	var b Bill
	err = r.DB.QueryRow(ctx, `
		INSERT INTO bills (type, title, amount, due_date, status, note, created_by)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, type, title, amount, due_date, status, paid_at, note, created_by, created_at, updated_at
	`, p.Type, p.Title, p.Amount, p.DueDate, p.Status, p.Note, createdBy).
		Scan(
			&b.ID, &b.Type, &b.Title, &b.Amount, &b.DueDate,
			&b.Status, &b.PaidAt, &b.Note, &b.CreatedBy, &b.CreatedAt, &b.UpdatedAt,
		)
	return &b, err
}

func (r Repo) ListBills(ctx context.Context, q, status string, limit, offset int) ([]Bill, error) {
	var sb strings.Builder
	var args []any
	argIdx := 1

	sb.WriteString(`SELECT id, type, title, amount, due_date, status, paid_at, note, created_by, created_at, updated_at FROM bills WHERE 1=1`)

	if q != "" {
		sb.WriteString(fmt.Sprintf(` AND (title ILIKE $%d OR note ILIKE $%d)`, argIdx, argIdx))
		args = append(args, "%"+q+"%")
		argIdx++
	}

	if status != "" && status != "all" {
		sb.WriteString(fmt.Sprintf(` AND status = $%d`, argIdx))
		args = append(args, status)
		argIdx++
	}

	sb.WriteString(fmt.Sprintf(` ORDER BY due_date DESC LIMIT $%d OFFSET $%d`, argIdx, argIdx+1))
	args = append(args, limit, offset)

	rows, err := r.DB.Query(ctx, sb.String(), args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Bill
	for rows.Next() {
		var b Bill
		if err := rows.Scan(
			&b.ID, &b.Type, &b.Title, &b.Amount, &b.DueDate,
			&b.Status, &b.PaidAt, &b.Note, &b.CreatedBy, &b.CreatedAt, &b.UpdatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (r Repo) UpdateBill(ctx context.Context, id string, p UpdateBillPayload) (*Bill, error) {
	b, err := r.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if p.Type != nil {
		b.Type = *p.Type
	}
	if p.Title != nil {
		b.Title = *p.Title
	}
	if p.Amount != nil {
		b.Amount = *p.Amount
	}
	if p.DueDate != nil {
		b.DueDate = *p.DueDate
	}
	if p.Status != nil {
		b.Status = *p.Status
		if b.Status == "paid" {
			now := time.Now()
			b.PaidAt = &now
		} else {
			b.PaidAt = nil
		}
	}
	if p.Note != nil {
		b.Note = p.Note
	}

	err = r.DB.QueryRow(ctx, `
		UPDATE bills
		SET type=$1, title=$2, amount=$3, due_date=$4, status=$5, note=$6, paid_at=$7, updated_at=now()
		WHERE id=$8
		RETURNING id, type, title, amount, due_date, status, paid_at, note, created_by, created_at, updated_at
	`, b.Type, b.Title, b.Amount, b.DueDate, b.Status, b.Note, b.PaidAt, id).
		Scan(
			&b.ID, &b.Type, &b.Title, &b.Amount, &b.DueDate,
			&b.Status, &b.PaidAt, &b.Note, &b.CreatedBy, &b.CreatedAt, &b.UpdatedAt,
		)
	return b, err
}

func (r Repo) DeleteBill(ctx context.Context, id string) error {
	ct, err := r.DB.Exec(ctx, `DELETE FROM bills WHERE id=$1`, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r Repo) MarkPaid(ctx context.Context, id string) (*Bill, error) {
	now := time.Now()
	var b Bill
	err := r.DB.QueryRow(ctx, `
		UPDATE bills
		SET status='paid', paid_at=$1, updated_at=now()
		WHERE id=$2
		RETURNING id, type, title, amount, due_date, status, paid_at, note, created_by, created_at, updated_at
	`, now, id).Scan(
		&b.ID, &b.Type, &b.Title, &b.Amount, &b.DueDate,
		&b.Status, &b.PaidAt, &b.Note, &b.CreatedBy, &b.CreatedAt, &b.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &b, nil
}

func (r Repo) Summarize(ctx context.Context) ([]Summary, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT type,
		  COUNT(*) AS count,
		  SUM(amount) AS total_amount,
		  SUM(CASE WHEN status='paid' THEN amount ELSE 0 END) AS total_paid,
		  SUM(CASE WHEN status!='paid' THEN amount ELSE 0 END) AS total_unpaid
		FROM bills
		GROUP BY type
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Summary
	for rows.Next() {
		var s Summary
		if err := rows.Scan(&s.Type, &s.Count, &s.TotalAmount, &s.TotalPaid, &s.TotalUnpaid); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}