-- +goose Up
CREATE TABLE purchase_attachments (
    purchase_id UUID REFERENCES purchases(id) ON DELETE CASCADE,
    file_id UUID REFERENCES files(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (purchase_id, file_id)
);

-- +goose Down
DROP TABLE purchase_attachments;
