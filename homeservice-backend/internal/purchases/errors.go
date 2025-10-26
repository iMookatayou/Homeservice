package purchases

import "errors"

var (
	// สิทธิ์ไม่พอ เช่น ไม่ใช่ requester/buyer ตามเงื่อนไข
	ErrForbidden = errors.New("forbidden")

	// ธุรกิจขัดแย้ง เช่น อัปเดตเลยเวลาที่แก้ไขได้หรือ transition ผิดลำดับ
	ErrConflict = errors.New("conflict")

	// ใช้เมื่อ resource ไม่พบ เช่น purchase ไม่อยู่ในระบบ
	ErrNotFound = errors.New("purchase not found")

	// ใช้เมื่อ payload ไม่ถูกต้อง เช่น input ไม่ครบหรือ type ไม่ถูก
	ErrBadRequest = errors.New("bad request")
)
