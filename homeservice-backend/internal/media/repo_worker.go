package media

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type WorkerRepo interface {
	ListChannelsWithActiveSubs(ctx context.Context, limit int) ([]MediaChannel, error)
	UpsertMediaPost(ctx context.Context, p *MediaPost) (created bool, err error)
}

type workerRepo struct{ db *pgxpool.Pool }

func NewWorkerRepo(db *pgxpool.Pool) WorkerRepo { return &workerRepo{db: db} }

// ดึงเฉพาะ channel ที่ "มีคน subscribe และตั้ง notify=true"
func (r *workerRepo) ListChannelsWithActiveSubs(ctx context.Context, limit int) ([]MediaChannel, error) {
	rows, err := r.db.Query(ctx, `
SELECT DISTINCT c.id::text, c.source, c.channel_id, c.display_name, c.url, c.created_by::text, c.created_at
FROM media_channels c
WHERE EXISTS (
  SELECT 1 FROM watch_media_subscriptions s
  WHERE s.channel_id = c.id AND s.notify = true
)
ORDER BY c.created_at DESC
LIMIT $1
`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []MediaChannel
	for rows.Next() {
		var m MediaChannel
		if err := rows.Scan(&m.ID, &m.Source, &m.ChannelID, &m.DisplayName, &m.URL, &m.CreatedBy, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// Upsert media_posts ด้วย UNIQUE (source, external_id)
// คืนค่า created=true เมื่อเป็น insert ใหม่จริง (ใช้ xmax = 0 ตรวจจับ)
func (r *workerRepo) UpsertMediaPost(ctx context.Context, p *MediaPost) (bool, error) {
	row := r.db.QueryRow(ctx, `
INSERT INTO media_posts (channel_id, source, external_id, title, url, thumbnail_url, published_at, raw)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
ON CONFLICT (source, external_id)
DO UPDATE SET
  title = EXCLUDED.title,
  url = EXCLUDED.url,
  thumbnail_url = COALESCE(EXCLUDED.thumbnail_url, media_posts.thumbnail_url),
  published_at  = COALESCE(EXCLUDED.published_at, media_posts.published_at),
  raw           = COALESCE(EXCLUDED.raw, media_posts.raw)
RETURNING id::text, channel_id::text, source, external_id, title, url, thumbnail_url, published_at, created_at, xmax = 0 AS created_new
`, p.ChannelID, p.Source, p.ExternalID, p.Title, p.URL, p.ThumbnailURL, p.PublishedAt, nil)
	var got MediaPost
	var createdNew bool
	if err := row.Scan(&got.ID, &got.ChannelID, &got.Source, &got.ExternalID, &got.Title, &got.URL, &got.ThumbnailURL, &got.PublishedAt, &got.CreatedAt, &createdNew); err != nil {
		return false, err
	}
	*p = got
	return createdNew, nil
}
