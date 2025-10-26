package contractors

import (
	"encoding/json"
	"net/http"
	"sort"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
)

type Handler struct {
	Svc *Service
}

// ใช้ใน main.go หรือ register route ภายในได้เหมือนกัน
func (h Handler) RegisterRoutes(r chi.Router) {
	r.Get("/contractors/search", h.Search)
}

// Handler หลักสำหรับค้นหารายชื่อช่าง
func (h Handler) Search(w http.ResponseWriter, r *http.Request) {
	lat, _ := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
	lng, _ := strconv.ParseFloat(r.URL.Query().Get("lng"), 64)
	if lat == 0 && lng == 0 {
		http.Error(w, "lat/lng required", http.StatusBadRequest)
		return
	}

	radius, _ := strconv.Atoi(r.URL.Query().Get("radius"))
	if radius <= 0 {
		radius = 5000 // default 5 กม.
	}

	q := strings.TrimSpace(r.URL.Query().Get("q"))
	tp := strings.TrimSpace(r.URL.Query().Get("type"))

	// เรียก service ไปค้นจาก Overpass API
	list, err := h.Svc.Search(lat, lng, radius)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}

	// กรองผลลัพธ์ตาม type และ q
	out := make([]Contractor, 0, len(list))
	for _, c := range list {
		if tp != "" && !contains(c.Types, tp) {
			continue
		}
		if q != "" {
			lq := strings.ToLower(q)
			if !strings.Contains(strings.ToLower(c.Name), lq) &&
				!strings.Contains(strings.ToLower(c.Address), lq) &&
				!anyContains(c.Types, lq) {
				continue
			}
		}
		out = append(out, c)
	}

	// เรียงระยะทางใกล้ไปไกล
	sort.Slice(out, func(i, j int) bool { return out[i].DistanceM < out[j].DistanceM })

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(out)
}

func contains(arr []string, v string) bool {
	for _, s := range arr {
		if strings.EqualFold(s, v) {
			return true
		}
	}
	return false
}

func anyContains(arr []string, needle string) bool {
	needle = strings.ToLower(needle)
	for _, s := range arr {
		if strings.Contains(strings.ToLower(s), needle) {
			return true
		}
	}
	return false
}
