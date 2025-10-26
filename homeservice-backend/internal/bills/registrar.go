package bills

import "github.com/go-chi/chi/v5"

type Registrar struct {
	H Handler
}

func (r Registrar) Register(rt chi.Router) {
	r.H.RegisterRoutes(rt)
}
