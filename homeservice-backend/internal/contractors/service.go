package contractors

import (
	"bytes"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"
	"strings"
)

type Service struct {
	Http     *http.Client
	Repo     *Repo
	Endpoint string
}

func NewService(h *http.Client, repo *Repo, endpoint string) *Service {
	if endpoint == "" {
		endpoint = "https://overpass-api.de/api/interpreter"
	}
	return &Service{Http: h, Repo: repo, Endpoint: endpoint}
}

func (s *Service) Search(lat, lng float64, radius int) ([]Contractor, error) {
	key := CacheKey{Lat: int(lat * 1e4), Lng: int(lng * 1e4), Radius: radius}
	if s.Repo != nil {
		if v, ok := s.Repo.Get(key); ok {
			for i := range v {
				v[i].DistanceM = haversine(lat, lng, v[i].Lat, v[i].Lng)
			}
			return v, nil
		}
	}

	q := fmt.Sprintf(`
[out:json][timeout:25];
(
  node["craft"~"electrician|plumber|carpenter|hvac"](around:%d,%f,%f);
  way["craft"~"electrician|plumber|carpenter|hvac"](around:%d,%f,%f);
  relation["craft"~"electrician|plumber|carpenter|hvac"](around:%d,%f,%f);
);
out center tags;`, radius, lat, lng, radius, lat, lng, radius, lat, lng)

	resp, err := s.Http.Post(s.Endpoint, "text/plain", bytes.NewBufferString(q))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	raw, _ := io.ReadAll(resp.Body)
	var over struct {
		Elements []struct {
			ID     int64                      `json:"id"`
			Lat    float64                    `json:"lat"`
			Lon    float64                    `json:"lon"`
			Center struct{ Lat, Lon float64 } `json:"center"`
			Tags   map[string]string          `json:"tags"`
		} `json:"elements"`
	}
	if err := json.Unmarshal(raw, &over); err != nil {
		return nil, err
	}

	var out []Contractor
	for _, e := range over.Elements {
		name := strings.TrimSpace(first(e.Tags["name"], e.Tags["operator"]))
		if name == "" {
			continue
		}
		types := mapCraft(e.Tags["craft"])
		if len(types) == 0 {
			continue
		}
		la, lo := e.Lat, e.Lon
		if la == 0 && lo == 0 {
			la, lo = e.Center.Lat, e.Center.Lon
		}

		c := Contractor{
			ID:      shortHash("osm:" + strconv.FormatInt(e.ID, 10)),
			Name:    name,
			Types:   types,
			Phone:   first(e.Tags["contact:phone"], e.Tags["phone"]),
			Address: buildAddr(e.Tags),
			Lat:     la,
			Lng:     lo,
			Source:  "osm",
		}
		c.DistanceM = haversine(lat, lng, c.Lat, c.Lng)
		out = append(out, c)
	}

	if s.Repo != nil {
		s.Repo.Set(key, out)
	}
	return out, nil
}

// --- helpers ---
func first(ss ...string) string {
	for _, s := range ss {
		if strings.TrimSpace(s) != "" {
			return s
		}
	}
	return ""
}
func mapCraft(c string) []string {
	switch strings.ToLower(c) {
	case "electrician":
		return []string{"electrician"}
	case "plumber":
		return []string{"plumber"}
	case "carpenter":
		return []string{"carpenter"}
	case "hvac":
		return []string{"hvac"}
	default:
		return nil
	}
}
func buildAddr(t map[string]string) string {
	parts := []string{
		t["addr:housenumber"], t["addr:street"],
		t["addr:suburb"], t["addr:city"], t["addr:postcode"],
	}
	res := strings.Join(filter(parts), " ")
	if res == "" {
		res = t["addr:full"]
	}
	return strings.TrimSpace(res)
}
func filter(a []string) []string {
	r := make([]string, 0, len(a))
	for _, s := range a {
		if strings.TrimSpace(s) != "" {
			r = append(r, s)
		}
	}
	return r
}
func shortHash(s string) string {
	h := sha1.Sum([]byte(s))
	return hex.EncodeToString(h[:8])
}
func haversine(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371000.0
	dLat := (lat2 - lat1) * math.Pi / 180
	dLon := (lon2 - lon1) * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c
}
