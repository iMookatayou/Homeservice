# Homeservice Backend

A personal home management API built with Go. Manage bills, purchases, notes, chores, medicine stock, and contractors — all in one place.

---

## Tech Stack

- **Language:** Go 1.24+
- **Router:** Chi
- **Database:** PostgreSQL 16
- **Auth:** JWT (HS256)
- **Storage:** Local / Cloudflare R2
- **Migration:** Goose
- **Container:** Docker + Docker Compose

---

## Project Structure

```
homeservice-backend/
├── cmd/
│   ├── api/          # Main server entrypoint
│   ├── migrate/      # Migration runner
│   └── seed/         # Database seeder
├── internal/
│   ├── auth/         # JWT auth middleware
│   ├── bills/        # Bills module
│   ├── chores/       # Chores module
│   ├── config/       # App configuration
│   ├── contractors/  # Contractors module
│   ├── db/           # Database connection
│   ├── files/        # File upload module
│   ├── health/       # Health check handlers
│   ├── httpx/        # HTTP helpers & middleware
│   ├── medicine/     # Medicine stock module
│   ├── notes/        # Notes module
│   ├── purchases/    # Purchases module
│   ├── storage/      # Storage adapters (Local/R2)
│   └── user/         # User & auth module
├── migrations/       # SQL migration files
├── .env              # Environment variables (not committed)
├── .env.example      # Environment variables template
├── docker-compose.yml
├── Dockerfile
└── Makefile
```

---

## Getting Started

### Prerequisites

- Go 1.24+
- PostgreSQL 16 (or Docker)
- Make (optional)

### 1. Clone & Setup

```bash
git clone https://github.com/iMookatayou/homeservice-backend.git
cd homeservice-backend
cp .env.example .env
```

Edit `.env` with your configuration.

### 2. Start Database

```bash
docker-compose up -d db
```

### 3. Run Migrations

```bash
go run ./cmd/migrate -cmd=up
```

### 4. Seed Database

```bash
go run ./cmd/seed
```

Default admin credentials:
- **Email:** `admin@home.local`
- **Password:** `password`

### 5. Start Server

```bash
go run ./cmd/api
```

Server will start at `http://localhost:8080`

---

## Docker

### Run everything with Docker Compose

```bash
docker-compose up -d
```

This will start both the database and the API server.

---

## Makefile Commands

```bash
make migrate          # Run migrations up
make migrate-down     # Rollback last migration
make migrate-reset    # Reset all migrations
make migrate-status   # Show migration status
make seed             # Seed database
make fresh            # Reset + migrate + seed
make run              # Run API server
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_PORT` | Server port | `8080` |
| `DB_DSN` | PostgreSQL connection string | `postgres://dev:devpass@localhost:5432/homeservice?sslmode=disable` |
| `JWT_SECRET` | JWT signing secret | `change-me` |
| `CORS_ALLOW_ORIGIN` | Allowed CORS origin | `*` |
| `STORAGE_BACKEND` | Storage backend (`local` or `r2`) | `local` |
| `LOCAL_STORAGE_DIR` | Local storage directory | `./data/uploads` |
| `PUBLIC_BASE_URL` | Public URL for file access | `http://localhost:8080/static` |
| `R2_ACCOUNT_ID` | Cloudflare R2 Account ID | - |
| `R2_ACCESS_KEY_ID` | Cloudflare R2 Access Key | - |
| `R2_SECRET_ACCESS_KEY` | Cloudflare R2 Secret Key | - |
| `R2_BUCKET` | Cloudflare R2 Bucket name | - |
| `R2_PUBLIC_URL` | Cloudflare R2 Public URL | - |

---

## API Endpoints

### Auth (Public)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Register new user |
| POST | `/api/v1/auth/login` | Login |
| POST | `/api/v1/auth/logout` | Logout |
| POST | `/api/v1/auth/forgot-password` | Request password reset |
| POST | `/api/v1/auth/reset-password` | Reset password |

### User (Auth Required)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/me` | Get current user |
| PATCH | `/api/v1/me` | Update profile |
| POST | `/api/v1/me/password` | Change password |

### Notes
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/notes` | List notes |
| POST | `/api/v1/notes` | Create note |
| GET | `/api/v1/notes/:id` | Get note |
| PUT | `/api/v1/notes/:id` | Update note |
| DELETE | `/api/v1/notes/:id` | Delete note |
| POST | `/api/v1/notes/:id/pin` | Pin note |
| POST | `/api/v1/notes/:id/unpin` | Unpin note |
| POST | `/api/v1/notes/:id/done` | Mark done |
| POST | `/api/v1/notes/:id/undone` | Mark undone |

### Chores
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/chores` | List chores |
| POST | `/api/v1/chores` | Create chore |
| POST | `/api/v1/chores/:id/claim` | Claim chore |
| POST | `/api/v1/chores/:id/complete` | Complete chore |
| DELETE | `/api/v1/chores/:id` | Delete chore |

### Bills
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/bills` | List bills |
| POST | `/api/v1/bills` | Create bill |
| GET | `/api/v1/bills/:id` | Get bill |
| PATCH | `/api/v1/bills/:id` | Update bill |
| DELETE | `/api/v1/bills/:id` | Delete bill |
| POST | `/api/v1/bills/:id/pay` | Mark as paid |
| GET | `/api/v1/bills/summary` | Bills summary |

### Purchases
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/purchases` | List purchases |
| POST | `/api/v1/purchases` | Create purchase |
| GET | `/api/v1/purchases/:id` | Get purchase |
| PATCH | `/api/v1/purchases/:id` | Update purchase |
| DELETE | `/api/v1/purchases/:id` | Delete purchase |
| POST | `/api/v1/purchases/:id/claim` | Claim purchase |
| POST | `/api/v1/purchases/:id/progress` | Progress status |
| POST | `/api/v1/purchases/:id/cancel` | Cancel purchase |

### Medicine
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/medicine` | List medicine |
| POST | `/api/v1/medicine` | Add medicine |
| GET | `/api/v1/medicine/:id` | Get medicine |
| PATCH | `/api/v1/medicine/:id` | Update medicine |
| DELETE | `/api/v1/medicine/:id` | Delete medicine |
| POST | `/api/v1/medicine/:id/stock` | Adjust stock |
| GET | `/api/v1/medicine/:id/alert` | Get alert |
| PUT | `/api/v1/medicine/:id/alert` | Set alert |
| GET | `/api/v1/medicine/low-stock` | List low stock |
| GET | `/api/v1/medicine/expiring` | List expiring soon |
| GET | `/api/v1/medicine/expired` | List expired |

### Contractors
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/contractors` | List contractors |
| POST | `/api/v1/contractors` | Add contractor |
| GET | `/api/v1/contractors/:id` | Get contractor |
| PATCH | `/api/v1/contractors/:id` | Update contractor |
| DELETE | `/api/v1/contractors/:id` | Delete contractor |
| POST | `/api/v1/contractors/:id/favorite` | Toggle favorite |
| GET | `/api/v1/contractors/favorites` | List favorites |

### Files
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/uploads` | Upload file |
| GET | `/api/v1/files/:id` | Get file |
| DELETE | `/api/v1/files/:id` | Delete file |

### Health
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/healthz` | Liveness check |
| GET | `/readyz` | Readiness check |

---

## Database Schema

| Table | Description |
|-------|-------------|
| `users` | User accounts with roles |
| `notes` | Notes and tasks |
| `chores` | Household chores |
| `bills` | Monthly bills |
| `purchases` | Purchase requests |
| `medicine_items` | Medicine stock |
| `medicine_alerts` | Medicine alerts |
| `contractors` | Contractors list |
| `files` | Uploaded files |
| `password_resets` | Password reset tokens |

---

## License

Private — for personal home use only.