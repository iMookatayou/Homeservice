package user

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")

type Repo struct {
	DB *pgxpool.Pool
}

func (r Repo) Create(ctx context.Context, u *User) error {
	return r.DB.QueryRow(ctx, `
		INSERT INTO users (name, email, password_hash)
		VALUES ($1, $2, $3)
		RETURNING id, role, created_at, updated_at
	`, u.Name, u.Email, u.PasswordHash).
		Scan(&u.ID, &u.Role, &u.CreatedAt, &u.UpdatedAt)
}

func (r Repo) ByEmail(ctx context.Context, email string) (*User, error) {
	var u User
	if err := r.DB.QueryRow(ctx, `
		SELECT id, name, email, role, password_hash, created_at, updated_at
		FROM users WHERE email=$1
	`, email).Scan(&u.ID, &u.Name, &u.Email, &u.Role, &u.PasswordHash, &u.CreatedAt, &u.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (r Repo) ByID(ctx context.Context, id string) (*User, error) {
	var u User
	if err := r.DB.QueryRow(ctx, `
		SELECT id, name, email, role, password_hash, created_at, updated_at
		FROM users WHERE id=$1
	`, id).Scan(&u.ID, &u.Name, &u.Email, &u.Role, &u.PasswordHash, &u.CreatedAt, &u.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (r Repo) UpdateName(ctx context.Context, id, name string) (*User, error) {
	var u User
	if err := r.DB.QueryRow(ctx, `
		UPDATE users SET name=$1, updated_at=now()
		WHERE id=$2
		RETURNING id, name, email, role, created_at, updated_at
	`, name, id).Scan(&u.ID, &u.Name, &u.Email, &u.Role, &u.CreatedAt, &u.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (r Repo) UpdatePassword(ctx context.Context, id, hash string) error {
	ct, err := r.DB.Exec(ctx, `
		UPDATE users SET password_hash=$1, updated_at=now() WHERE id=$2
	`, hash, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r Repo) CreatePasswordReset(ctx context.Context, userID string) (string, error) {
	b := make([]byte, 32)
	rand.Read(b)
	token := hex.EncodeToString(b)

	_, err := r.DB.Exec(ctx, `
		INSERT INTO password_resets (user_id, token)
		VALUES ($1, $2)
	`, userID, token)
	if err != nil {
		return "", err
	}
	return token, nil
}

func (r Repo) ValidatePasswordReset(ctx context.Context, token string) (string, error) {
	var userID string
	err := r.DB.QueryRow(ctx, `
		SELECT user_id FROM password_resets
		WHERE token=$1
		  AND used_at IS NULL
		  AND expires_at > now()
	`, token).Scan(&userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", errors.New("invalid or expired token")
		}
		return "", err
	}
	return userID, nil
}

func (r Repo) MarkPasswordResetUsed(ctx context.Context, token string) error {
	_, err := r.DB.Exec(ctx, `
		UPDATE password_resets SET used_at=now() WHERE token=$1
	`, token)
	return err
}