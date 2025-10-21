package notes

import "github.com/go-chi/chi/v5"

// ทำให้โมดูลนี้ implement httpx.RouteRegistrar
type Registrar struct {
	H Handler
}

// ชื่อเมธอดต้องเป็น Register เหมือน interface
func (rg Registrar) Register(r chi.Router) {
	// ถ้าระบบคุณสร้าง prefix /api/v1 แล้วจาก main/router กลางอยู่แล้ว:
	// ก็แค่ปล่อยให้ Handler จัดการเส้นทางย่อย /notes ภายในเอง
	rg.H.RegisterRoutes(r)

	// -- ถ้าระบบของคุณยังไม่ได้ครอบ /api/v1 จากชั้นบน --
	// ให้ใช้แบบนี้แทน:
	// r.Route("/api/v1", func(r chi.Router) {
	//     rg.H.RegisterRoutes(r)
	// })
}
