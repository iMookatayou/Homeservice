package main

import (
	"context"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

var adminID string

func seedUsers(ctx context.Context, db *pgxpool.Pool) {
	err := db.QueryRow(ctx, `
		INSERT INTO users (name, email, password_hash, role)
		VALUES ('Admin', 'admin@home.local', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin')
		ON CONFLICT (email) DO UPDATE SET role = 'admin'
		RETURNING id
	`).Scan(&adminID)
	if err != nil {
		log.Fatalf("seedUsers: %v", err)
	}
	log.Printf("✅ users seeded (admin id: %s)", adminID)
}

func seedNotes(ctx context.Context, db *pgxpool.Pool) {
	notes := []struct {
		title, content, category string
		pinned                   bool
	}{
		{"ซื้อหลอดไฟ", "ห้องนอนใหญ่ไฟขาด", "general", true},
		{"นัดหมอ", "วันศุกร์ 10:00 โรงพยาบาล", "appointment", false},
		{"จ่ายค่าน้ำ", "ครบกำหนดสิ้นเดือน", "bills", false},
	}
	for _, n := range notes {
		_, err := db.Exec(ctx, `
			INSERT INTO notes (user_id, title, content, category, pinned)
			VALUES ($1, $2, $3, $4, $5)
		`, adminID, n.title, n.content, n.category, n.pinned)
		if err != nil {
			log.Printf("seedNotes: %v", err)
		}
	}
	log.Println("✅ notes seeded")
}

func seedChores(ctx context.Context, db *pgxpool.Pool) {
	chores := []struct {
		title, category string
	}{
		{"ล้างจาน", "kitchen"},
		{"กวาดบ้าน", "general"},
		{"ล้างห้องน้ำ", "bathroom"},
		{"ตัดหญ้า", "outdoor"},
	}
	for _, c := range chores {
		_, err := db.Exec(ctx, `
			INSERT INTO chores (title, category, created_by)
			VALUES ($1, $2, $3)
		`, c.title, c.category, adminID)
		if err != nil {
			log.Printf("seedChores: %v", err)
		}
	}
	log.Println("✅ chores seeded")
}

func seedBills(ctx context.Context, db *pgxpool.Pool) {
	bills := []struct {
		billType, title string
		amount          float64
		status          string
	}{
		{"electric", "ค่าไฟเดือนนี้", 1200.00, "unpaid"},
		{"water", "ค่าน้ำเดือนนี้", 350.00, "unpaid"},
		{"internet", "ค่าเน็ต", 590.00, "paid"},
	}
	for _, b := range bills {
		_, err := db.Exec(ctx, `
			INSERT INTO bills (type, title, amount, due_date, status, created_by)
			VALUES ($1, $2, $3, now() + INTERVAL '7 days', $4, $5)
		`, b.billType, b.title, b.amount, b.status, adminID)
		if err != nil {
			log.Printf("seedBills: %v", err)
		}
	}
	log.Println("✅ bills seeded")
}

func seedPurchases(ctx context.Context, db *pgxpool.Pool) {
	_, err := db.Exec(ctx, `
		INSERT INTO purchases (title, note, items, amount_estimated, currency, status, requester_id)
		VALUES 
		('ซื้ออุปกรณ์ทำความสะอาด', 'น้ำยาถูพื้น + ไม้กวาด', '[]', 500.00, 'THB', 'planned', $1),
		('หลอดไฟ LED', 'ห้องนอน 3 หลอด', '[]', 250.00, 'THB', 'bought', $1)
	`, adminID)
	if err != nil {
		log.Printf("seedPurchases: %v", err)
	}
	log.Println("✅ purchases seeded")
}

func seedMedicine(ctx context.Context, db *pgxpool.Pool) {
	medicines := []struct {
		name, form, unit, category string
		qty                        float64
	}{
		{"Paracetamol 500mg", "tablet", "tab", "painkiller", 20},
		{"Cetirizine", "tablet", "tab", "antihistamine", 10},
		{"น้ำเกลือล้างแผล", "liquid", "ml", "wound care", 500},
	}
	for _, m := range medicines {
		_, err := db.Exec(ctx, `
			INSERT INTO medicine_items (name, form, unit, category, stock_qty)
			VALUES ($1, $2, $3, $4, $5)
		`, m.name, m.form, m.unit, m.category, m.qty)
		if err != nil {
			log.Printf("seedMedicine: %v", err)
		}
	}
	log.Println("✅ medicine seeded")
}

func seedContractors(ctx context.Context, db *pgxpool.Pool) {
	_, err := db.Exec(ctx, `
		INSERT INTO contractors (name, types, phone, note, is_favorite, created_by)
		VALUES 
		('ช่างอ้น', '{"electrician"}', '0812345678', 'ช่างไฟแนะนำ', true, $1),
		('ช่างประปาแถวบ้าน', '{"plumber"}', '0898765432', '', false, $1)
	`, adminID)
	if err != nil {
		log.Printf("seedContractors: %v", err)
	}
	log.Println("✅ contractors seeded")
}