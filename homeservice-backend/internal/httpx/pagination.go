package httpx

import (
	"net/http"
	"strconv"
)

type Page struct {
	Page     int `json:"page"`
	PageSize int `json:"page_size"`
	Total    int `json:"total,omitempty"`
}

func ParsePage(r *http.Request, defSize int) Page {
	q := r.URL.Query()
	page, _ := strconv.Atoi(q.Get("page"))
	if page <= 0 {
		page = 1
	}
	size, _ := strconv.Atoi(q.Get("page_size"))
	if size <= 0 {
		size = defSize
	}
	if size > 100 {
		size = 100
	}
	return Page{Page: page, PageSize: size}
}

func (p Page) LimitOffset() (limit, offset int) {
	limit = p.PageSize
	offset = (p.Page - 1) * p.PageSize
	return
}
