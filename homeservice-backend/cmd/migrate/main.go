package main

import (
	"context"
	"database/sql"
	"flag"
	"log"
	"os"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
)

func main() {
	cmd := flag.String("cmd", "up", "goose command: up|down|reset|status")
	dsn := flag.String("dsn", "", "postgres DSN")
	flag.Parse()

	if *dsn == "" {
		*dsn = os.Getenv("DB_DSN")
	}
	if *dsn == "" {
		*dsn = "postgres://dev:devpass@localhost:5432/homeservice?sslmode=disable"
	}

	db, err := sql.Open("pgx", *dsn)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	defer db.Close()

	goose.SetDialect("postgres")

	if err := goose.RunContext(context.Background(), *cmd, db, "migrations"); err != nil {
		log.Fatalf("goose %s: %v", *cmd, err)
	}
}