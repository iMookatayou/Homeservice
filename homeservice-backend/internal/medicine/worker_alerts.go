// internal/medicine/worker_alerts.go
package medicine

import (
	"context"
	"fmt"
	"time"
)

// Notifier คือสัญญาที่ฝั่งระบบแจ้งเตือนของคุณต้องทำให้ได้
// คุณสามารถผูกกับ notification service, push, หรือ in-app feed ตามที่มีอยู่
type Notifier interface {
	NotifyLowStock(ctx context.Context, householdID, itemID string, message string) error
	NotifyExpiring(ctx context.Context, householdID, itemID string, message string) error
}

// AlertWorker ทำหน้าที่สแกนยาในบ้าน และส่งแจ้งเตือน "ใกล้หมด" / "ใกล้หมดอายุ"
// หมายเหตุ: การกันซ้ำ/คูลดาวน์ ควรจัดการในชั้น Notifier หรือ notification service ของคุณ
type AlertWorker struct {
	Svc      *Service
	Notifier Notifier
	Now      func() time.Time
}

// RunOnce สแกนและส่งแจ้งเตือนสำหรับบ้านหนึ่งหลัง
// - ใช้กติกา alert ต่อ item (min_qty, expiry_window_days) จาก DB (ผ่าน Service.ListItems)
// - สาระสำคัญ: ไม่แตะ SQL ตรง ๆ เพื่อให้ logic อยู่ที่ Service ที่เดียว
func (w *AlertWorker) RunOnce(ctx context.Context, householdID string) error {
	if w.Svc == nil || w.Notifier == nil {
		return fmt.Errorf("worker not wired: svc or notifier is nil")
	}
	now := w.now()

	// ใช้ filter ว่าง ๆ ให้ Service เติม flag LowStock/Expiring ให้เรียบร้อย
	items, err := w.Svc.ListItems(ctx, householdID, ListItemFilter{})
	if err != nil {
		return err
	}

	for _, it := range items {
		// แจ้งเตือนใกล้หมด
		if it.LowStock {
			msg := fmt.Sprintf("“%s” สต็อกใกล้หมด (คงเหลือ %.3f %s)", it.Item.Name, it.TotalQty, it.Item.Unit)
			_ = w.Notifier.NotifyLowStock(ctx, it.Item.HouseholdID, it.Item.ID, msg)
		}

		// แจ้งเตือนใกล้หมดอายุ
		if it.Expiring && it.NextExpiry != nil {
			days := int(it.NextExpiry.Sub(now).Hours() / 24) // อาจเป็นค่าติดลบถ้าหมดแล้ว
			var msg string
			if days >= 0 {
				msg = fmt.Sprintf("“%s” ใกล้หมดอายุใน %d วัน (หมดอายุ %s)", it.Item.Name, days, it.NextExpiry.Format("2006-01-02"))
			} else {
				msg = fmt.Sprintf("“%s” หมดอายุมาแล้ว %d วัน (หมดอายุ %s)", it.Item.Name, -days, it.NextExpiry.Format("2006-01-02"))
			}
			_ = w.Notifier.NotifyExpiring(ctx, it.Item.HouseholdID, it.Item.ID, msg)
		}
	}
	return nil
}

// Helper: ใช้เวลา Now() ที่ฉีดเข้ามาได้ทดสอบง่าย
func (w *AlertWorker) now() time.Time {
	if w.Now != nil {
		return w.Now()
	}
	return time.Now()
}

/*
การใช้งาน (ตัวอย่าง):

// wire
repo := medicine.NewPGRepo(appDB)
svc  := &medicine.Service{Repo: repo, Now: time.Now}
note := &notifications.Service{DB: appDB} // ต้องมีเมธอดตาม Notifier

worker := &medicine.AlertWorker{
    Svc: svc,
    Notifier: note,
    Now: time.Now,
}

// schedule อาจวิ่งทุกวัน 07:00
_ = worker.RunOnce(ctx, "<household-id>")
*/
