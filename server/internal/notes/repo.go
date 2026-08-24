package notes

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")

type Repo struct {
	DB *pgxpool.Pool
}

const selectCols = `
	id, user_id, title, content, category, pinned, priority,
	due_at, done_at, tags, created_at, updated_at
`

func scanNote(row pgx.Row) (*Note, error) {
	var n Note
	if err := row.Scan(
		&n.ID, &n.UserID, &n.Title, &n.Content, &n.Category,
		&n.Pinned, &n.Priority, &n.DueAt, &n.DoneAt, &n.Tags,
		&n.CreatedAt, &n.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &n, nil
}

func (r Repo) List(ctx context.Context, userID string, f ListFilter) ([]Note, error) {
	if f.Limit <= 0 || f.Limit > 200 {
		f.Limit = 50
	}

	var args []any
	var where []string
	args = append(args, userID)
	where = append(where, fmt.Sprintf("user_id = $%d", len(args)))

	if f.Query != "" {
		args = append(args, "%"+strings.TrimSpace(f.Query)+"%")
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
	if f.Done != nil {
		if *f.Done {
			where = append(where, "done_at IS NOT NULL")
		} else {
			where = append(where, "done_at IS NULL")
		}
	}

	args = append(args, f.Limit, f.Offset)
	sql := `SELECT ` + selectCols + ` FROM notes WHERE ` +
		strings.Join(where, " AND ") +
		` ORDER BY pinned DESC, created_at DESC` +
		fmt.Sprintf(` LIMIT $%d OFFSET $%d`, len(args)-1, len(args))

	rows, err := r.DB.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Note
	for rows.Next() {
		var n Note
		if err := rows.Scan(
			&n.ID, &n.UserID, &n.Title, &n.Content, &n.Category,
			&n.Pinned, &n.Priority, &n.DueAt, &n.DoneAt, &n.Tags,
			&n.CreatedAt, &n.UpdatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

func (r Repo) GetByID(ctx context.Context, userID, id string) (*Note, error) {
	row := r.DB.QueryRow(ctx,
		`SELECT `+selectCols+` FROM notes WHERE id=$1 AND user_id=$2`, id, userID)
	return scanNote(row)
}

func (r Repo) Create(ctx context.Context, userID string, p CreateNotePayload) (*Note, error) {
	if p.Category == "" {
		p.Category = CatGeneral
	}
	if p.Tags == nil {
		p.Tags = []string{}
	}
	row := r.DB.QueryRow(ctx, `
		INSERT INTO notes (user_id, title, content, category, pinned, priority, due_at, tags)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING `+selectCols,
		userID, p.Title, p.Content, p.Category, p.Pinned, p.Priority, p.DueAt, p.Tags,
	)
	return scanNote(row)
}

func (r Repo) Update(ctx context.Context, userID, id string, p UpdateNotePayload) (*Note, error) {
	n, err := r.GetByID(ctx, userID, id)
	if err != nil {
		return nil, err
	}

	if p.Title != nil {
		n.Title = *p.Title
	}
	if p.Content != nil {
		n.Content = p.Content
	}
	if p.Category != nil {
		n.Category = *p.Category
	}
	if p.Pinned != nil {
		n.Pinned = *p.Pinned
	}
	if p.Priority != nil {
		n.Priority = *p.Priority
	}
	if p.DueAt != nil {
		n.DueAt = p.DueAt
	}
	if p.Tags != nil {
		n.Tags = *p.Tags
	}

	row := r.DB.QueryRow(ctx, `
		UPDATE notes
		SET title=$1, content=$2, category=$3, pinned=$4, priority=$5, due_at=$6, tags=$7, updated_at=now()
		WHERE id=$8 AND user_id=$9
		RETURNING `+selectCols,
		n.Title, n.Content, n.Category, n.Pinned, n.Priority, n.DueAt, n.Tags, id, userID,
	)
	return scanNote(row)
}

func (r Repo) Delete(ctx context.Context, userID, id string) error {
	ct, err := r.DB.Exec(ctx, `DELETE FROM notes WHERE id=$1 AND user_id=$2`, id, userID)
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
		UPDATE notes SET pinned=$1, updated_at=now()
		WHERE id=$2 AND user_id=$3
		RETURNING `+selectCols, pin, id, userID)
	return scanNote(row)
}

func (r Repo) MarkDone(ctx context.Context, userID, id string) (*Note, error) {
	row := r.DB.QueryRow(ctx, `
		UPDATE notes SET done_at=now(), updated_at=now()
		WHERE id=$1 AND user_id=$2
		RETURNING `+selectCols, id, userID)
	return scanNote(row)
}

func (r Repo) MarkUndone(ctx context.Context, userID, id string) (*Note, error) {
	row := r.DB.QueryRow(ctx, `
		UPDATE notes SET done_at=NULL, updated_at=now()
		WHERE id=$1 AND user_id=$2
		RETURNING `+selectCols, id, userID)
	return scanNote(row)
}