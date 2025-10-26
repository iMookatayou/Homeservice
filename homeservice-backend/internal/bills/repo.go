package bills

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	DB *pgxpool.Pool
}

// CreateBill เพิ่มบิลใหม่
func (r Repo) CreateBill(ctx context.Context, b *Bill) error {
	_, err := r.DB.Exec(ctx, `
        INSERT INTO bills (id, type, title, amount, billing_period_start, billing_period_end,
          due_date, status, paid_at, note, created_by, created_at, updated_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
		b.ID, b.Type, b.Title, b.Amount,
		b.BillingPeriodStart, b.BillingPeriodEnd,
		b.DueDate, b.Status, b.PaidAt, b.Note,
		b.CreatedBy, b.CreatedAt, b.UpdatedAt,
	)
	return err
}

// ListBills ดึงรายการบิลทั้งหมด
func (r Repo) ListBills(ctx context.Context) ([]Bill, error) {
	rows, err := r.DB.Query(ctx, `
        SELECT id, type, title, amount, billing_period_start, billing_period_end,
          due_date, status, paid_at, note, created_by, created_at, updated_at
        FROM bills
        ORDER BY due_date DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []Bill
	for rows.Next() {
		var b Bill
		if err := rows.Scan(
			&b.ID, &b.Type, &b.Title, &b.Amount,
			&b.BillingPeriodStart, &b.BillingPeriodEnd,
			&b.DueDate, &b.Status, &b.PaidAt, &b.Note,
			&b.CreatedBy, &b.CreatedAt, &b.UpdatedAt,
		); err != nil {
			return nil, err
		}
		result = append(result, b)
	}
	return result, nil
}

// Summarize ดึงยอดรวมตามประเภทบิล
func (r Repo) Summarize(ctx context.Context) ([]Summary, error) {
	rows, err := r.DB.Query(ctx, `
        SELECT type,
          COUNT(*) AS count,
          SUM(amount) AS total_amount,
          SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END) AS total_paid,
          SUM(CASE WHEN status != 'paid' THEN amount ELSE 0 END) AS total_unpaid
        FROM bills
        GROUP BY type`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []Summary
	for rows.Next() {
		var s Summary
		if err := rows.Scan(&s.Type, &s.Count, &s.TotalAmount, &s.TotalPaid, &s.TotalUnpaid); err != nil {
			return nil, err
		}
		result = append(result, s)
	}
	return result, nil
}
