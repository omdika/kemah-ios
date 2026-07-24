# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Native SwiftUI implementation of **Kemah**, a group camping trip planner (packing checklist, budget tracking with split-bill settlement, participant management, invites, sharing). The app is built from a versioned design handoff kept in-repo under `trip planner/docs/handoff/`:

- `README.md` and `API_CONTRACT.md` (handoff root = latest version) are the **authoritative specs**. Re-read them before changing models, networking, or split-bill logic. `CHANGELOG.md` tracks spec changes; `versions/vX.Y.Z/` holds archived snapshots.
- `reference/Kemah Travel App.dc.html` is a visual + logic **reference prototype only** — do not copy/embed it. Its `<script>` block (`computeTransfers`, `buildTripView`) is the source of truth for the settlement math, but reflects v1.0.0 scope (no personal-privacy features).

The Xcode project/target is `trip planner` (note the space in the path); the app is Kemah.

## Build & test

This project is driven from Xcode via the `xcode-tools` MCP server — prefer those tools over shell:

- **Build**: `BuildProject`
- **Fast diagnostics for one file** (type errors, bad APIs) without a full build: `XcodeRefreshCodeIssuesInFile`
- **Run tests**: `RunAllTests`, or `RunSomeTests` / `GetTestList` for a subset
- **Try a snippet in a file's context**: `RunCodeSnippet`
- **New source files must be added to the target** — write them with `XcodeWrite` (auto-adds to the project), not the plain filesystem `Write` tool, or they won't compile.

Tests use the **Testing** framework (`import Testing`, `@Test`) and XCUIAutomation for UI tests — not XCTest.

## Architecture

Strict layering, built bottom-up (data → networking → logic → UI). Source under `trip planner/trip planner/`:

- **`Models/`** — `Trip`/`TripSummary`, `Participant`, `ChecklistItem`, `BudgetItem`, split-bill DTOs. Field names and shapes match `API_CONTRACT.md` exactly so JSON decodes with no adapter. `GET /trips` returns `TripSummary` (with `participantCount`/`checklistProgress`); `GET /trips/:id` returns the full `Trip` with nested arrays.
- **`Networking/`** — `APIClient` (async/await REST, `Authorization: Bearer <idToken>` via a `TokenProvider`, multipart upload). `Requests.swift` holds create/update payloads; PATCH bodies use optionals so only provided fields encode. No Firebase/Supabase SDK — the contract is plain REST.
- **`Store/`** — `KemahRepository` protocol with two implementations: `APIRepository` (wraps `APIClient`, real backend) and `MockRepository` (an `actor`, in-memory, seeded from the prototype). Mock is the default so the app runs in the simulator without the FastAPI backend; UI code depends only on the protocol.
- **`SplitBill/`** — `SplitBillCalculator` is a **faithful port** of the prototype's settlement algorithm and is the app's core value. `Formatters` ports `rp()` (currency) and `waLinkFor()` (WhatsApp deep link).
- **`Theme/`** — design tokens from the README's `oklch()` values converted to sRGB hex, accent themes, and the index-cycled avatar palette.

## Split-bill logic (handle with care)

This is the most business-critical code — change it only against the README's "Split Bill Logic" section and the HTML reference, and keep it exact:

- **Per-Orang** items: pooled; each participant's share is proportional to their `headcount`.
- **Pooled Per-PIC** (`pic` blank/nil): pooled; split **flatly** by participant count (headcount ignored).
- **Self-paid Per-PIC** (`pic` set and equal to `paidBy`): **excluded from all settlement**. The person already paid for their own cost; no redistribution to other participants.
- **Direct debt** (`pic` set and different from `paidBy`): a fixed 1:1 debt (`pic` owes `paidBy` the full price), not pooled.
- Settlement = greedy debt simplification over pooled balances, then direct debts appended as-is, then **transfers merged by `(from, to)` pair** with an expandable parts breakdown.
- Computed **client-side** by default (deterministic, no side effects); `GET /trips/:id/split-bill` also exists in `APIClient` if server-side computation is preferred.
- Thresholds are load-bearing: balances within ±1000 are "Lunas"; the greedy matcher ignores amounts ≤ 500. `paidBy` falls back to `pic` when absent (`paidBy || pic` in the original).
- **Personal privacy (v1.1.0):** `BudgetItem.isPersonal`/`owner` and `ChecklistItem.owner` mark private entries. Personal budget items are excluded from the split (`SplitBillCalculator` drops `isPersonal` first) and from the group budget total. Personal checklist + budget items are only returned to their `owner` — `MockRepository.visible(_:)` enforces this per-user filter, mirroring how the real backend filters by auth token. Never render another user's personal entries.

## Conventions

- Deployment target is **iOS 16.0**, so no iOS 17-only APIs (no `@Observable`/`@Bindable`/`@Environment(Type.self)`, no two-parameter `onChange`, no `.spring(duration:)`).
- SwiftUI + async/await for app logic; avoid Combine for data flow. The one exception forced by the iOS 16 target: `TripStore` is an `ObservableObject` (`@Published` + `import Combine`), injected via `@EnvironmentObject`. Bindings use `$store.property`.
- Copy/UI language is **Indonesian** (e.g. "Buat Trip Baru", "Perlengkapan Kelompok", "Bagi rata"). Match it.
- Prefer native iOS controls (nav bars, sheets, share sheet, date picker, SF Symbols) over recreating the HTML's custom chrome; the design is high-fidelity for structure/logic, medium for visual polish.
