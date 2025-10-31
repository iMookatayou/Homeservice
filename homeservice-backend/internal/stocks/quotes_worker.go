package stocks

import (
	"context"
	"time"
)

// QuotesWorker: ดึงราคาชุดจาก Provider แล้ว upsert เข้าฐาน + ใช้จาก cron/ticker
type QuotesWorker struct {
	Repo  Repo
	Prov  Provider
	Every time.Duration
}

func (w *QuotesWorker) Run(ctx context.Context) error {
	t := time.NewTicker(w.Every)
	defer t.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-t.C:
			pairs, err := w.Repo.ListDistinctWatchSymbols(ctx)
			if err != nil || len(pairs) == 0 {
				continue
			}
			batch, err := w.Prov.GetQuotes(ctx, pairs)
			if err != nil {
				continue
			}
			for _, it := range batch.Items {
				_ = w.Repo.UpsertQuote(ctx, &StockQuote{
					Symbol: it.Symbol, Exchange: it.Exchange,
					TS: it.TS, Price: it.Price, Change: it.Change, ChangePct: it.ChangePct,
				})
			}
		}
	}
}
