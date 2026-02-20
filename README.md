# Auth Service — Centralized SSO Server

A centralized authentication and Single Sign-On (SSO) service powered by **Keycloak 26**.  
Designed to provide identity and access management for multiple independent applications.

---

## What is this?

A standalone auth server that you can sell as a service to different businesses (stores, clinics, etc.).  
Each business gets its own isolated environment (realm) with its own users, roles, and branding.

```
                    ┌──────────────────────┐
                    │    Auth Service       │
                    │  (Keycloak + Nginx)   │
                    └──────────┬───────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                     │
   ┌──────▼──────┐     ┌──────▼──────┐      ┌──────▼──────┐
   │ Store App   │     │ Clinic App  │      │ Future App  │
   │ (Realm A)   │     │ (Realm B)   │      │ (Realm C)   │
   └─────────────┘     └─────────────┘      └─────────────┘
```

---

## Quick Start (Development)

### Prerequisites

- Docker 24+
- Docker Compose 2+

### 1. Clone & Configure

```bash
cd auth-service/docker
cp .env.example .env
# Edit .env with your values
```

### 2. Start Services

```bash
cd docker
docker compose up -d
```

### 3. Access

| Service | URL |
|---------|-----|
| Keycloak Admin Console | http://localhost:8080 |
| Keycloak via Nginx | http://auth.localhost |
| Health Check | http://localhost:8080/health |

**Default admin credentials:** `admin` / `admin` (change in `.env`)

### 4. First Steps

1. Open Keycloak Admin Console
2. Create a new Realm for your first business
3. Create a Client (app) inside the realm
4. Configure redirect URIs
5. Connect your application (see [Integration Guide](docs/integration.md))

---

## Project Structure

```
auth-service/
├── docker/
│   ├── docker-compose.yml          # Main compose file
│   ├── docker-compose.prod.yml     # Production overrides
│   ├── .env                        # Environment variables
│   ├── .env.example                # Example env file
│   ├── nginx/
│   │   └── conf.d/
│   │       ├── keycloak.conf            # Dev nginx config
│   │       └── keycloak.conf.production # Production nginx config (SSL)
│   └── ssl/                        # SSL certificates (production)
│
├── keycloak/
│   ├── realms/
│   │   └── example-realm.json      # Example realm template
│   ├── themes/                     # Custom login themes
│   └── providers/                  # Custom SPI plugins (e.g., SMS OTP)
│
├── docs/
│   ├── architecture.md             # System architecture & decisions
│   ├── api.md                      # Keycloak API reference
│   ├── flows.md                    # Authentication flow diagrams
│   └── integration.md             # How to connect apps
│
├── scripts/
│   ├── backup.sh                   # Database & realm backup
│   ├── export-realm.sh             # Export a specific realm
│   └── health-check.sh             # Service health check
│
└── README.md                       # This file
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System design, multi-tenant model, security |
| [API Reference](docs/api.md) | Keycloak REST API endpoints |
| [Auth Flows](docs/flows.md) | All authentication flow diagrams |
| [Integration Guide](docs/integration.md) | How to connect Laravel, Next.js, mobile apps |

---

## Services

| Service | Image | Port (Dev) | Purpose |
|---------|-------|------------|---------|
| Keycloak | `quay.io/keycloak/keycloak:26.0` | 8080 | Auth server |
| PostgreSQL | `postgres:16-alpine` | — (internal) | Database |
| Nginx | `nginx:1.25-alpine` | 80, 443 | Reverse proxy + SSL |

---

## Scripts

```bash
# Health check all services
./scripts/health-check.sh

# Backup database + realms
./scripts/backup.sh

# Export a specific realm
./scripts/export-realm.sh my-realm
```

---

## Production Deployment

### 1. Configure Environment

```bash
cd docker
cp .env.example .env
# Set strong passwords and production hostname
```

### 2. Add SSL Certificates

Place your certificates in `docker/ssl/`:
- `fullchain.pem`
- `privkey.pem`

### 3. Switch Nginx Config

```bash
cd docker/nginx/conf.d
cp keycloak.conf keycloak.conf.dev
cp keycloak.conf.production keycloak.conf
# Edit keycloak.conf — set your domain
```

### 4. Start with Production Overrides

```bash
cd docker
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 5. DNS

Point `auth.example.com` to your server IP.

---

## Frontend Options

Applications can authenticate in two ways:

| Option | Description | Best For |
|--------|-------------|----------|
| **Keycloak Login Pages** | Redirect to Keycloak, it handles the UI | Most apps, quick setup |
| **Custom Login UI** | App has its own login form, calls Keycloak API | Full UI control |

Admins always use the **Keycloak Admin Console** directly.

---

## Adding a New Customer

1. Create a new **Realm** in Keycloak Admin
2. Configure realm settings (branding, password policy, etc.)
3. Create **Clients** (one per app)
4. Create **Roles** as needed
5. Create an **Admin User** for the customer
6. Optionally customize the **Theme**
7. Export realm config as backup: `./scripts/export-realm.sh realm-name`

No code changes needed. Just config.

---

## Implementer Checklist

The developer implementing this must complete:

- [ ] Docker infrastructure setup & verify all services start
- [ ] Configure first realm (use `example-realm.json` as template)
- [ ] Create clients for target applications
- [ ] Configure SSO between apps (test cross-app login)
- [ ] Set up SSL and production Nginx config
- [ ] Enable brute force protection per realm
- [ ] Test token lifecycle (access, refresh, logout)
- [ ] Set up backup cron job (`scripts/backup.sh`)
- [ ] Test realm export/import flow
- [ ] Document any custom configuration decisions

### Future tasks (not day-1):

- [ ] Implement OTP/SMS flow (custom SPI)
- [ ] Custom themes per customer
- [ ] Social login integration (Google, Apple)
- [ ] Monitoring & alerting setup

---

## License

Private — Internal use only.
