package contractors

import "github.com/go-chi/chi/v5"

// ให้สไตล์เดียวกับ notes.Registrar
type Registrar struct{ H Handler }

func (rg Registrar) Register(r chi.Router) {
	rg.H.RegisterRoutes(r.Route("/contractors", func(rr chi.Router) {}))
	// หมายเหตุ: ข้างบนเป็นทริคให้ prefix /contractors เดียว
}
