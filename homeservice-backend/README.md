# HomeService Backend (Go + Chi + Postgres)

## Dev quickstart
```bash
cp .env.example .env  
docker compose up -d   
export DB_DSN=postgres://dev:devpass@localhost:5432/homeservice?sslmode=disable
export APP_PORT=8080 JWT_SECRET=change-me
make migrate
go run ./cmd/api
