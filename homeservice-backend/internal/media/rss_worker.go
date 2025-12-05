package media

import (
	"context"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"time"
)

// RSSWorker
type RSSWorker struct {
	Repo            WorkerRepo
	Every           time.Duration // ex: 3 * time.Minute
	Timeout         time.Duration // ex: 5 * time.Second
	MaxFeedsPerTick int           // ex: 100
	Client          *http.Client
	Now             func() time.Time
}

func NewRSSWorker(repo WorkerRepo, every, timeout time.Duration, maxFeeds int) *RSSWorker {
	return &RSSWorker{
		Repo:            repo,
		Every:           every,
		Timeout:         timeout,
		MaxFeedsPerTick: maxFeeds,
		Client:          &http.Client{Timeout: timeout},
		Now:             time.Now,
	}
}

func (w *RSSWorker) Run(ctx context.Context) error {
	ticker := time.NewTicker(w.Every)
	defer ticker.Stop()

	_ = w.tick(ctx) // run once immediately

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			_ = w.tick(ctx)
		}
	}
}

func (w *RSSWorker) tick(ctx context.Context) error {
	chs, err := w.Repo.ListChannelsWithActiveSubs(ctx, w.MaxFeedsPerTick)
	if err != nil {
		return err
	}

	for _, ch := range chs {
		url := fmt.Sprintf("https://www.youtube.com/feeds/videos.xml?channel_id=%s", ch.ChannelID)
		entries, err := w.fetchRSS(ctx, url)
		if err != nil {
			// TODO: log error
			continue
		}
		for _, e := range entries {
			mp := MediaPost{
				ChannelID:    ch.ID,
				Source:       SourceYouTube,
				ExternalID:   e.VideoID,
				Title:        e.Title,
				URL:          first(e.Link.Href, e.LinkHref, fmt.Sprintf("https://www.youtube.com/watch?v=%s", e.VideoID)),
				ThumbnailURL: strPtr(e.Thumb.URL),
			}
			if t, err := time.Parse(time.RFC3339, e.Published); err == nil {
				tt := t.UTC()
				mp.PublishedAt = &tt
			}
			_, _ = w.Repo.UpsertMediaPost(ctx, &mp)
			// ไม่ยิง notify ตามที่ตกลง — ไว้ค่อยต่อ “ตัวกลาง” ทีหลัง
		}
	}
	return nil
}

// ---------- RSS parsing ----------

type rssFeed struct {
	XMLName xml.Name   `xml:"feed"`
	Entries []rssEntry `xml:"entry"`
}
type rssEntry struct {
	Title     string       `xml:"title"`
	LinkHref  string       `xml:"link"`
	Link      rssLink      `xml:"link"`
	Published string       `xml:"published"`
	VideoID   string       `xml:"{http://www.youtube.com/xml/schemas/2015}videoId"`
	Thumb     rssThumbnail `xml:"{http://search.yahoo.com/mrss/}thumbnail"`
}
type rssLink struct {
	Href string `xml:"href,attr"`
}
type rssThumbnail struct {
	URL string `xml:"url,attr"`
}

func (w *RSSWorker) fetchRSS(ctx context.Context, url string) ([]rssEntry, error) {
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	req.Header.Set("User-Agent", "HomeService-RSS/1.0")
	resp, err := w.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		io.Copy(io.Discard, resp.Body)
		return nil, fmt.Errorf("status %d", resp.StatusCode)
	}
	b, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var feed rssFeed
	if err := xml.Unmarshal(b, &feed); err != nil {
		return nil, err
	}
	// fallback: บาง feed ให้ link เป็น text แทน href
	for i := range feed.Entries {
		if feed.Entries[i].Link.Href == "" {
			feed.Entries[i].Link.Href = feed.Entries[i].LinkHref
		}
	}
	return feed.Entries, nil
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
func first(ss ...string) string {
	for _, s := range ss {
		if s != "" {
			return s
		}
	}
	return ""
}
