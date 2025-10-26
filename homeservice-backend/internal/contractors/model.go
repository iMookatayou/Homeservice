package contractors

type Contractor struct {
	ID        string   `json:"id"`
	Name      string   `json:"name"`
	Types     []string `json:"types"`
	Phone     string   `json:"phone,omitempty"`
	Address   string   `json:"address,omitempty"`
	Lat       float64  `json:"lat"`
	Lng       float64  `json:"lng"`
	Source    string   `json:"source"`               // "osm"
	DistanceM float64  `json:"distance_m,omitempty"` // คำนวณจากพิกัดที่ client ส่งมา
}
