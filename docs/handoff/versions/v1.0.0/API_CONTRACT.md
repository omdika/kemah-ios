# API Contract: Kemah

Defines the backend contract needed to make the prototype's mocked actions real. Written as REST for portability; if using Firestore/Supabase realtime instead, treat each resource below as a collection/table with the same shape and add realtime listeners on `trips/{id}` and its subcollections instead of polling.

Auth: all endpoints below require `Authorization: Bearer <idToken>` (Google/Apple ID token exchanged via Firebase Auth / Supabase Auth on login). No custom auth server needed — use the BaaS's built-in Google/Apple sign-in and pass its session token through.

## Users

### `GET /me`
Returns the signed-in user's profile.
```json
{ "id": "u_123", "name": "Dinda", "email": "dinda@example.com", "avatarUrl": null }
```

## Trips

### `GET /trips`
List trips the signed-in user participates in.
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
Full trip detail including nested lists.
```json
{
  "id": "t1", "name": "...", "location": "...", "date": "2026-08-01", "coverUrl": "...",
  "mapLink": "...", "phone": "...", "status": "upcoming",
  "budgetTarget": 1200000, "budgetMode": "manual",
  "participants": [ { "id": "p1", "name": "Dinda", "picForLabel": "Koordinator", "headcount": 1 } ],
  "items": [ { "id": "i1", "name": "Tenda dome 4 orang", "qty": 1, "pic": "Rangga",
      "note": "cek patok & pasak lengkap", "checked": true, "isPersonal": false } ],
  "budgetItems": [ { "id": "b1", "name": "Sewa mobil", "price": 100000,
      "paidBy": "Dinda", "pic": null, "splitMode": "pic" } ]
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

### `PATCH /:itemId`
Any subset of `name, qty, pic, note, checked, isPersonal`. Toggling done state is `PATCH { "checked": true }`.

### `DELETE /:itemId`

## Budget Items (`/trips/:tripId/budget-items`)

### `POST /`
```json
{ "name": "Bensin & tol", "price": 100000, "paidBy": "Dinda", "pic": null, "splitMode": "orang" }
```
- `splitMode`: `"orang"` or `"pic"`.
- `pic`: null/omitted unless this is a `"pic"`-mode expense that belongs to someone other than `paidBy`.

### `PATCH /:budgetItemId`
Any subset of `name, price, paidBy, pic, splitMode`.

### `DELETE /:budgetItemId`

## Split Bill (`GET /trips/:tripId/split-bill`)
Server-computed settlement (recommended: compute this endpoint server-side using the exact algorithm in the main README's "Split Bill Logic" section, so the client never has to trust its own math for money — but it's also safe to compute purely client-side from the trip payload above, since the algorithm is deterministic and has no side effects).
```json
{
  "equalShareLabel": "Rp40.000",
  "participantCount": 5,
  "perPerson": [
    { "name": "Dinda", "paid": 200000, "share": 40000, "balance": 160000 },
    { "name": "Rangga", "paid": 0, "share": 40000, "balance": -40000 }
  ],
  "transfers": [
    { "from": "Rangga", "to": "Dinda", "amount": 40000,
      "parts": [ { "label": "Bagi rata", "amount": 20000 }, { "label": "Sewa mobil", "amount": 20000 } ] }
  ]
}
```

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
If using Firestore/Supabase: subscribe to `trips/{id}` and its `items`, `budgetItems`, `participants` subcollections/tables so all participants see checklist/budget edits live, matching the collaborative intent of "Undang Teman". The offline indicator in the UI should reflect the SDK's actual connection state (Firestore/Supabase both expose this) rather than the mocked toggle in the prototype.
