package contractors

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

func NewRepo(db *pgxpool.Pool) *Repo {
	return &Repo{DB: db}
}

func (r *Repo) List(ctx context.Context, onlyFavorites bool, limit, offset int) ([]Contractor, error) {
	q := `
		SELECT id, name, types, phone, address, lat, lng, google_maps_url, note, is_favorite, created_by, created_at, updated_at
		FROM contractors
	`
	if onlyFavorites {
		q += ` WHERE is_favorite = true`
	}
	q += fmt.Sprintf(` ORDER BY is_favorite DESC, name ASC LIMIT %d OFFSET %d`, limit, offset)

	rows, err := r.DB.Query(ctx, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Contractor
	for rows.Next() {
		var c Contractor
		if err := rows.Scan(
			&c.ID, &c.Name, &c.Types, &c.Phone, &c.Address,
			&c.Lat, &c.Lng, &c.GoogleMapsURL, &c.Note,
			&c.IsFavorite, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *Repo) Search(ctx context.Context, f SearchFilter) ([]ContractorSearchResult, error) {
	var sb strings.Builder
	var args []any
	argIdx := 1

	selectClause := `SELECT id, name, types, phone, address, lat, lng, google_maps_url, note, is_favorite, created_by, created_at, updated_at`
	distanceClause := `, CAST(NULL AS FLOAT) as distance_m`

	if f.Lat != nil && f.Lng != nil {
		distanceClause = fmt.Sprintf(`, ( 6371000 * acos( cos( radians($%d) ) * cos( radians( lat ) ) * cos( radians( lng ) - radians($%d) ) + sin( radians($%d) ) * sin( radians( lat ) ) ) ) AS distance_m`, argIdx, argIdx+1, argIdx)
		args = append(args, *f.Lat, *f.Lng)
		argIdx += 2
	}

	sb.WriteString(selectClause)
	sb.WriteString(distanceClause)
	sb.WriteString(` FROM contractors WHERE 1=1`)

	if f.Query != "" {
		sb.WriteString(fmt.Sprintf(` AND (name ILIKE $%d OR address ILIKE $%d OR note ILIKE $%d)`, argIdx, argIdx, argIdx))
		args = append(args, "%"+f.Query+"%")
		argIdx++
	}

	if f.Type != "" {
		sb.WriteString(fmt.Sprintf(` AND $%d = ANY(types)`, argIdx))
		args = append(args, f.Type)
		argIdx++
	}

	if f.Lat != nil && f.Lng != nil && f.Radius != nil && *f.Radius > 0 {
		sb.WriteString(fmt.Sprintf(` AND lat IS NOT NULL AND lng IS NOT NULL AND ( 6371000 * acos( cos( radians($1) ) * cos( radians( lat ) ) * cos( radians( lng ) - radians($2) ) + sin( radians($1) ) * sin( radians( lat ) ) ) ) <= $%d`, argIdx))
		args = append(args, *f.Radius)
		argIdx++
	}

	if f.Lat != nil && f.Lng != nil {
		sb.WriteString(` ORDER BY distance_m ASC`)
	} else {
		sb.WriteString(` ORDER BY is_favorite DESC, name ASC`)
	}

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

	var out []ContractorSearchResult
	for rows.Next() {
		var c ContractorSearchResult
		if err := rows.Scan(
			&c.ID, &c.Name, &c.Types, &c.Phone, &c.Address,
			&c.Lat, &c.Lng, &c.GoogleMapsURL, &c.Note,
			&c.IsFavorite, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt,
			&c.DistanceM,
		); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *Repo) GetByID(ctx context.Context, id string) (*Contractor, error) {
	row := r.DB.QueryRow(ctx, `
		SELECT id, name, types, phone, address, lat, lng, google_maps_url, note, is_favorite, created_by, created_at, updated_at
		FROM contractors
		WHERE id = $1
	`, id)

	var c Contractor
	if err := row.Scan(
		&c.ID, &c.Name, &c.Types, &c.Phone, &c.Address,
		&c.Lat, &c.Lng, &c.GoogleMapsURL, &c.Note,
		&c.IsFavorite, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &c, nil
}

func (r *Repo) Create(ctx context.Context, c *Contractor) error {
	return r.DB.QueryRow(ctx, `
		INSERT INTO contractors (name, types, phone, address, lat, lng, google_maps_url, note, is_favorite, created_by)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, created_at, updated_at
	`, c.Name, c.Types, c.Phone, c.Address, c.Lat, c.Lng,
		c.GoogleMapsURL, c.Note, c.IsFavorite, c.CreatedBy).
		Scan(&c.ID, &c.CreatedAt, &c.UpdatedAt)
}

func (r *Repo) Update(ctx context.Context, id string, p UpdateContractorPayload) (*Contractor, error) {
	c, err := r.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if p.Name != nil {
		c.Name = *p.Name
	}
	if p.Types != nil {
		c.Types = p.Types
	}
	if p.Phone != nil {
		c.Phone = p.Phone
	}
	if p.Address != nil {
		c.Address = p.Address
	}
	if p.Lat != nil {
		c.Lat = p.Lat
	}
	if p.Lng != nil {
		c.Lng = p.Lng
	}
	if p.GoogleMapsURL != nil {
		c.GoogleMapsURL = p.GoogleMapsURL
	}
	if p.Note != nil {
		c.Note = p.Note
	}

	err = r.DB.QueryRow(ctx, `
		UPDATE contractors
		SET name=$1, types=$2, phone=$3, address=$4, lat=$5, lng=$6,
		    google_maps_url=$7, note=$8, updated_at=now()
		WHERE id=$9
		RETURNING updated_at
	`, c.Name, c.Types, c.Phone, c.Address, c.Lat, c.Lng,
		c.GoogleMapsURL, c.Note, id).Scan(&c.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return c, nil
}

func (r *Repo) Delete(ctx context.Context, id string) error {
	ct, err := r.DB.Exec(ctx, `DELETE FROM contractors WHERE id=$1`, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repo) ToggleFavorite(ctx context.Context, id string) (*Contractor, error) {
	row := r.DB.QueryRow(ctx, `
		UPDATE contractors
		SET is_favorite = NOT is_favorite, updated_at = now()
		WHERE id = $1
		RETURNING id, name, types, phone, address, lat, lng, google_maps_url, note, is_favorite, created_by, created_at, updated_at
	`, id)

	var c Contractor
	if err := row.Scan(
		&c.ID, &c.Name, &c.Types, &c.Phone, &c.Address,
		&c.Lat, &c.Lng, &c.GoogleMapsURL, &c.Note,
		&c.IsFavorite, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &c, nil
}