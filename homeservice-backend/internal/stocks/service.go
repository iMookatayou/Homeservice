package stocks

import (
	"context"
	"strings"
	"time"
)

type Provider interface {
	GetQuotes(ctx context.Context, pairs [][2]string) (*ProviderBatch, error)
}

type ProviderQuote struct {
	Symbol, Exchange  string
	Price             float64
	Change, ChangePct *float64
	TS                time.Time
	Provider          string
}
type ProviderBatch struct {
	Items     []ProviderQuote
	NotFound  []string
	FetchedAt time.Time
}

type Service struct {
	Repo       Repo
	Prov       Provider
	StaleAfter time.Duration // e.g. 3 * time.Minute
}

func normalize(ex, sym string) (string, string) {
	return strings.ToUpper(ex), strings.ToUpper(sym)
}

func (s *Service) AddWatch(ctx context.Context, userID, householdID string, p CreateWatchPayload) (*StockWatch, error) {
	ex, sym := normalize(p.Exchange, p.Symbol)
	w := &StockWatch{
		Symbol: sym, Exchange: ex,
		DisplayName: p.DisplayName, Note: p.Note, Tags: p.Tags,
		Scope: p.Scope, CreatedBy: userID,
	}
	if w.Scope == "household" && householdID != "" {
		w.HouseholdID = &householdID
	}
	if err := s.Repo.CreateWatch(ctx, w); err != nil {
		return nil, err
	}
	return w, nil
}

func (s *Service) GetLatestQuote(ctx context.Context, ex, sym string) (*QuoteResponse, error) {
	ex, sym = normalize(ex, sym)
	q, err := s.Repo.LatestQuote(ctx, sym, ex)
	if err != nil {
		return nil, err
	}
	resp := &QuoteResponse{
		Symbol: sym, Exchange: ex,
		Price: q.Price, Change: q.Change, ChangePct: q.ChangePct,
		TS: q.TS, Provider: "cache/db",
	}
	resp.Stale = time.Since(q.TS) > s.StaleAfter
	return resp, nil
}

// batch endpoint 
func (s *Service) GetBatchQuotes(ctx context.Context, pairs [][2]string) (*BatchQuotesResponse, error) {
	var items []QuoteResponse
	for _, p := range pairs {
		ex, sym := normalize(p[0], p[1])
		q, err := s.Repo.LatestQuote(ctx, sym, ex)
		if err != nil {
			continue
		}
		items = append(items, QuoteResponse{
			Symbol: sym, Exchange: ex,
			Price: q.Price, Change: q.Change, ChangePct: q.ChangePct,
			TS: q.TS, Stale: time.Since(q.TS) > s.StaleAfter, Provider: "cache/db",
		})
	}
	return &BatchQuotesResponse{Items: items, FetchedAt: time.Now()}, nil
}

func (s *Service) AddSnapshot(ctx context.Context, watchID string, p CreateSnapshotPayload) (*StockSnapshot, error) {
	ss := &StockSnapshot{
		StockWatchID: watchID,
		Title:        p.Title, Reason: p.Reason, PriceTarget: p.PriceTarget,
		Files: p.Files, CapturedAt: time.Now(),
	}
	if err := s.Repo.CreateSnapshot(ctx, ss); err != nil {
		return nil, err
	}
	return ss, nil
}
