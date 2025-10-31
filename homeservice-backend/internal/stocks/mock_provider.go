package stocks

import (
	"context"
	"math/rand"
	"strings"
	"time"
)

// MockProvider implements Provider (สำหรับ dev/test)
type MockProvider struct{}

func NewMockProvider() *MockProvider {
	rand.Seed(time.Now().UnixNano())
	return &MockProvider{}
}

func (m *MockProvider) GetQuotes(ctx context.Context, pairs [][2]string) (*ProviderBatch, error) {
	now := time.Now()
	items := make([]ProviderQuote, 0, len(pairs))
	for _, p := range pairs {
		ex := strings.ToUpper(p[0])
		sym := strings.ToUpper(p[1])

		base := float64(len(sym))*1.1 + float64(len(ex)) + 10
		delta := (rand.Float64() - 0.5) * 0.5
		price := base + delta
		ch := delta
		chPct := (ch / price) * 100

		items = append(items, ProviderQuote{
			Symbol: sym, Exchange: ex,
			Price: price, Change: &ch, ChangePct: &chPct,
			TS: now, Provider: "mock",
		})
	}
	return &ProviderBatch{Items: items, FetchedAt: now}, nil
}
