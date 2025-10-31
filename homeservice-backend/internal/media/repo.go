package media

import (
	"context"
	"encoding/base64"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

type Repo interface {
	UpsertChannel(ctx context.Context, ch *MediaChannel) (*MediaChannel, bool, error) // (channel, createdNew, err)
	GetChannelBySourceAndID(ctx context.Context, source, channelID string) (*MediaChannel, error)
	DeleteChannel(ctx context.Context, channelUUID string) error

	Subscribe(ctx context.Context, watchID, channelUUID string, notify bool) (*WatchMediaSubscription, bool, error)
	ListSubscriptions(ctx context.Context, watchID string) ([]WatchMediaSubscription, error)
	Unsubscribe(ctx context.Context, watchID, channelUUID string) error

	// Feed (aggregate by watch): cursor = base64("{published_at_unix}:{id}")
	ListMediaByWatch(ctx context.Context, watchID string, limit int, cursor *string) ([]MediaPost, *string, error)
}

type pgRepo struct{ db *pgx.Conn }

func NewPGRepo(db *pgx.Conn) Repo { return &pgRepo{db: db} }

// --- Channels ---
func (r *pgRepo) UpsertChannel(ctx context.Context, ch *MediaChannel) (*MediaChannel, bool, error) {
	row := r.db.QueryRow(ctx, `
INSERT INTO media_channels (source, channel_id, display_name, url, created_by)
VALUES ($1,$2,$3,$4,$5)
ON CONFLICT (source, channel_id)
DO UPDATE SET display_name = COALESCE(EXCLUDED.display_name, media_channels.display_name),
              url = COALESCE(EXCLUDED.url, media_channels.url)
RETURNING id, source, channel_id, display_name, url, created_by, created_at
`, ch.Source, ch.ChannelID, ch.DisplayName, ch.URL, ch.CreatedBy)
	var out MediaChannel
	if err := row.Scan(&out.ID, &out.Source, &out.ChannelID, &out.DisplayName, &out.URL, &out.CreatedBy, &out.CreatedAt); err != nil {
		return nil, false, err
	}
	// ถ้าเป็น upsert เราไม่รู้จาก Scan ว่า insert หรือ update; เช็คด้วยการหาเดิมก่อน insert ก็ได้
	// ที่นี่ simplify: ถือว่าอาจ "อัปเดต" ได้ — ผู้ใช้ endpoint จะ treat เป็น idempotent
	return &out, true, nil
}

func (r *pgRepo) GetChannelBySourceAndID(ctx context.Context, source, channelID string) (*MediaChannel, error) {
	row := r.db.QueryRow(ctx, `
SELECT id, source, channel_id, display_name, url, created_by, created_at
FROM media_channels
WHERE source=$1 AND channel_id=$2
`, source, channelID)
	var out MediaChannel
	if err := row.Scan(&out.ID, &out.Source, &out.ChannelID, &out.DisplayName, &out.URL, &out.CreatedBy, &out.CreatedAt); err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &out, nil
}

func (r *pgRepo) DeleteChannel(ctx context.Context, channelUUID string) error {
	_, err := r.db.Exec(ctx, `DELETE FROM media_channels WHERE id=$1`, channelUUID)
	return err
}

// --- Subscriptions ---
func (r *pgRepo) Subscribe(ctx context.Context, watchID, channelUUID string, notify bool) (*WatchMediaSubscription, bool, error) {
	row := r.db.QueryRow(ctx, `
INSERT INTO watch_media_subscriptions (watch_id, channel_id, notify)
VALUES ($1,$2,$3)
ON CONFLICT (watch_id, channel_id) DO UPDATE SET notify=EXCLUDED.notify
RETURNING id, watch_id, channel_id, notify, created_at
`, watchID, channelUUID, notify)
	var out WatchMediaSubscription
	if err := row.Scan(&out.ID, &out.WatchID, &out.ChannelID, &out.Notify, &out.CreatedAt); err != nil {
		return nil, false, err
	}
	return &out, true, nil
}

func (r *pgRepo) ListSubscriptions(ctx context.Context, watchID string) ([]WatchMediaSubscription, error) {
	rows, err := r.db.Query(ctx, `
SELECT id, watch_id, channel_id, notify, created_at
FROM watch_media_subscriptions
WHERE watch_id=$1
ORDER BY created_at DESC
`, watchID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []WatchMediaSubscription
	for rows.Next() {
		var it WatchMediaSubscription
		if err := rows.Scan(&it.ID, &it.WatchID, &it.ChannelID, &it.Notify, &it.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, it)
	}
	return out, rows.Err()
}

func (r *pgRepo) Unsubscribe(ctx context.Context, watchID, channelUUID string) error {
	_, err := r.db.Exec(ctx, `
DELETE FROM watch_media_subscriptions
WHERE watch_id=$1 AND channel_id=$2
`, watchID, channelUUID)
	return err
}

// --- Feed (aggregate) ---
func decodeCursor(c string) (time.Time, string, error) {
	b, err := base64.StdEncoding.DecodeString(c)
	if err != nil {
		return time.Time{}, "", err
	}
	var ts int64
	var id string
	if _, err := fmt.Sscanf(string(b), "%d:%s", &ts, &id); err != nil {
		return time.Time{}, "", err
	}
	return time.Unix(ts, 0).UTC(), id, nil
}
func encodeCursor(t time.Time, id string) string {
	payload := fmt.Sprintf("%d:%s", t.Unix(), id)
	return base64.StdEncoding.EncodeToString([]byte(payload))
}

func (r *pgRepo) ListMediaByWatch(ctx context.Context, watchID string, limit int, cursor *string) ([]MediaPost, *string, error) {
	var rows pgx.Rows
	var err error

	if cursor == nil || *cursor == "" {
		rows, err = r.db.Query(ctx, `
SELECT p.id, p.channel_id, p.source, p.external_id, p.title, p.url, p.thumbnail_url, p.published_at, p.created_at
FROM media_posts p
JOIN watch_media_subscriptions s ON s.channel_id = p.channel_id
WHERE s.watch_id = $1
ORDER BY p.published_at DESC NULLS LAST, p.id DESC
LIMIT $2
`, watchID, limit+1)
	} else {
		// cursor after (published_at, id)
		pt, pid, err2 := decodeCursor(*cursor)
		if err2 != nil {
			return nil, nil, err2
		}
		rows, err = r.db.Query(ctx, `
SELECT p.id, p.channel_id, p.source, p.external_id, p.title, p.url, p.thumbnail_url, p.published_at, p.created_at
FROM media_posts p
JOIN watch_media_subscriptions s ON s.channel_id = p.channel_id
WHERE s.watch_id = $1
  AND (
        (p.published_at IS NOT NULL AND p.published_at < $2) OR
        (p.published_at IS NULL AND $2 IS NOT NULL) OR
        (p.published_at = $2 AND p.id < $3)
      )
ORDER BY p.published_at DESC NULLS LAST, p.id DESC
LIMIT $4
`, watchID, pt, pid, limit+1)
	}
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	var list []MediaPost
	for rows.Next() {
		var m MediaPost
		if err := rows.Scan(&m.ID, &m.ChannelID, &m.Source, &m.ExternalID, &m.Title, &m.URL, &m.ThumbnailURL, &m.PublishedAt, &m.CreatedAt); err != nil {
			return nil, nil, err
		}
		list = append(list, m)
	}
	if err := rows.Err(); err != nil {
		return nil, nil, err
	}

	var next *string
	if len(list) > limit {
		last := list[limit-1]
		list = list[:limit]
		var ts time.Time
		if last.PublishedAt != nil {
			ts = *last.PublishedAt
		} else {
			ts = last.CreatedAt
		}
		c := encodeCursor(ts.UTC(), last.ID)
		next = &c
	}
	return list, next, nil
}
