# Auth Service — Keycloak API Reference

All endpoints are relative to the Keycloak base URL:  
`https://auth.example.com`

> **Note**: Keycloak provides a full REST API. This document covers the most commonly used endpoints by client applications. For the full API, see:  
> https://www.keycloak.org/docs-api/26.0.0/rest-api/index.html

---

## Table of Contents

1. [OpenID Connect Endpoints (Per Realm)](#1-openid-connect-endpoints-per-realm)
2. [Token Operations](#2-token-operations)
3. [User Info](#3-user-info)
4. [Logout](#4-logout)
5. [User Registration](#5-user-registration)
6. [Admin API](#6-admin-api)
7. [Well-Known Configuration](#7-well-known-configuration)

---

## 1. OpenID Connect Endpoints (Per Realm)

All OIDC endpoints are scoped to a realm:

```
Base: /realms/{realm-name}/protocol/openid-connect
```

| Endpoint | Path |
|----------|------|
| Authorization | `/realms/{realm}/protocol/openid-connect/auth` |
| Token | `/realms/{realm}/protocol/openid-connect/token` |
| UserInfo | `/realms/{realm}/protocol/openid-connect/userinfo` |
| Logout | `/realms/{realm}/protocol/openid-connect/logout` |
| Certs (JWKS) | `/realms/{realm}/protocol/openid-connect/certs` |
| Introspect | `/realms/{realm}/protocol/openid-connect/token/introspect` |
| Revoke | `/realms/{realm}/protocol/openid-connect/revoke` |

---

## 2. Token Operations

### 2.1 Authorization Code Flow (Recommended)

**Step 1 — Redirect user to login:**

```
GET /realms/{realm}/protocol/openid-connect/auth
    ?client_id={client_id}
    &redirect_uri={redirect_uri}
    &response_type=code
    &scope=openid profile email
    &state={random_state}
    &code_challenge={code_challenge}        # PKCE
    &code_challenge_method=S256             # PKCE
```

**Step 2 — Exchange code for tokens:**

```http
POST /realms/{realm}/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code={authorization_code}
&client_id={client_id}
&client_secret={client_secret}          # For confidential clients
&redirect_uri={redirect_uri}
&code_verifier={code_verifier}          # PKCE
```

**Response:**

```json
{
    "access_token": "eyJhbGciOiJSUzI1NiIs...",
    "expires_in": 900,
    "refresh_expires_in": 2592000,
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "token_type": "Bearer",
    "id_token": "eyJhbGciOiJSUzI1NiIs...",
    "not-before-policy": 0,
    "session_state": "abc-123-def",
    "scope": "openid profile email"
}
```

### 2.2 Refresh Token

```http
POST /realms/{realm}/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&refresh_token={refresh_token}
&client_id={client_id}
&client_secret={client_secret}
```

### 2.3 Client Credentials (Service-to-Service)

```http
POST /realms/{realm}/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id={client_id}
&client_secret={client_secret}
&scope=openid
```

### 2.4 Direct Access Grant (Resource Owner Password — NOT recommended)

> Only for trusted apps that handle their own login form.

```http
POST /realms/{realm}/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=password
&client_id={client_id}
&client_secret={client_secret}
&username={username}
&password={password}
&scope=openid
```

---

## 3. User Info

Get current user's profile from their access token.

```http
GET /realms/{realm}/protocol/openid-connect/userinfo
Authorization: Bearer {access_token}
```

**Response:**

```json
{
    "sub": "user-uuid-here",
    "email": "user@example.com",
    "email_verified": true,
    "name": "John Doe",
    "preferred_username": "johndoe",
    "given_name": "John",
    "family_name": "Doe"
}
```

---

## 4. Logout

### 4.1 RP-Initiated Logout (Redirect)

```
GET /realms/{realm}/protocol/openid-connect/logout
    ?id_token_hint={id_token}
    &post_logout_redirect_uri={url}
    &client_id={client_id}
```

### 4.2 Back-Channel Logout (Server-Side)

```http
POST /realms/{realm}/protocol/openid-connect/logout
Content-Type: application/x-www-form-urlencoded

client_id={client_id}
&client_secret={client_secret}
&refresh_token={refresh_token}
```

---

## 5. User Registration

If self-registration is enabled for the realm:

```
GET /realms/{realm}/protocol/openid-connect/registrations
    ?client_id={client_id}
    &redirect_uri={redirect_uri}
    &response_type=code
    &scope=openid
```

This redirects to Keycloak's registration form.

---

## 6. Admin API

> Admin API requires an admin access token. Obtain via master realm or realm admin user.

**Base URL:**

```
/admin/realms/{realm}
```

### 6.1 Get Admin Token

```http
POST /realms/master/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=password
&client_id=admin-cli
&username=admin
&password={admin_password}
```

### 6.2 Users

| Action | Method | Endpoint |
|--------|--------|----------|
| List users | `GET` | `/admin/realms/{realm}/users` |
| Get user | `GET` | `/admin/realms/{realm}/users/{id}` |
| Create user | `POST` | `/admin/realms/{realm}/users` |
| Update user | `PUT` | `/admin/realms/{realm}/users/{id}` |
| Delete user | `DELETE` | `/admin/realms/{realm}/users/{id}` |
| Reset password | `PUT` | `/admin/realms/{realm}/users/{id}/reset-password` |

**Create User Example:**

```http
POST /admin/realms/{realm}/users
Authorization: Bearer {admin_token}
Content-Type: application/json

{
    "username": "newuser",
    "email": "newuser@example.com",
    "firstName": "New",
    "lastName": "User",
    "enabled": true,
    "emailVerified": true,
    "credentials": [
        {
            "type": "password",
            "value": "temporary123",
            "temporary": true
        }
    ]
}
```

### 6.3 Roles

| Action | Method | Endpoint |
|--------|--------|----------|
| List realm roles | `GET` | `/admin/realms/{realm}/roles` |
| Create role | `POST` | `/admin/realms/{realm}/roles` |
| Assign role to user | `POST` | `/admin/realms/{realm}/users/{id}/role-mappings/realm` |
| List client roles | `GET` | `/admin/realms/{realm}/clients/{clientId}/roles` |

### 6.4 Clients

| Action | Method | Endpoint |
|--------|--------|----------|
| List clients | `GET` | `/admin/realms/{realm}/clients` |
| Create client | `POST` | `/admin/realms/{realm}/clients` |
| Get client | `GET` | `/admin/realms/{realm}/clients/{id}` |
| Get client secret | `GET` | `/admin/realms/{realm}/clients/{id}/client-secret` |

### 6.5 Groups

| Action | Method | Endpoint |
|--------|--------|----------|
| List groups | `GET` | `/admin/realms/{realm}/groups` |
| Create group | `POST` | `/admin/realms/{realm}/groups` |
| Add user to group | `PUT` | `/admin/realms/{realm}/users/{userId}/groups/{groupId}` |

### 6.6 Sessions

| Action | Method | Endpoint |
|--------|--------|----------|
| Get user sessions | `GET` | `/admin/realms/{realm}/users/{id}/sessions` |
| Logout user | `POST` | `/admin/realms/{realm}/users/{id}/logout` |
| Get active sessions | `GET` | `/admin/realms/{realm}/client-session-stats` |

---

## 7. Well-Known Configuration

Auto-discovery endpoint for OIDC configuration:

```
GET /realms/{realm}/.well-known/openid-configuration
```

**Response (key fields):**

```json
{
    "issuer": "https://auth.example.com/realms/{realm}",
    "authorization_endpoint": "https://auth.example.com/realms/{realm}/protocol/openid-connect/auth",
    "token_endpoint": "https://auth.example.com/realms/{realm}/protocol/openid-connect/token",
    "userinfo_endpoint": "https://auth.example.com/realms/{realm}/protocol/openid-connect/userinfo",
    "end_session_endpoint": "https://auth.example.com/realms/{realm}/protocol/openid-connect/logout",
    "jwks_uri": "https://auth.example.com/realms/{realm}/protocol/openid-connect/certs",
    "grant_types_supported": [
        "authorization_code",
        "implicit",
        "refresh_token",
        "password",
        "client_credentials"
    ],
    "response_types_supported": [
        "code",
        "code id_token",
        "id_token",
        "token id_token"
    ],
    "scopes_supported": [
        "openid",
        "profile",
        "email",
        "roles",
        "web-origins"
    ]
}
```

---

## 8. JWT Token Structure

### Access Token Payload (Decoded)

```json
{
    "exp": 1700000000,
    "iat": 1699999100,
    "jti": "token-uuid",
    "iss": "https://auth.example.com/realms/{realm}",
    "aud": "account",
    "sub": "user-uuid",
    "typ": "Bearer",
    "azp": "store-app",
    "session_state": "session-uuid",
    "scope": "openid profile email",
    "realm_access": {
        "roles": ["user", "admin"]
    },
    "resource_access": {
        "store-app": {
            "roles": ["manager"]
        }
    },
    "email": "user@example.com",
    "name": "John Doe",
    "preferred_username": "johndoe"
}
```

### Validating JWT on Client Side

1. Fetch JWKS from `/realms/{realm}/protocol/openid-connect/certs`
2. Verify signature using RSA256 public key
3. Check `iss` matches your Keycloak URL
4. Check `exp` is not expired
5. Check `aud` or `azp` matches your client ID
6. Extract roles from `realm_access` and `resource_access`

---

## 9. Error Responses

Standard Keycloak error format:

```json
{
    "error": "invalid_grant",
    "error_description": "Invalid user credentials"
}
```

Common errors:

| Error | HTTP Code | Description |
|-------|-----------|-------------|
| `invalid_grant` | 400 | Bad credentials or expired code |
| `invalid_client` | 401 | Wrong client_id or client_secret |
| `unauthorized_client` | 400 | Client not allowed for this grant type |
| `invalid_token` | 401 | Token expired or invalid |
| `access_denied` | 403 | User doesn't have required role |

---

## 10. Health & Metrics

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Overall health status |
| `GET /health/ready` | Readiness check |
| `GET /health/live` | Liveness check |
| `GET /metrics` | Prometheus metrics |
