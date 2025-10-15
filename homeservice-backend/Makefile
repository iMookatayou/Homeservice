run:
	go run ./cmd/api

devdb:
	docker compose up -d

migrate:
	psql "$(DB_DSN)" -f migrations/0001_init.sql
