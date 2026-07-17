package medicine

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	DB *pgxpool.Pool
}

func NewRepo(db *pgxpool.Pool) *Repo {
	return &Repo{DB: db}
}

// Items
func (r *Repo) List(ctx context.Context, f ListItemFilter) ([]MedicineItem, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT id, name, form, unit, category, stock_qty, expiry_date, location, note, created_at, updated_at
		FROM medicine_items
		ORDER BY name ASC
		LIMIT $1 OFFSET $2
	`, f.Limit, f.Offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []MedicineItem
	for rows.Next() {
		var it MedicineItem
		if err := rows.Scan(
			&it.ID, &it.Name, &it.Form, &it.Unit, &it.Category,
			&it.StockQty, &it.ExpiryDate, &it.Location, &it.Note,
			&it.CreatedAt, &it.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

func (r *Repo) GetByID(ctx context.Context, id string) (*MedicineItem, error) {
	row := r.DB.QueryRow(ctx, `
		SELECT id, name, form, unit, category, stock_qty, expiry_date, location, note, created_at, updated_at
		FROM medicine_items
		WHERE id = $1
	`, id)

	var it MedicineItem
	if err := row.Scan(
		&it.ID, &it.Name, &it.Form, &it.Unit, &it.Category,
		&it.StockQty, &it.ExpiryDate, &it.Location, &it.Note,
		&it.CreatedAt, &it.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &it, nil
}

func (r *Repo) Create(ctx context.Context, it *MedicineItem) error {
	return r.DB.QueryRow(ctx, `
		INSERT INTO medicine_items (name, form, unit, category, stock_qty, expiry_date, location, note)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, created_at, updated_at
	`, it.Name, it.Form, it.Unit, it.Category, it.StockQty, it.ExpiryDate, it.Location, it.Note).
		Scan(&it.ID, &it.CreatedAt, &it.UpdatedAt)
}

func (r *Repo) Update(ctx context.Context, id string, p UpdateItemPayload, ed *time.Time) (*MedicineItem, error) {
	it, err := r.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if p.Name != nil {
		it.Name = *p.Name
	}
	if p.Form != nil {
		it.Form = p.Form
	}
	if p.Unit != nil {
		it.Unit = p.Unit
	}
	if p.Category != nil {
		it.Category = p.Category
	}
	if p.StockQty != nil {
		it.StockQty = *p.StockQty
	}
	if ed != nil {
		it.ExpiryDate = ed
	} else if p.ExpiryDate != nil && *p.ExpiryDate == "" {
		it.ExpiryDate = nil
	}
	if p.Location != nil {
		it.Location = p.Location
	}
	if p.Note != nil {
		it.Note = p.Note
	}

	err = r.DB.QueryRow(ctx, `
		UPDATE medicine_items
		SET name=$1, form=$2, unit=$3, category=$4, stock_qty=$5,
		    expiry_date=$6, location=$7, note=$8, updated_at=now()
		WHERE id=$9
		RETURNING updated_at
	`, it.Name, it.Form, it.Unit, it.Category, it.StockQty,
		it.ExpiryDate, it.Location, it.Note, id).
		Scan(&it.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return it, nil
}

func (r *Repo) Delete(ctx context.Context, id string) error {
	ct, err := r.DB.Exec(ctx, `DELETE FROM medicine_items WHERE id=$1`, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Alerts
func (r *Repo) GetAlert(ctx context.Context, itemID string) (*MedicineAlert, error) {
	row := r.DB.QueryRow(ctx, `
		SELECT id, item_id, min_qty, expiry_window_days, is_enabled
		FROM medicine_alerts
		WHERE item_id = $1
	`, itemID)

	var a MedicineAlert
	if err := row.Scan(&a.ID, &a.ItemID, &a.MinQty, &a.ExpiryWindowDays, &a.IsEnabled); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &a, nil
}

func (r *Repo) UpsertAlert(ctx context.Context, a *MedicineAlert) error {
	return r.DB.QueryRow(ctx, `
		INSERT INTO medicine_alerts (item_id, min_qty, expiry_window_days, is_enabled)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (item_id) DO UPDATE
		SET min_qty=$2, expiry_window_days=$3, is_enabled=$4
		RETURNING id
	`, a.ItemID, a.MinQty, a.ExpiryWindowDays, a.IsEnabled).Scan(&a.ID)
}

// Low stock check
func (r *Repo) ListLowStock(ctx context.Context) ([]MedicineItem, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT i.id, i.name, i.form, i.unit, i.category, i.stock_qty, 
		       i.expiry_date, i.location, i.note, i.created_at, i.updated_at
		FROM medicine_items i
		JOIN medicine_alerts a ON a.item_id = i.id
		WHERE a.is_enabled = true
		  AND a.min_qty IS NOT NULL
		  AND i.stock_qty <= a.min_qty
		ORDER BY i.stock_qty ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []MedicineItem
	for rows.Next() {
		var it MedicineItem
		if err := rows.Scan(
			&it.ID, &it.Name, &it.Form, &it.Unit, &it.Category,
			&it.StockQty, &it.ExpiryDate, &it.Location, &it.Note,
			&it.CreatedAt, &it.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

// Expiring soon check
func (r *Repo) ListExpiringSoon(ctx context.Context) ([]MedicineItem, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT i.id, i.name, i.form, i.unit, i.category, i.stock_qty,
		       i.expiry_date, i.location, i.note, i.created_at, i.updated_at
		FROM medicine_items i
		JOIN medicine_alerts a ON a.item_id = i.id
		WHERE a.is_enabled = true
		  AND a.expiry_window_days IS NOT NULL
		  AND i.expiry_date IS NOT NULL
		  AND i.expiry_date <= now() + (a.expiry_window_days || ' days')::interval
		ORDER BY i.expiry_date ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []MedicineItem
	for rows.Next() {
		var it MedicineItem
		if err := rows.Scan(
			&it.ID, &it.Name, &it.Form, &it.Unit, &it.Category,
			&it.StockQty, &it.ExpiryDate, &it.Location, &it.Note,
			&it.CreatedAt, &it.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

// Stock adjustment
func (r *Repo) AdjustStock(ctx context.Context, id string, delta float64) (*MedicineItem, error) {
	row := r.DB.QueryRow(ctx, `
		UPDATE medicine_items
		SET stock_qty = stock_qty + $1, updated_at = now()
		WHERE id = $2
		RETURNING id, name, form, unit, category, stock_qty, expiry_date, location, note, created_at, updated_at
	`, delta, id)

	var it MedicineItem
	if err := row.Scan(
		&it.ID, &it.Name, &it.Form, &it.Unit, &it.Category,
		&it.StockQty, &it.ExpiryDate, &it.Location, &it.Note,
		&it.CreatedAt, &it.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &it, nil
}

// Expire check
func (r *Repo) ListExpired(ctx context.Context) ([]MedicineItem, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT id, name, form, unit, category, stock_qty, expiry_date, location, note, created_at, updated_at
		FROM medicine_items
		WHERE expiry_date IS NOT NULL
		  AND expiry_date < now()
		ORDER BY expiry_date ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []MedicineItem
	for rows.Next() {
		var it MedicineItem
		if err := rows.Scan(
			&it.ID, &it.Name, &it.Form, &it.Unit, &it.Category,
			&it.StockQty, &it.ExpiryDate, &it.Location, &it.Note,
			&it.CreatedAt, &it.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

// UpdateExpiry
func (r *Repo) UpdateExpiry(ctx context.Context, id string, expiry *time.Time) (*MedicineItem, error) {
	row := r.DB.QueryRow(ctx, `
		UPDATE medicine_items
		SET expiry_date = $1, updated_at = now()
		WHERE id = $2
		RETURNING id, name, form, unit, category, stock_qty, expiry_date, location, note, created_at, updated_at
	`, expiry, id)

	var it MedicineItem
	if err := row.Scan(
		&it.ID, &it.Name, &it.Form, &it.Unit, &it.Category,
		&it.StockQty, &it.ExpiryDate, &it.Location, &it.Note,
		&it.CreatedAt, &it.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &it, nil
}

// Locations
func (r *Repo) ListLocations(ctx context.Context) ([]map[string]string, error) {
	rows, err := r.DB.Query(ctx, `SELECT DISTINCT location FROM medicine_items WHERE location IS NOT NULL AND location != '' ORDER BY location ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var locs []map[string]string
	for rows.Next() {
		var loc string
		if err := rows.Scan(&loc); err != nil {
			return nil, err
		}
		locs = append(locs, map[string]string{"id": loc, "name": loc})
	}
	return locs, rows.Err()
}