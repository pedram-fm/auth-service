# Auth Service — Architecture

## 1. Overview

Auth Service is a **centralized SSO (Single Sign-On) server** based on [Keycloak](https://www.keycloak.org/).  
It acts as an identity provider for multiple independent applications (store, clinic, reservation system, etc.).

This is a **multi-tenant** solution — each customer (business) gets its own isolated realm with separate users, roles, themes, and clients.

---

## 2. Goals

| Goal | Description |
|------|-------------|
| **Centralized Auth** | One service handles authentication for all apps |
| **SSO** | Users log in once, access multiple apps seamlessly |
| **Multi-Tenant** | Each business (customer) gets its own isolated realm |
| **Token-Based** | JWT tokens via OpenID Connect / OAuth 2.0 |
| **Scalable** | Add new apps and tenants without core changes |
| **Sellable** | Package user-management as a product for businesses |

---

## 3. High-Level Architecture

```
                    ┌─────────────────────────┐
                    │     Nginx (Reverse       │
                    │       Proxy + SSL)       │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │    Keycloak Auth Server  │
                    │    (SSO / OIDC / OAuth2) │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │     PostgreSQL Database  │
                    └─────────────────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            │                    │                     │
   ┌────────▼────────┐ ┌────────▼────────┐  ┌────────▼────────┐
   │  Realm: Store   │ │ Realm: Clinic   │  │ Realm: Future   │
   │  ┌────────────┐ │ │ ┌────────────┐  │  │ ┌────────────┐  │
   │  │ Store App  │ │ │ │ Clinic App │  │  │ │  Any App   │  │
   │  │ (Client)   │ │ │ │ (Client)   │  │  │ │  (Client)  │  │
   │  └────────────┘ │ │ └────────────┘  │  │ └────────────┘  │
   │  ┌────────────┐ │ │ ┌────────────┐  │  │                 │
   │  │ Admin App  │ │ │ │ Booking    │  │  │                 │
   │  │ (Client)   │ │ │ │ (Client)   │  │  │                 │
   │  └────────────┘ │ │ └────────────┘  │  │                 │
   └─────────────────┘ └────────────────┘   └─────────────────┘
```

---

## 4. Multi-Tenant Model

Each **customer/business** = one **Keycloak Realm**.

| Concept | Keycloak Equivalent |
|---------|-------------------|
| Customer / Business | Realm |
| Application | Client |
| End User | User (inside realm) |
| Permission | Role (realm or client level) |
| Business Admin | Realm Admin user |

### Why per-realm?

- **Data isolation**: Users of one business never see another business's data.
- **Independent config**: Each realm has its own login theme, password policy, roles.
- **Self-service admin**: Each business admin manages their own realm (users, roles).
- **Easy onboarding**: Create a new realm = onboard a new customer.

---

## 5. Component Breakdown

### 5.1 Keycloak Server

- **Version**: 26.x (latest stable)
- **Mode**: `start-dev` for development, `start --optimized` for production
- **Features enabled**: health, metrics
- **Realm import**: Auto-import from `/opt/keycloak/data/import/`

### 5.2 PostgreSQL

- **Version**: 16 Alpine
- **Purpose**: Persistent storage for Keycloak (users, sessions, realms)
- **Health check**: `pg_isready`

### 5.3 Nginx

- **Purpose**: Reverse proxy, SSL termination, rate limiting
- **Development**: HTTP on port 80, proxies to Keycloak
- **Production**: HTTPS with SSL, HTTP→HTTPS redirect, rate limiting on token endpoint

---

## 6. Authentication Protocols

| Protocol | Usage |
|----------|-------|
| **OpenID Connect (OIDC)** | Primary — all app authentication |
| **OAuth 2.0** | Token issuance, authorization |
| **SAML 2.0** | Optional — for enterprise integrations |

### Token Types

| Token | Lifetime | Purpose |
|-------|----------|---------|
| Access Token (JWT) | 15 minutes | API authorization |
| Refresh Token | 30 days | Renew access token |
| ID Token | 15 minutes | User identity claims |

---

## 7. Client Types

Applications can connect in two ways:

### Option A: Use Keycloak Login Pages (Recommended for most apps)

- App redirects to Keycloak for login
- Keycloak handles login UI (customizable per realm/theme)
- Token returned to app via redirect
- **Best for**: Simple setup, consistent UX, less code

### Option B: Custom Frontend + Keycloak API

- App has its own login form
- App calls Keycloak REST API (`/token` endpoint)
- App handles all UI
- **Best for**: Apps that need complete UI control

### Admin Access

- All admins use the **Keycloak Admin Console** directly
- URL: `https://auth.example.com/admin/{realm}/console`
- No need for custom admin panel

---

## 8. Roles Architecture

### Global Realm Roles

| Role | Description |
|------|-------------|
| `user` | Default authenticated user |
| `admin` | Business admin — manages realm |
| `super_admin` | System-wide admin (master realm only) |

### Client-Specific Roles (per app)

| Role | Description |
|------|-------------|
| `manager` | App-level manager |
| `operator` | App-level operator |
| `viewer` | Read-only access |

> Each client (app) can define its own roles. These are scoped to that client only.

---

## 9. Security

### Required (Day 1)

- [x] HTTPS only (via Nginx SSL)
- [x] Secure cookies
- [x] CORS configured per client
- [x] PKCE enabled for public clients
- [x] Brute force protection (Keycloak built-in)
- [x] Rate limiting on token endpoint (Nginx)
- [x] X-Frame-Options, CSP headers

### Recommended (Phase 2)

- [ ] 2FA / OTP optional for users
- [ ] IP whitelisting for admin access
- [ ] Audit logging enabled
- [ ] Intrusion detection alerts

---

## 10. Infrastructure Requirements

### Development

| Resource | Minimum |
|----------|---------|
| CPU | 1 core |
| RAM | 2 GB |
| Disk | 5 GB |
| Docker | 24.x+ |
| Docker Compose | 2.x+ |

### Production

| Resource | Minimum |
|----------|---------|
| CPU | 2 cores |
| RAM | 4 GB |
| Disk | 20 GB |
| Docker | 24.x+ |
| PostgreSQL | 16.x |
| Reverse Proxy | Nginx |
| SSL | Yes (Let's Encrypt or commercial) |
| Domain | `auth.example.com` |

---

## 11. Backup Strategy

| Target | Method | Schedule |
|--------|--------|----------|
| PostgreSQL | `pg_dump` | Daily |
| Realm Config | `realm-export.json` | After changes |
| Keycloak Themes | Git (in this repo) | With code changes |

Backup script: `scripts/backup.sh`

---

## 12. Deployment Topology

```
                Internet
                    │
              ┌─────▼─────┐
              │  DNS / CDN │
              └─────┬─────┘
                    │
        ┌───────────▼───────────┐
        │  auth.example.com     │
        │  (Nginx + SSL)        │
        └───────────┬───────────┘
                    │
        ┌───────────▼───────────┐
        │  Keycloak Container   │
        │  Port 8080 (internal) │
        └───────────┬───────────┘
                    │
        ┌───────────▼───────────┐
        │  PostgreSQL Container │
        │  Port 5432 (internal) │
        └───────────────────────┘
```

> All internal communication is on Docker bridge network. Only Nginx is exposed to the internet.

---

## 13. Future Extensions

| Feature | Priority | Notes |
|---------|----------|-------|
| Google/Apple Login | Medium | Social identity providers |
| SMS/OTP Login | High | Custom authentication flow + SMS provider |
| Magic Link | Low | Email-based passwordless login |
| Multi-language | Medium | Per-realm theme translations |
| Custom Themes | High | Brand per customer |
| Webhooks | Medium | Notify apps on user events |
| User Federation | Low | LDAP/AD integration |
