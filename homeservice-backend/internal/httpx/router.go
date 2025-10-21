package httpx

import "github.com/go-chi/chi/v5"

type RouteRegistrar interface {
	Register(r chi.Router)
}
