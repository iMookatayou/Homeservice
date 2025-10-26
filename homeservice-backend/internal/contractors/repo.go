package contractors

import (
	"sync"
	"time"
)

type CacheKey struct {
	Lat    int
	Lng    int
	Radius int
}
type cacheItem struct {
	Data      []Contractor
	CreatedAt time.Time
}

type Repo struct {
	mu   sync.RWMutex
	data map[CacheKey]cacheItem
	TTL  time.Duration
}

func NewRepo(ttl time.Duration) *Repo {
	return &Repo{data: make(map[CacheKey]cacheItem), TTL: ttl}
}

func (r *Repo) Get(key CacheKey) (out []Contractor, ok bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	it, ok := r.data[key]
	if !ok || time.Since(it.CreatedAt) > r.TTL {
		return nil, false
	}
	return it.Data, true
}

func (r *Repo) Set(key CacheKey, in []Contractor) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.data[key] = cacheItem{Data: in, CreatedAt: time.Now()}
}
