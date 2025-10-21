package purchases

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrAttachmentExists = errors.New("attachment already exists")

type AttachRepo struct {
	DB *pgxpool.Pool
}

type Attachment struct {
	FileID     string `json:"file_id"`
	Filename   string `json:"filename"`
	MIME       string `json:"mimetype"`
	Size       int64  `json:"size"`
	StorageURL string `json:"storage_url"`
}

func (r AttachRepo) Attach(ctx context.Context, purchaseID, fileID string) error {
	const q = `
	INSERT INTO purchase_attachments (purchase_id, file_id)
	VALUES ($1::uuid, $2::uuid) ON CONFLICT DO NOTHING`
	ct, err := r.DB.Exec(ctx, q, purchaseID, fileID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrAttachmentExists
	}
	return nil
}

func (r AttachRepo) List(ctx context.Context, purchaseID string) ([]Attachment, error) {
	const q = `
	SELECT f.id, f.filename, f.mimetype, f.size, f.storage_url
	FROM purchase_attachments pa
	JOIN files f ON f.id = pa.file_id
	WHERE pa.purchase_id = $1::uuid
	ORDER BY f.created_at DESC`
	rows, err := r.DB.Query(ctx, q, purchaseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Attachment
	for rows.Next() {
		var a Attachment
		if err := rows.Scan(&a.FileID, &a.Filename, &a.MIME, &a.Size, &a.StorageURL); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (r AttachRepo) Detach(ctx context.Context, purchaseID, fileID string) error {
	const q = `DELETE FROM purchase_attachments WHERE purchase_id=$1::uuid AND file_id=$2::uuid`
	_, err := r.DB.Exec(ctx, q, purchaseID, fileID)
	return err
}

// helper: ตรวจเจ้าของคำขอ
func (r AttachRepo) IsOwner(ctx context.Context, purchaseID, userID string) (bool, error) {
	const q = `SELECT 1 FROM purchase_requests WHERE id=$1::uuid AND user_id=$2::uuid`
	var tmp int
	if err := r.DB.QueryRow(ctx, q, purchaseID, userID).Scan(&tmp); err != nil {
		return false, nil
	}
	return true, nil
}
