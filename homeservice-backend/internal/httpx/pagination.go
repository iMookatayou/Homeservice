package httpx

import (
	"net/http"
	"strconv"
)

type Pagination struct {
	Limit  int `json:"limit"`
	Offset int `json:"offset"`
}

type PaginatedResponse struct {
	Data   any        `json:"data"`
	Paging Pagination `json:"paging"`
}

func ParsePagination(r *http.Request) Pagination {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	return Pagination{Limit: limit, Offset: offset}
}

func Paginate(w http.ResponseWriter, data any, p Pagination) {
	JSON(w, 200, PaginatedResponse{Data: data, Paging: p})
}