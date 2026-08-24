package main

import (
	"context"
	"log"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	dsn := os.Getenv("DB_DSN")
	if dsn == "" {
		dsn = "postgres://dev:devpass@localhost:5432/homeservice?sslmode=disable"
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		log.Fatalf("connect failed: %v", err)
	}
	defer pool.Close()

	log.Println("seeding...")

	seedUsers(ctx, pool)
	seedNotes(ctx, pool)
	seedChores(ctx, pool)
	seedBills(ctx, pool)
	seedPurchases(ctx, pool)
	seedMedicine(ctx, pool)
	seedContractors(ctx, pool)

	log.Println("done!")
}