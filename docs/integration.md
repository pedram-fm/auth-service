# Auth Service — Integration Guide

How to connect client applications to the Auth Service.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Create a Client in Keycloak](#2-create-a-client-in-keycloak)
3. [Laravel Integration](#3-laravel-integration)
4. [Next.js / React Integration](#4-nextjs--react-integration)
5. [Mobile App Integration](#5-mobile-app-integration)
6. [JWT Validation (Any Backend)](#6-jwt-validation-any-backend)
7. [Adding a New Tenant (Business)](#7-adding-a-new-tenant-business)

---

## 1. Prerequisites

- Auth Service is running (Keycloak is accessible)
- You know the realm name for your business
- You have admin access to create clients

**Keycloak URLs you'll need:**

| URL | Purpose |
|-----|---------|
| `https://auth.example.com` | Keycloak base URL |
| `https://auth.example.com/admin` | Admin console |
| `https://auth.example.com/realms/{realm}/.well-known/openid-configuration` | OIDC discovery |

---

## 2. Create a Client in Keycloak

### Step-by-step in Admin Console:

1. Login to Keycloak Admin: `https://auth.example.com/admin`
2. Select your realm
3. Go to **Clients** → **Create Client**
4. Fill in:

| Field | Value |
|-------|-------|
| Client ID | `my-app` (unique identifier) |
| Client Protocol | OpenID Connect |
| Root URL | `https://myapp.example.com` |

5. **Capability Config:**

| Setting | Value |
|---------|-------|
| Client Authentication | ON (for confidential) / OFF (for public) |
| Standard Flow | ON |
| Direct Access Grants | ON only if custom login UI |
| Service Accounts | ON only if service-to-service |

6. **Access Settings:**

| Setting | Value |
|---------|-------|
| Valid Redirect URIs | `https://myapp.example.com/auth/callback` |
| Valid Post Logout Redirect URIs | `https://myapp.example.com` |
| Web Origins | `https://myapp.example.com` |

7. Save → go to **Credentials** tab → copy `Client Secret`

---

## 3. Laravel Integration

### 3.1 Using Socialite (Recommended)

**Install:**

```bash
composer require laravel/socialite
composer require socialiteproviders/keycloak
```

**Config — `config/services.php`:**

```php
'keycloak' => [
    'client_id'     => env('KEYCLOAK_CLIENT_ID'),
    'client_secret' => env('KEYCLOAK_CLIENT_SECRET'),
    'redirect'      => env('KEYCLOAK_REDIRECT_URI'),
    'base_url'      => env('KEYCLOAK_BASE_URL'),
    'realms'        => env('KEYCLOAK_REALM'),
],
```

**`.env`:**

```env
KEYCLOAK_BASE_URL=https://auth.example.com
KEYCLOAK_REALM=my-realm
KEYCLOAK_CLIENT_ID=my-app
KEYCLOAK_CLIENT_SECRET=your-client-secret
KEYCLOAK_REDIRECT_URI=https://myapp.example.com/auth/callback
```

**Event Listener — `app/Providers/EventServiceProvider.php`:**

```php
protected $listen = [
    \SocialiteProviders\Manager\SocialiteWasCalled::class => [
        \SocialiteProviders\Keycloak\KeycloakExtendSocialite::class . '@handle',
    ],
];
```

**Routes — `routes/web.php`:**

```php
use Laravel\Socialite\Facades\Socialite;

// Redirect to Keycloak
Route::get('/auth/redirect', function () {
    return Socialite::driver('keycloak')->redirect();
});

// Callback from Keycloak
Route::get('/auth/callback', function () {
    $user = Socialite::driver('keycloak')->user();

    // $user->getId()       — Keycloak user UUID
    // $user->getName()     — Full name
    // $user->getEmail()    — Email
    // $user->token         — Access token
    // $user->refreshToken  — Refresh token

    // Find or create user in local DB
    $localUser = User::updateOrCreate(
        ['keycloak_id' => $user->getId()],
        [
            'name'  => $user->getName(),
            'email' => $user->getEmail(),
        ]
    );

    Auth::login($localUser);

    return redirect('/dashboard');
});

// Logout
Route::post('/auth/logout', function () {
    $realm = config('services.keycloak.realms');
    $baseUrl = config('services.keycloak.base_url');
    $redirectUri = url('/');

    Auth::logout();
    session()->invalidate();

    return redirect(
        "{$baseUrl}/realms/{$realm}/protocol/openid-connect/logout"
        . "?client_id=" . config('services.keycloak.client_id')
        . "&post_logout_redirect_uri=" . urlencode($redirectUri)
    );
});
```

### 3.2 JWT Validation Middleware (For APIs)

**Install:**

```bash
composer require firebase/php-jwt
```

**Middleware — `app/Http/Middleware/KeycloakAuth.php`:**

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Firebase\JWT\JWT;
use Firebase\JWT\JWK;
use Firebase\JWT\Key;
use Illuminate\Http\Request;

class KeycloakAuth
{
    private static ?array $jwks = null;

    public function handle(Request $request, Closure $next)
    {
        $token = $request->bearerToken();

        if (!$token) {
            return response()->json(['error' => 'Token required'], 401);
        }

        try {
            $decoded = JWT::decode($token, $this->getKeys());

            // Verify issuer
            $expectedIssuer = config('services.keycloak.base_url')
                . '/realms/' . config('services.keycloak.realms');

            if ($decoded->iss !== $expectedIssuer) {
                return response()->json(['error' => 'Invalid issuer'], 401);
            }

            // Attach user info to request
            $request->merge([
                'keycloak_user_id' => $decoded->sub,
                'keycloak_email'   => $decoded->email ?? null,
                'keycloak_roles'   => $decoded->realm_access->roles ?? [],
                'keycloak_client_roles' => $decoded->resource_access ?? [],
            ]);

            return $next($request);

        } catch (\Exception $e) {
            return response()->json(['error' => 'Invalid token: ' . $e->getMessage()], 401);
        }
    }

    private function getKeys(): array
    {
        if (self::$jwks === null) {
            $jwksUrl = config('services.keycloak.base_url')
                . '/realms/' . config('services.keycloak.realms')
                . '/protocol/openid-connect/certs';

            $jwksJson = file_get_contents($jwksUrl);
            $jwksData = json_decode($jwksJson, true);
            self::$jwks = JWK::parseKeySet($jwksData);
        }

        return self::$jwks;
    }
}
```

**Register in `bootstrap/app.php`:**

```php
->withMiddleware(function (Middleware $middleware) {
    $middleware->alias([
        'keycloak' => \App\Http\Middleware\KeycloakAuth::class,
    ]);
})
```

**Use on routes:**

```php
Route::middleware('keycloak')->group(function () {
    Route::get('/api/profile', function (Request $request) {
        return response()->json([
            'user_id' => $request->keycloak_user_id,
            'email'   => $request->keycloak_email,
            'roles'   => $request->keycloak_roles,
        ]);
    });
});
```

---

## 4. Next.js / React Integration

### 4.1 Using NextAuth.js (Recommended for Next.js)

**Install:**

```bash
npm install next-auth
```

**`app/api/auth/[...nextauth]/route.ts`:**

```typescript
import NextAuth from "next-auth";
import KeycloakProvider from "next-auth/providers/keycloak";

const handler = NextAuth({
  providers: [
    KeycloakProvider({
      clientId: process.env.KEYCLOAK_CLIENT_ID!,
      clientSecret: process.env.KEYCLOAK_CLIENT_SECRET!,
      issuer: `${process.env.KEYCLOAK_BASE_URL}/realms/${process.env.KEYCLOAK_REALM}`,
    }),
  ],
  callbacks: {
    async jwt({ token, account }) {
      if (account) {
        token.accessToken = account.access_token;
        token.refreshToken = account.refresh_token;
        token.idToken = account.id_token;
        token.expiresAt = account.expires_at;
      }
      return token;
    },
    async session({ session, token }) {
      session.accessToken = token.accessToken as string;
      return session;
    },
  },
});

export { handler as GET, handler as POST };
```

**`.env.local`:**

```env
KEYCLOAK_BASE_URL=https://auth.example.com
KEYCLOAK_REALM=my-realm
KEYCLOAK_CLIENT_ID=my-nextjs-app
KEYCLOAK_CLIENT_SECRET=your-client-secret
NEXTAUTH_URL=https://myapp.example.com
NEXTAUTH_SECRET=random-secret-here
```

### 4.2 Using keycloak-js (For SPAs / React)

**Install:**

```bash
npm install keycloak-js
```

**`lib/keycloak.ts`:**

```typescript
import Keycloak from "keycloak-js";

const keycloak = new Keycloak({
  url: process.env.NEXT_PUBLIC_KEYCLOAK_URL!,
  realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM!,
  clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID!,
});

export default keycloak;
```

**`providers/AuthProvider.tsx`:**

```tsx
"use client";

import { createContext, useContext, useEffect, useState, ReactNode } from "react";
import keycloak from "@/lib/keycloak";

interface AuthContextType {
  isAuthenticated: boolean;
  token: string | null;
  user: any;
  login: () => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [token, setToken] = useState<string | null>(null);

  useEffect(() => {
    keycloak
      .init({ onLoad: "check-sso", silentCheckSsoRedirectUri: window.location.origin + "/silent-check-sso.html" })
      .then((authenticated) => {
        setIsAuthenticated(authenticated);
        setToken(keycloak.token || null);
      });

    // Auto-refresh token
    setInterval(() => {
      keycloak.updateToken(60).then((refreshed) => {
        if (refreshed) {
          setToken(keycloak.token || null);
        }
      });
    }, 30000);
  }, []);

  const login = () => keycloak.login();
  const logout = () => keycloak.logout({ redirectUri: window.location.origin });

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated,
        token,
        user: keycloak.tokenParsed,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
};
```

---

## 5. Mobile App Integration

### React Native / Flutter / Swift / Kotlin

Use **AppAuth** library (platform-specific):

| Platform | Library |
|----------|---------|
| React Native | `react-native-app-auth` |
| Flutter | `flutter_appauth` |
| iOS (Swift) | `AppAuth-iOS` |
| Android (Kotlin) | `AppAuth-Android` |

**Configuration (common across platforms):**

```json
{
  "issuer": "https://auth.example.com/realms/{realm}",
  "clientId": "my-mobile-app",
  "redirectUrl": "com.myapp://auth/callback",
  "scopes": ["openid", "profile", "email"]
}
```

> For mobile apps, use **public client** (no client_secret) with **PKCE**.

---

## 6. JWT Validation (Any Backend)

### Steps for any language/framework:

1. **Fetch JWKS** from:
   ```
   GET https://auth.example.com/realms/{realm}/protocol/openid-connect/certs
   ```

2. **Decode JWT** header to get `kid` (Key ID)

3. **Find matching key** in JWKS response

4. **Verify signature** using RSA256

5. **Validate claims:**
   - `iss` = `https://auth.example.com/realms/{realm}`
   - `exp` > current time
   - `aud` or `azp` = your client ID

6. **Extract user info:**
   - `sub` = user ID
   - `email` = email
   - `realm_access.roles` = realm roles
   - `resource_access.{client_id}.roles` = client roles

### Validation Libraries

| Language | Library |
|----------|---------|
| PHP | `firebase/php-jwt` |
| Node.js | `jsonwebtoken` + `jwks-rsa` |
| Python | `PyJWT` + `cryptography` |
| Go | `github.com/golang-jwt/jwt` |
| Java | `nimbus-jose-jwt` |

---

## 7. Adding a New Tenant (Business)

When selling to a new customer:

### Step 1: Create Realm

```
Admin Console → Create Realm → Enter name (e.g., "acme-store")
```

### Step 2: Configure Realm Settings

| Setting | Recommended Value |
|---------|------------------|
| Login Theme | custom (per business) |
| User Registration | depends on business |
| Email Verification | ON |
| Forgot Password | ON |
| Remember Me | ON |
| Login with Email | ON |
| Brute Force Protection | ON |

### Step 3: Create Clients

Create one client per app the business uses.

### Step 4: Create Realm Roles

Based on business needs (e.g., `admin`, `manager`, `user`).

### Step 5: Create Admin User

Create a user for the business admin with `realm-admin` role.

### Step 6: Customize Theme (Optional)

Place theme files in `keycloak/themes/{theme-name}/` and restart Keycloak.

### Step 7: Export Realm Config

```bash
./scripts/export-realm.sh acme-store
```

> Keep realm exports as backups. They contain all config but NOT user passwords.
