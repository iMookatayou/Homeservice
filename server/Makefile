DB_DSN ?= postgres://dev:devpass@localhost:5432/homeservice?sslmode=disable

migrate:
	go run ./cmd/migrate -cmd=up -dsn="$(DB_DSN)"

migrate-down:
	go run ./cmd/migrate -cmd=down -dsn="$(DB_DSN)"

migrate-reset:
	go run ./cmd/migrate -cmd=reset -dsn="$(DB_DSN)"

migrate-status:
	go run ./cmd/migrate -cmd=status -dsn="$(DB_DSN)"

seed:
	go run ./cmd/seed -dsn="$(DB_DSN)"

fresh:
	go run ./cmd/migrate -cmd=reset -dsn="$(DB_DSN)"
	go run ./cmd/migrate -cmd=up -dsn="$(DB_DSN)"
	go run ./cmd/seed -dsn="$(DB_DSN)"

run:
	go run ./cmd/api