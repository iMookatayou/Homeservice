package stocks

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("not found")
	ErrConflict = errors.New("conflict")
)

type Repo interface {
	CreateWatch(ctx context.Context, w *StockWatch) error
	UpdateWatch(ctx context.Context, w *StockWatch) error
	DeleteWatch(ctx context.Context, id string, userID string) error
	ListWatch(ctx context.Context, userID, householdID string, f WatchFilter) ([]StockWatch, string, error)

	CreateSnapshot(ctx context.Context, s *StockSnapshot) error
	ListSnapshots(ctx context.Context, watchID string, limit int, cursor string) ([]StockSnapshot, string, error)

	UpsertQuote(ctx context.Context, q *StockQuote) error
	LatestQuote(ctx context.Context, symbol, exchange string) (*StockQuote, error)

	ListDistinctWatchSymbols(ctx context.Context) ([][2]string, error) // [][exchange,symbol]
}

type PgRepo struct{ DB *pgxpool.Pool }

func NewPgRepo(db *pgxpool.Pool) *PgRepo { return &PgRepo{DB: db} }

// --- Implementations (ย่อให้กระชับ / ใส่ SQL หลัก) ---

func (r *PgRepo) CreateWatch(ctx context.Context, w *StockWatch) error {
	// unique scope: (symbol, exchange, scope, coalesce(household_id, created_by))
	sql := `
	INSERT INTO stock_watch (symbol,exchange,display_name,note,tags,scope,household_id,created_by)
	VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
	RETURNING id,created_at;
	`
	return r.DB.QueryRow(ctx, sql,
		w.Symbol, w.Exchange, w.DisplayName, w.Note, w.Tags, w.Scope, w.HouseholdID, w.CreatedBy,
	).Scan(&w.ID, &w.CreatedAt)
}

func (r *PgRepo) UpdateWatch(ctx context.Context, w *StockWatch) error {
	sql := `
	UPDATE stock_watch SET display_name=COALESCE($2,display_name),
		note=COALESCE($3,note), tags=COALESCE($4,tags), scope=COALESCE($5,scope)
	WHERE id=$1 AND created_by=$6
	RETURNING created_by;
	`
	var createdBy string
	if err := r.DB.QueryRow(ctx, sql, w.ID, w.DisplayName, w.Note, w.Tags, w.Scope, w.CreatedBy).Scan(&createdBy); err != nil {
		return err
	}
	return nil
}

func (r *PgRepo) DeleteWatch(ctx context.Context, id string, userID string) error {
	_, err := r.DB.Exec(ctx, `DELETE FROM stock_watch WHERE id=$1 AND created_by=$2`, id, userID)
	return err
}

func (r *PgRepo) ListWatch(ctx context.Context, userID, householdID string, f WatchFilter) ([]StockWatch, string, error) {
	// NOTE: ใช้ created_at,id เป็น cursor (base64) – ย่อที่นี่ (ปล่อย cursor ว่างไปก่อน)
	sql := `
	SELECT id,symbol,exchange,display_name,note,tags,scope,household_id,created_by,created_at
	FROM stock_watch
	WHERE (scope='private' AND created_by=$1)
	   OR (scope='household' AND household_id=$2)
	ORDER BY created_at DESC
	LIMIT $3;
	`
	limit := f.Limit
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	rows, err := r.DB.Query(ctx, sql, userID, householdID, limit)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var list []StockWatch
	for rows.Next() {
		var w StockWatch
		if err := rows.Scan(&w.ID, &w.Symbol, &w.Exchange, &w.DisplayName, &w.Note, &w.Tags, &w.Scope, &w.HouseholdID, &w.CreatedBy, &w.CreatedAt); err != nil {
			return nil, "", err
		}
		list = append(list, w)
	}
	return list, "", nil
}

func (r *PgRepo) CreateSnapshot(ctx context.Context, s *StockSnapshot) error {
	sql := `
	INSERT INTO stock_snapshot (stock_watch_id,title,reason,price_target,files,captured_at)
	VALUES ($1,$2,$3,$4,$5,$6)
	RETURNING id,created_at;
	`
	return r.DB.QueryRow(ctx, sql, s.StockWatchID, s.Title, s.Reason, s.PriceTarget, s.Files, s.CapturedAt).
		Scan(&s.ID, &s.CreatedAt)
}

func (r *PgRepo) ListSnapshots(ctx context.Context, watchID string, limit int, cursor string) ([]StockSnapshot, string, error) {
	sql := `
	SELECT id,stock_watch_id,title,reason,price_target,files,captured_at,created_at
	FROM stock_snapshot WHERE stock_watch_id=$1
	ORDER BY created_at DESC
	LIMIT $2;
	`
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	rows, err := r.DB.Query(ctx, sql, watchID, limit)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var out []StockSnapshot
	for rows.Next() {
		var s StockSnapshot
		if err := rows.Scan(&s.ID, &s.StockWatchID, &s.Title, &s.Reason, &s.PriceTarget, &s.Files, &s.CapturedAt, &s.CreatedAt); err != nil {
			return nil, "", err
		}
		out = append(out, s)
	}
	return out, "", nil
}

func (r *PgRepo) UpsertQuote(ctx context.Context, q *StockQuote) error {
	// ใช้ unique(symbol,exchange,ts)
	sql := `
	INSERT INTO stock_quote(symbol,exchange,ts,price,change,change_pct)
	VALUES ($1,$2,$3,$4,$5,$6)
	ON CONFLICT (symbol,exchange,ts) DO NOTHING;
	`
	_, err := r.DB.Exec(ctx, sql, q.Symbol, q.Exchange, q.TS, q.Price, q.Change, q.ChangePct)
	return err
}

func (r *PgRepo) LatestQuote(ctx context.Context, symbol, exchange string) (*StockQuote, error) {
	sql := `
	SELECT symbol,exchange,ts,price,change,change_pct
	FROM stock_quote
	WHERE symbol=$1 AND exchange=$2
	ORDER BY ts DESC
	LIMIT 1;
	`
	var q StockQuote
	if err := r.DB.QueryRow(ctx, sql, symbol, exchange).Scan(&q.Symbol, &q.Exchange, &q.TS, &q.Price, &q.Change, &q.ChangePct); err != nil {
		return nil, err
	}
	return &q, nil
}

func (r *PgRepo) ListDistinctWatchSymbols(ctx context.Context) ([][2]string, error) {
	rows, err := r.DB.Query(ctx, `SELECT DISTINCT exchange, symbol FROM stock_watch`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out [][2]string
	for rows.Next() {
		var ex, sym string
		if err := rows.Scan(&ex, &sym); err != nil {
			return nil, err
		}
		out = append(out, [2]string{ex, sym})
	}
	return out, nil
}
