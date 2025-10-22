package notes

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("note not found")

type Repo struct {
	DB *pgxpool.Pool
}

type ListFilter struct {
	Query    string
	Category *Category
	Pinned   *bool
	Limit    int
	Offset   int
}

func (r Repo) List(ctx context.Context, userID string, f ListFilter) ([]Note, error) {
	if f.Limit <= 0 || f.Limit > 200 {
		f.Limit = 50
	}
	var args []any
	var where []string
	args = append(args, userID)
	where = append(where, fmt.Sprintf("created_by = $%d", len(args)))

	if f.Query != "" {
		args = append(args, "%"+strings.TrimSpace(f.Query)+"%")
		// เปลี่ยน body -> content
		where = append(where, fmt.Sprintf("(title ILIKE $%d OR content ILIKE $%d)", len(args), len(args)))
	}
	if f.Category != nil {
		args = append(args, *f.Category)
		where = append(where, fmt.Sprintf("category = $%d", len(args)))
	}
	if f.Pinned != nil {
		args = append(args, *f.Pinned)
		where = append(where, fmt.Sprintf("pinned = $%d", len(args)))
	}

	args = append(args, f.Limit, f.Offset)
	sql := `
		SELECT id, title, content, category, pinned, created_by, created_at, updated_at, done_at
		FROM public.notes
		WHERE ` + strings.Join(where, " AND ") + `
		ORDER BY pinned DESC, updated_at DESC
		LIMIT $` + fmt.Sprint(len(args)-1) + ` OFFSET $` + fmt.Sprint(len(args))

	rows, err := r.DB.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Note
	for rows.Next() {
		var n Note
		if err := rows.Scan(
			&n.ID,
			&n.Title,
			&n.Content, // *string รองรับ NULL
			&n.Category,
			&n.Pinned,
			&n.CreatedBy, // *string
			&n.CreatedAt,
			&n.UpdatedAt,
			&n.DoneAt, // *time.Time
		); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

func (r Repo) Get(ctx context.Context, userID, id string) (*Note, error) {
	row := r.DB.QueryRow(ctx, `
		SELECT id, title, content, category, pinned, created_by, created_at, updated_at, done_at
		FROM public.notes
		WHERE id=$1 AND created_by=$2
	`, id, userID)

	var n Note
	if err := row.Scan(
		&n.ID, &n.Title, &n.Content, &n.Category, &n.Pinned,
		&n.CreatedBy, &n.CreatedAt, &n.UpdatedAt, &n.DoneAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &n, nil
}

func (r Repo) Create(ctx context.Context, userID string, in CreateNoteReq) (*Note, error) {
	row := r.DB.QueryRow(ctx, `
		INSERT INTO public.notes (title, content, category, pinned, created_by)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING id, title, content, category, pinned, created_by, created_at, updated_at, done_at
	`, in.Title, in.Content, in.Category, in.Pinned, userID)

	var n Note
	if err := row.Scan(
		&n.ID, &n.Title, &n.Content, &n.Category, &n.Pinned,
		&n.CreatedBy, &n.CreatedAt, &n.UpdatedAt, &n.DoneAt,
	); err != nil {
		return nil, err
	}
	return &n, nil
}

func (r Repo) Update(ctx context.Context, userID, id string, in UpdateNoteReq) (*Note, error) {
	// ดึงก่อนเพื่อ merge
	n, err := r.Get(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	if in.Title != nil {
		n.Title = *in.Title
	}
	if in.Content != nil { // nil=ไม่แก้, &nil=NULL, &""=ค่าว่าง
		n.Content = *in.Content
	}
	if in.Category != nil {
		n.Category = *in.Category
	}
	if in.Pinned != nil {
		n.Pinned = *in.Pinned
	}

	row := r.DB.QueryRow(ctx, `
		UPDATE public.notes
		SET title=$1, content=$2, category=$3, pinned=$4, updated_at=now()
		WHERE id=$5 AND created_by=$6
		RETURNING id, title, content, category, pinned, created_by, created_at, updated_at, done_at
	`, n.Title, n.Content, n.Category, n.Pinned, id, userID)

	var out Note
	if err := row.Scan(
		&out.ID, &out.Title, &out.Content, &out.Category, &out.Pinned,
		&out.CreatedBy, &out.CreatedAt, &out.UpdatedAt, &out.DoneAt,
	); err != nil {
		return nil, err
	}
	return &out, nil
}

func (r Repo) Delete(ctx context.Context, userID, id string) error {
	ct, err := r.DB.Exec(ctx, `DELETE FROM public.notes WHERE id=$1 AND created_by=$2`, id, userID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r Repo) TogglePin(ctx context.Context, userID, id string, pin bool) (*Note, error) {
	row := r.DB.QueryRow(ctx, `
		UPDATE public.notes
		SET pinned=$1, updated_at=now()
		WHERE id=$2 AND created_by=$3
		RETURNING id, title, content, category, pinned, created_by, created_at, updated_at, done_at
	`, pin, id, userID)

	var n Note
	if err := row.Scan(
		&n.ID, &n.Title, &n.Content, &n.Category, &n.Pinned,
		&n.CreatedBy, &n.CreatedAt, &n.UpdatedAt, &n.DoneAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &n, nil
}

// -------- เสร็จสิ้น / ยกเลิกเสร็จสิ้น --------

func (r Repo) MarkDone(ctx context.Context, userID, id string) (*Note, error) {
	row := r.DB.QueryRow(ctx, `
		UPDATE public.notes
		   SET done_at = now(), updated_at = now()
		 WHERE id=$1 AND created_by=$2
		 RETURNING id, title, content, category, pinned, created_by, created_at, updated_at, done_at
	`, id, userID)

	var n Note
	if err := row.Scan(
		&n.ID, &n.Title, &n.Content, &n.Category, &n.Pinned,
		&n.CreatedBy, &n.CreatedAt, &n.UpdatedAt, &n.DoneAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &n, nil
}

func (r Repo) MarkUndone(ctx context.Context, userID, id string) (*Note, error) {
	row := r.DB.QueryRow(ctx, `
		UPDATE public.notes
		   SET done_at = NULL, updated_at = now()
		 WHERE id=$1 AND created_by=$2
		 RETURNING id, title, content, category, pinned, created_by, created_at, updated_at, done_at
	`, id, userID)

	var n Note
	if err := row.Scan(
		&n.ID, &n.Title, &n.Content, &n.Category, &n.Pinned,
		&n.CreatedBy, &n.CreatedAt, &n.UpdatedAt, &n.DoneAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &n, nil
}
