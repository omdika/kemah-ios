# API Contract: Kemah

> **Version:** 1.3.1 — see [`CHANGELOG.md`](./CHANGELOG.md). Older snapshots under [`versions/`](./versions/).

Defines the backend contract needed to make the prototype's mocked actions real. Written as REST for portability; if using Firestore/Supabase realtime instead, treat each resource below as a collection/table with the same shape and add realtime listeners on `trips/{id}` and its subcollections instead of polling.

Auth: all endpoints below require `Authorization: Bearer <idToken>` (Google/Apple ID token exchanged via Firebase Auth / Supabase Auth on login). No custom auth server needed — use the BaaS's built-in Google/Apple sign-in and pass its session token through. **[v1.3.1]** iOS implements the Google leg natively: `GoogleSignIn-iOS` obtains a Google ID token, which the client exchanges directly via Supabase's REST token endpoint (`POST /auth/v1/token?grant_type=id_token`, no Supabase SDK) for a Supabase session — that session's `access_token` is the bearer token sent to every endpoint below.

> **[v1.1.0] Per-user privacy.** Personal checklist items and personal expenses are private to the user who created them. The server sets their `owner` from the authenticated token and MUST only return a personal entry to its owner. All list/detail responses below are already filtered to the caller: another participant never sees your personal `items`/`budgetItems`, and they are excluded from split-bill and group budget totals.

## Users

### `GET /me`
Returns the signed-in user's profile.
```json
{ "id": "u_123", "name": "Dinda", "email": "dinda@example.com", "avatarUrl": null }
```

## Trips

### `GET /trips`
List trips the signed-in user participates in. `checklistProgress` counts only items visible to the caller (group items + the caller's own personal items).
```json
{ "trips": [ { "id": "t1", "name": "Camping Gunung Papandayan", "location": "Garut, Jawa Barat",
    "date": "2026-08-01", "coverUrl": "https://.../cover.jpg", "mapLink": "https://maps.google.com/...",
    "phone": "081234567890", "status": "upcoming", "budgetTarget": 1200000, "budgetMode": "manual",
    "participantCount": 5, "checklistProgress": { "checked": 8, "total": 15 } } ] }
```

### `POST /trips`
Create a trip. Creator is auto-added as first participant (`picForLabel: "Koordinator"`, `headcount: 1`).
```json
// request
{ "name": "Camping Kawah Putih", "location": "Bandung", "date": "2026-09-12",
  "mapLink": "", "phone": "", "coverUrl": "" }
// response: 201, full Trip object (see GET /trips/:id)
```

### `GET /trips/:id`
Full trip detail including nested lists. **`items` and `budgetItems` are filtered to the caller** — personal entries (`isPersonal: true`) belonging to other users are omitted.
```json
{
  "id": "t1", "name": "...", "location": "...", "date": "2026-08-01", "coverUrl": "...",
  "mapLink": "...", "phone": "...", "status": "upcoming",
  "budgetTarget": 1200000, "budgetMode": "manual",
  "participants": [ { "id": "p1", "name": "Dinda", "picForLabel": "Koordinator", "headcount": 1 } ],
  "items": [ { "id": "i1", "name": "Tenda dome 4 orang", "qty": 1, "pic": "Rangga",
      "note": "cek patok & pasak lengkap", "checked": true, "isPersonal": false, "owner": null } ],
  "budgetItems": [ { "id": "b1", "name": "Sewa mobil", "price": 100000,
      "paidBy": "Dinda", "pic": null, "splitMode": "pic", "isPersonal": false, "owner": null } ]
}
```

### `PATCH /trips/:id`
Partial update — any subset of `name, location, date, mapLink, phone, coverUrl, budgetTarget, budgetMode, status`.

### `DELETE /trips/:id`

## Participants (`/trips/:tripId/participants`)

### `POST /`
```json
// request: { "name": "Ani" }
// response: { "id": "p5", "name": "Ani", "picForLabel": "Peserta", "headcount": 1 }
```

### `PATCH /:participantId`
```json
{ "picForLabel": "PIC Tiket & Logistik", "headcount": 1 }
```

### `DELETE /:participantId`

## Checklist Items (`/trips/:tripId/items`)

### `POST /`
```json
{ "name": "Kompor portable + gas", "qty": 1, "pic": "Budi", "note": "", "isPersonal": false }
```
- **[v1.1.0]** When `isPersonal: true`, the server sets `owner` to the caller and the item becomes private (returned only to the owner). `pic` is ignored/omitted for personal items. Do **not** accept `owner` from the client.

### `PATCH /:itemId`
Any subset of `name, qty, pic, note, checked, isPersonal`. Toggling done state is `PATCH { "checked": true }`. **[v1.1.0]** Setting `isPersonal: true` assigns `owner` to the caller; setting it back to `false` clears `owner`.

### `DELETE /:itemId`

## Budget Items (`/trips/:tripId/budget-items`)

### `POST /`
```json
{ "name": "Bensin & tol", "price": 100000, "paidBy": "Dinda", "pic": null, "splitMode": "orang", "isPersonal": false }
```
- `splitMode`: `"orang"` or `"pic"`.
- `pic`: null/omitted unless this is a `"pic"`-mode expense that belongs to someone other than `paidBy`.
- **[v1.1.0] `isPersonal`** (bool, default `false`): when `true`, this is a **private personal expense**. The server sets `owner` to the caller; it is returned only to the owner, excluded from the group budget total, and **never enters the split-bill calculation**. For personal expenses, `splitMode`/`pic` are irrelevant (`paidBy` is implicitly the owner). Do **not** accept `owner` from the client.

### `PATCH /:budgetItemId`
Any subset of `name, price, paidBy, pic, splitMode, isPersonal`. Toggling `isPersonal` (re)assigns/clears `owner` as with checklist items.

### `DELETE /:budgetItemId`

## Split Bill (`GET /trips/:tripId/split-bill`)

**[v1.3.0] Server-side computation is now required.** The iOS client calls this endpoint and decodes the response directly — it no longer computes settlement locally (except as an offline fallback). Implement the exact algorithm from the README's "Split Bill Logic" section server-side.

**Exclusion rules (compute in this order):**
1. Drop items with `isPersonal: true` — personal expenses are never split. **[v1.1.0]**
2. Drop Per-PIC items where `pic == paidBy` (non-empty) — self-paid; the person already covered their own cost. **[v1.3.0]**
3. Remaining Per-PIC items with `pic` blank/nil → pooled (flat per participant). Per-PIC with `pic != paidBy` → direct 1:1 debt.

**Thresholds:** balances within ±1000 are "Lunas"; the greedy matcher ignores amounts ≤ 500.

**Response** — field names match the iOS `SettlementResult` / `PerPersonRow` / `TransferRow` structs exactly for zero-adapter JSON decoding:

```json
{
  "equalShareLabel": "Rp40.000",
  "participantCount": 4,
  "perPerson": [
    {
      "name": "Dinda",
      "contribution": 200000,
      "share": 40000,
      "balance": 160000,
      "headcount": 1,
      "poolDetails": [
        { "name": "Sewa mobil", "share": 50000, "paid": 200000 },
        { "name": "Kompor + gas", "share": 25000, "paid": 0 }
      ]
    },
    {
      "name": "Rangga",
      "contribution": 0,
      "share": 40000,
      "balance": -40000,
      "headcount": 1,
      "poolDetails": [
        { "name": "Sewa mobil", "share": 50000, "paid": 0 },
        { "name": "Kompor + gas", "share": 25000, "paid": 0 }
      ]
    }
  ],
  "transfers": [
    {
      "from": "Rangga",
      "to": "Dinda",
      "total": 40000,
      "parts": [
        { "label": "Bagi rata", "amount": 20000 },
        { "label": "Sewa mobil", "amount": 20000 }
      ]
    }
  ]
}
```

**Field notes:**
- `perPerson[].contribution` — total amount this person actually fronted (their pool payments only; direct debts excluded). Renamed from `paid` in v1.2.0 and earlier.
- `perPerson[].poolDetails` — per-item breakdown for the "Bagi rata" pool. Each entry: `name` = expense name, `share` = this person's fair portion of that item, `paid` = full item price if this person was the payer, else 0. Powers the Level B transparency expansion in the transfer list. Include only pool items (Per-Orang and Pooled Per-PIC); exclude self-paid and direct-debt items.
- `transfers[].total` — merged transfer total. Renamed from `amount` in v1.2.0 and earlier.
- `transfers[].parts[].amount` — individual part amount (unchanged field name).
- Pool-derived parts use `label: "Bagi rata"`; direct-debt parts use the expense `name` as the label.

## Invite (`/trips/:tripId/invite`)

### `POST /invite-link`
Generates (or returns existing) a shareable join link.
```json
{ "url": "https://kemah.app/join/t1?token=abc123" }
```

### `POST /join` (unauthenticated route, then requires login to complete)
```json
// request: { "token": "abc123" }
// response: { "tripId": "t1" }  → client then calls GET /trips/t1
```

## Photo Upload

### `POST /uploads` (multipart/form-data, field `file`)
Used for both trip cover photos and (future) checklist/receipt photos. Upload to BaaS storage (Firebase Storage / Supabase Storage bucket), return the public/CDN URL.
```json
{ "url": "https://.../cover-t1.jpg" }
```

## Realtime (recommended over polling)
If using Firestore/Supabase: subscribe to `trips/{id}` and its `items`, `budgetItems`, `participants` subcollections/tables so all participants see checklist/budget edits live, matching the collaborative intent of "Undang Teman". **[v1.1.0]** Realtime rules/queries must enforce the same per-owner visibility: a participant's subscription must not receive other users' personal `items`/`budgetItems`. The offline indicator in the UI should reflect the SDK's actual connection state (Firestore/Supabase both expose this) rather than the mocked toggle in the prototype.
