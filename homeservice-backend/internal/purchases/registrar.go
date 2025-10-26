package purchases

import "github.com/go-chi/chi/v5"

type Registrar struct {
	H Handler
}

func (rg Registrar) Register(r chi.Router) {
	rg.H.RegisterRoutes(r)
}
