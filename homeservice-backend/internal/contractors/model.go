package contractors

import "time"

type Contractor struct {
	ID            string    `json:"id"`
	Name          string    `json:"name"`
	Types         []string  `json:"types"`
	Phone         *string   `json:"phone,omitempty"`
	Address       *string   `json:"address,omitempty"`
	Lat           *float64  `json:"lat,omitempty"`
	Lng           *float64  `json:"lng,omitempty"`
	GoogleMapsURL *string   `json:"google_maps_url,omitempty"`
	Note          *string   `json:"note,omitempty"`
	IsFavorite    bool      `json:"is_favorite"`
	CreatedBy     string    `json:"created_by"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type CreateContractorPayload struct {
	Name          string   `json:"name"`
	Types         []string `json:"types"`
	Phone         *string  `json:"phone,omitempty"`
	Address       *string  `json:"address,omitempty"`
	Lat           *float64 `json:"lat,omitempty"`
	Lng           *float64 `json:"lng,omitempty"`
	GoogleMapsURL *string  `json:"google_maps_url,omitempty"`
	Note          *string  `json:"note,omitempty"`
	IsFavorite    bool     `json:"is_favorite"`
}

type UpdateContractorPayload struct {
	Name          *string  `json:"name,omitempty"`
	Types         []string `json:"types,omitempty"`
	Phone         *string  `json:"phone,omitempty"`
	Address       *string  `json:"address,omitempty"`
	Lat           *float64 `json:"lat,omitempty"`
	Lng           *float64 `json:"lng,omitempty"`
	GoogleMapsURL *string  `json:"google_maps_url,omitempty"`
	Note          *string  `json:"note,omitempty"`
}

type SearchFilter struct {
	Query  string
	Type   string
	Lat    *float64
	Lng    *float64
	Radius *float64
	Limit  int
	Offset int
}

type ContractorSearchResult struct {
	Contractor
	DistanceM *float64 `json:"distance_m,omitempty"`
}