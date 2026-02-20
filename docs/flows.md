# Auth Service — Authentication Flows

This document describes all authentication flows supported by the Auth Service.

---

## Table of Contents

1. [Authorization Code Flow + PKCE (Primary)](#1-authorization-code-flow--pkce)
2. [SSO Flow (Cross-App)](#2-sso-flow)
3. [Refresh Token Flow](#3-refresh-token-flow)
4. [Logout Flow](#4-logout-flow)
5. [Client Credentials Flow (Service-to-Service)](#5-client-credentials-flow)
6. [Direct Access Grant (Custom Login UI)](#6-direct-access-grant)
7. [User Registration Flow](#7-user-registration-flow)
8. [OTP / SMS Flow (Future)](#8-otp--sms-flow-future)

---

## 1. Authorization Code Flow + PKCE

**Primary flow** for all web and mobile applications.  
Use this when the app redirects users to Keycloak's login page.

```
┌──────────┐     ┌──────────────┐     ┌────────────┐
│  Browser │     │   App Server │     │  Keycloak  │
└────┬─────┘     └──────┬───────┘     └─────┬──────┘
     │                   │                    │
     │  1. Click Login   │                    │
     ├──────────────────►│                    │
     │                   │                    │
     │  2. Generate PKCE │                    │
     │     code_verifier │                    │
     │     code_challenge│                    │
     │                   │                    │
     │  3. Redirect to Keycloak               │
     │◄──────────────────┤                    │
     │   /auth?client_id=xxx                  │
     │        &redirect_uri=xxx               │
     │        &code_challenge=xxx             │
     │        &response_type=code             │
     │                   │                    │
     │  4. Show login page                    │
     ├───────────────────────────────────────►│
     │                   │                    │
     │  5. User enters credentials            │
     ├───────────────────────────────────────►│
     │                   │                    │
     │  6. Redirect back with code            │
     │◄──────────────────────────────────────┤
     │   /callback?code=AUTH_CODE             │
     │                   │                    │
     │  7. Send code to app                   │
     ├──────────────────►│                    │
     │                   │                    │
     │                   │  8. Exchange code   │
     │                   │     for tokens      │
     │                   │  POST /token        │
     │                   │  code + verifier    │
     │                   ├───────────────────►│
     │                   │                    │
     │                   │  9. Return tokens   │
     │                   │◄───────────────────┤
     │                   │  access_token       │
     │                   │  refresh_token      │
     │                   │  id_token           │
     │                   │                    │
     │ 10. Session created│                    │
     │◄──────────────────┤                    │
     │                   │                    │
```

### Key Points:
- PKCE is **mandatory** for public clients (SPAs, mobile apps)
- PKCE is **recommended** for confidential clients too
- `code_challenge_method` should always be `S256`

---

## 2. SSO Flow

When a user is already logged into one app and opens another app in the same realm.

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌────────────┐
│  Browser │     │ Store App│     │Clinic App│     │  Keycloak  │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └─────┬──────┘
     │                │                │                   │
     │  Already logged in to Store     │                   │
     │  (has Keycloak session cookie)  │                   │
     │                │                │                   │
     │  1. Open Clinic App             │                   │
     ├─────────────────────────────────►                   │
     │                │                │                   │
     │  2. Redirect to Keycloak        │                   │
     │◄────────────────────────────────┤                   │
     │                │                │                   │
     │  3. Keycloak detects existing session               │
     ├─────────────────────────────────────────────────────►
     │                │                │                   │
     │  4. NO login needed — redirect back with code       │
     │◄────────────────────────────────────────────────────┤
     │                │                │                   │
     │  5. Code → Tokens               │                   │
     ├─────────────────────────────────►                   │
     │                │                │                   │
     │  6. User is logged in (seamless)│                   │
     │◄────────────────────────────────┤                   │
     │                │                │                   │
```

### Key Points:
- SSO works via Keycloak's session cookie
- Both apps must be **clients in the same realm**
- User never sees a login page for the second app
- Session lifetime is configured per realm

---

## 3. Refresh Token Flow

When the access token expires, use the refresh token to get a new one.

```
┌──────────────┐                    ┌────────────┐
│   App Server │                    │  Keycloak  │
└──────┬───────┘                    └─────┬──────┘
       │                                   │
       │  1. Access token expired          │
       │     (401 from API)                │
       │                                   │
       │  2. POST /token                   │
       │     grant_type=refresh_token      │
       │     refresh_token=xxx             │
       ├──────────────────────────────────►│
       │                                   │
       │  3. New access_token              │
       │     New refresh_token             │
       │◄──────────────────────────────────┤
       │                                   │
       │  4. Retry original request        │
       │     with new access_token         │
       │                                   │
```

### Key Points:
- Refresh token rotation is enabled by default
- Old refresh token is invalidated after use
- If refresh token is expired → redirect to login

---

## 4. Logout Flow

### 4.1 Single App Logout (RP-Initiated)

```
┌──────────┐     ┌──────────────┐     ┌────────────┐
│  Browser │     │   App Server │     │  Keycloak  │
└────┬─────┘     └──────┬───────┘     └─────┬──────┘
     │                   │                    │
     │  1. Click Logout  │                    │
     ├──────────────────►│                    │
     │                   │                    │
     │  2. Clear app session                  │
     │                   │                    │
     │  3. Redirect to Keycloak logout        │
     │◄──────────────────┤                    │
     │   /logout?id_token_hint=xxx            │
     │          &redirect_uri=xxx             │
     │                   │                    │
     │  4. Keycloak destroys session          │
     ├───────────────────────────────────────►│
     │                   │                    │
     │  5. Redirect back │                    │
     │◄──────────────────────────────────────┤
     │                   │                    │
```

### 4.2 Global Logout (All Apps — SSO Logout)

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌────────────┐
│  Browser │     │ Store App│     │Clinic App│     │  Keycloak  │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └─────┬──────┘
     │                │                │                   │
     │  1. Logout from Store           │                   │
     ├───────────────►│                │                   │
     │                │                │                   │
     │  2. Send logout to Keycloak     │                   │
     │  ──────────────────────────────────────────────────►│
     │                │                │                   │
     │                │                │  3. Back-channel   │
     │                │                │     logout notify  │
     │                │                │◄──────────────────┤
     │                │                │                   │
     │                │  4. Session destroyed in Clinic too │
     │                │                │                   │
     │  5. Redirected to login page    │                   │
     │◄──────────────────────────────────────────────────┤
```

### Key Points:
- Back-channel logout must be configured for each client
- Apps need a back-channel logout endpoint to receive notifications
- Global logout destroys sessions across ALL apps in the realm

---

## 5. Client Credentials Flow

For **service-to-service** communication (no user involved).

```
┌──────────────┐                    ┌────────────┐
│  Service A   │                    │  Keycloak  │
└──────┬───────┘                    └─────┬──────┘
       │                                   │
       │  1. POST /token                   │
       │     grant_type=client_credentials │
       │     client_id=service-a           │
       │     client_secret=xxx             │
       ├──────────────────────────────────►│
       │                                   │
       │  2. access_token                  │
       │◄──────────────────────────────────┤
       │                                   │
       │  3. Call Service B API            │
       │     Authorization: Bearer xxx     │
       │──────────────────►                │
       │                                   │
```

### Key Points:
- No user context — token represents the service itself
- Client must have "Service Accounts Enabled"
- Use for background jobs, microservice communication

---

## 6. Direct Access Grant

For apps that have **their own login form** and don't redirect to Keycloak.

```
┌──────────┐     ┌──────────────┐     ┌────────────┐
│  Browser │     │   App Server │     │  Keycloak  │
└────┬─────┘     └──────┬───────┘     └─────┬──────┘
     │                   │                    │
     │  1. Enter username│                    │
     │     + password    │                    │
     ├──────────────────►│                    │
     │                   │                    │
     │                   │  2. POST /token    │
     │                   │  grant_type=password│
     │                   │  username + pass   │
     │                   ├───────────────────►│
     │                   │                    │
     │                   │  3. Tokens         │
     │                   │◄───────────────────┤
     │                   │                    │
     │  4. Logged in     │                    │
     │◄──────────────────┤                    │
```

### Key Points:
- ⚠️ **Not recommended** for most apps — SSO won't work with this flow
- User credentials pass through the app (less secure)
- Use only when you MUST have a custom login UI
- Must enable "Direct Access Grants" on the client

---

## 7. User Registration Flow

```
┌──────────┐     ┌──────────────┐     ┌────────────┐
│  Browser │     │   App Server │     │  Keycloak  │
└────┬─────┘     └──────┬───────┘     └─────┬──────┘
     │                   │                    │
     │  1. Click Register│                    │
     ├──────────────────►│                    │
     │                   │                    │
     │  2. Redirect to Keycloak registration  │
     │◄──────────────────┤                    │
     │                   │                    │
     │  3. Show registration form             │
     ├───────────────────────────────────────►│
     │                   │                    │
     │  4. User fills form                    │
     ├───────────────────────────────────────►│
     │                   │                    │
     │  5. User created, redirect with code   │
     │◄──────────────────────────────────────┤
     │                   │                    │
     │  6. Code → Tokens │                    │
     ├──────────────────►│                    │
     │                   ├───────────────────►│
     │                   │◄───────────────────┤
     │                   │                    │
     │  7. User logged in│                    │
     │◄──────────────────┤                    │
```

### Key Points:
- Self-registration must be enabled per realm
- Email verification can be enabled
- Custom registration form via themes

---

## 8. OTP / SMS Flow (Future)

> This requires a custom Keycloak SPI (Service Provider Interface)

```
┌──────────┐     ┌────────────┐     ┌─────────────┐
│  Browser │     │  Keycloak  │     │ SMS Provider │
└────┬─────┘     └─────┬──────┘     └──────┬───────┘
     │                  │                    │
     │  1. Enter phone  │                    │
     ├─────────────────►│                    │
     │                  │                    │
     │                  │  2. Generate OTP   │
     │                  │  3. Send SMS       │
     │                  ├───────────────────►│
     │                  │                    │
     │  4. Show OTP form│                    │
     │◄─────────────────┤                    │
     │                  │                    │
     │  5. Enter OTP    │                    │
     ├─────────────────►│                    │
     │                  │                    │
     │                  │  6. Verify OTP     │
     │                  │                    │
     │  7. Tokens       │                    │
     │◄─────────────────┤                    │
     │                  │                    │
```

### Implementation Steps (for developer):

1. Create custom **Authenticator SPI** in Java/Kotlin
2. Package as `.jar` → place in `keycloak/providers/`
3. Configure OTP authentication flow in realm
4. Integrate with SMS provider API (e.g., Kavenegar, Twilio)

### Custom SPI Structure:

```
keycloak/providers/
└── sms-otp-authenticator.jar
    ├── SmsOtpAuthenticator.java
    ├── SmsOtpAuthenticatorFactory.java
    └── META-INF/services/
        └── org.keycloak.authentication.AuthenticatorFactory
```

---

## Flow Decision Matrix

| Scenario | Recommended Flow |
|----------|-----------------|
| Web app with Keycloak login page | Authorization Code + PKCE |
| SPA (React, Vue, Angular) | Authorization Code + PKCE |
| Mobile app | Authorization Code + PKCE |
| Web app with custom login form | Direct Access Grant |
| Service-to-service (no user) | Client Credentials |
| User already logged in via another app | SSO (automatic) |
| Background job / cron | Client Credentials |
| SMS/OTP login | Custom SPI + Authentication Flow |
