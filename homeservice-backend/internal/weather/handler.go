package weather

import (
	"encoding/json"
	"net/http"
)

type Handler struct{}

func (h Handler) Today(w http.ResponseWriter, r *http.Request) {
	// TODO: proxy ไป provider + cache ใน weather_cache
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"location":  "Bangkok",
		"temp_c":    30.5,
		"humidity":  70,
		"condition": "Partly Cloudy",
	})
}
