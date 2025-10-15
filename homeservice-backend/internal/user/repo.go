package user

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct{ DB *pgxpool.Pool }

func (r Repo) Create(ctx context.Context, u *User) error {
	return r.DB.QueryRow(ctx, `
		insert into users (name, email, password_hash)
		values ($1,$2,$3)
		returning id, created_at, updated_at
	`, u.Name, u.Email, u.PasswordHash).Scan(&u.ID, &u.CreatedAt, &u.UpdatedAt)
}
func (r Repo) ByEmail(ctx context.Context, email string) (*User, error) {
	row := r.DB.QueryRow(ctx, `select id,name,email,password_hash,created_at,updated_at from users where email=$1`, email)
	u := new(User)
	if err := row.Scan(&u.ID, &u.Name, &u.Email, &u.PasswordHash, &u.CreatedAt, &u.UpdatedAt); err != nil {
		return nil, err
	}
	return u, nil
}
func (r Repo) ByID(ctx context.Context, id string) (*User, error) {
	row := r.DB.QueryRow(ctx, `select id,name,email,password_hash,created_at,updated_at from users where id=$1`, id)
	u := new(User)
	if err := row.Scan(&u.ID, &u.Name, &u.Email, &u.PasswordHash, &u.CreatedAt, &u.UpdatedAt); err != nil {
		return nil, err
	}
	return u, nil
}
