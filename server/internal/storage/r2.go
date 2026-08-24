package storage

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"path/filepath"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/iMookatayou/homeservice-backend/internal/config"
)

type R2 struct {
	client     *s3.Client
	bucket     string
	publicBase string
}

func NewR2(cfg config.Config) (*R2, error) {
	client := s3.New(s3.Options{
		BaseEndpoint: aws.String(fmt.Sprintf("https://%s.r2.cloudflarestorage.com", cfg.R2AccountID)),
		Region:       "auto",
		Credentials: credentials.NewStaticCredentialsProvider(
			cfg.R2AccessKey,
			cfg.R2SecretKey,
			"",
		),
	})

	return &R2{
		client:     client,
		bucket:     cfg.R2Bucket,
		publicBase: strings.TrimRight(cfg.R2PublicURL, "/"),
	}, nil
}

func (r *R2) Save(ctx context.Context, ownerID string, body io.Reader, filename, mime string, size int64) (PutResult, error) {
	key := generateKey(ownerID, filename)

	_, err := r.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(r.bucket),
		Key:           aws.String(key),
		Body:          body,
		ContentType:   aws.String(mime),
		ContentLength: aws.Int64(size),
	})
	if err != nil {
		return PutResult{}, err
	}

	return PutResult{
		URL:      fmt.Sprintf("%s/%s", r.publicBase, key),
		Filename: filepath.Base(key),
		Size:     size,
		MIME:     mime,
	}, nil
}

func (r *R2) PresignPut(ctx context.Context, ownerID, filename, mime string, size int64) (Presign, error) {
	key := generateKey(ownerID, filename)

	presignClient := s3.NewPresignClient(r.client)
	req, err := presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(r.bucket),
		Key:         aws.String(key),
		ContentType: aws.String(mime),
	}, s3.WithPresignExpires(15*time.Minute))
	if err != nil {
		return Presign{}, err
	}

	return Presign{
		URL:    req.URL,
		Expire: time.Now().Add(15 * time.Minute),
	}, nil
}

func (r *R2) Delete(ctx context.Context, key string) error {
	_, err := r.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(r.bucket),
		Key:    aws.String(key),
	})
	return err
}

func generateKey(ownerID, filename string) string {
	b := make([]byte, 8)
	rand.Read(b)
	randPart := hex.EncodeToString(b)
	ext := filepath.Ext(filename)
	return fmt.Sprintf("%s/%s%s", ownerID, randPart, ext)
}