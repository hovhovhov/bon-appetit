# Weeknight local backend

This is the local-only Milestone 4 boundary for Weeknight's validated development recipe catalogue and optional personalization. It uses TypeScript, Node.js, Fastify, Zod, and the OpenAI Responses API behind a provider adapter. Stub mode is the default and needs no account, key, network connection, or paid usage.

No public deployment has occurred. This service binds to `127.0.0.1` by default and is not production hosting.

## Architecture

```text
SwiftUI screens
      |
      v
AppStore + deterministic Planning / eligibility / budget / shopping
      |
      v  URLSession, versioned JSON, eligible recipe-ID allow-list
Local backend (Fastify + Zod)
      |
      +--> validated catalogue repository --> development fixtures
      |
      +--> provider interface --> deterministic stub
                            \--> Responses API adapter (optional, server-only)

Every provider result returns through schema + domain validation, then through
the iPhone's deterministic guard, before the existing plan can be committed.
```

## Directory structure

- `src/catalog/` — development fixtures and catalogue repository boundary
- `src/contracts/` — strict runtime and JSON contracts
- `src/domain/` — deterministic selection and post-provider validation
- `src/ai/` — provider interface, stub, and Responses API adapter
- `src/http/` — local rate limiter
- `src/services/` — caching, request deduplication, provider orchestration, fallback
- `test/` — catalogue, API, safety, resilience, and adapter tests
- `scripts/live-smoke.ts` — explicitly locked minimal live check

## Local setup and stub mode

Use Node.js 22 through 25. From Terminal:

```sh
cd /Users/hugo/Desktop/Weeknight/backend
npm install
npm start
```

The default is deterministic stub mode at `http://127.0.0.1:8787`. Keep that Terminal window open while reviewing in Simulator. Stop the backend by returning to the Terminal and pressing Control-C.

To make configuration explicit, copy `.env.example` to `.env.local` and set only the values you need. `.env.local` is ignored by Git. Do not paste keys into source, Xcode settings, screenshots, logs, fixtures, documentation, or a chat.

## Environment variables

| Name | Purpose | Default / limits |
|---|---|---|
| `AI_PROVIDER_MODE` | `stub` or `openai` provider | `stub` |
| `OPENAI_API_KEY` | Server-only credential; required only in `openai` mode | unset |
| `OPENAI_MODEL` | One centrally configured Responses API model | `gpt-5.6-luna` |
| `BACKEND_HOST` | HTTP bind interface | `127.0.0.1` |
| `BACKEND_PORT` | Local port | `8787`, 1–65535 |
| `AI_REQUEST_TIMEOUT_MS` | Provider deadline | `4000`, 250–30000 |
| `AI_MAX_OUTPUT_TOKENS` | Provider output ceiling | `400`, 64–1024 |
| `AI_MAX_CANDIDATES` | Eligible candidates sent per request | `20`, 1–50 |
| `BACKEND_RATE_LIMIT_PER_MINUTE` | Per-client, per-route local limit | `120`, 1–10000 |
| `AI_CACHE_TTL_SECONDS` | Identical result cache lifetime | `120`, 1–3600 |
| `BACKEND_TEST_SCENARIO` | Local UI-test behavior | `normal`; test-only alternative `invalid-recommendations` |

Invalid configuration fails startup with field names only. Secret values are never logged. Future production request and spending limits belong in production server configuration and infrastructure; they are not represented as client-side controls.

## Secure API-key setup (later, only with explicit approval)

1. In Finder, duplicate `backend/.env.example` and rename the copy `.env.local`.
2. Open `.env.local` in a local text editor.
3. Set `AI_PROVIDER_MODE=openai`.
4. Put the key after `OPENAI_API_KEY=` and the approved model after `OPENAI_MODEL=`.
5. Save the file locally. Never share its contents or add it to Git.

The backend reads `.env.local` only from this directory. The iPhone never reads or receives the key. A missing key is normal in stub mode and is rejected at startup only if `openai` mode was explicitly selected.

Milestone 4 made no live API request. After the owner gives explicit approval, one tightly bounded check can be run with:

```sh
cd /Users/hugo/Desktop/Weeknight/backend
WEEKNIGHT_LIVE_SMOKE_APPROVED=YES npm run live:smoke
```

The script refuses to run without that approval flag and records only pass/fail, model, latency, response ID, and token counts. It contains no personal or medical data.

## API contracts

All routes are versioned under `/v1` and accept/return JSON.

- `GET /v1/health` — status, API version, and provider mode
- `GET /v1/catalog/recipes` — schema/versioned development catalogue with source, rights, image, cost provenance, canonical ingredients, instructions, classifications, and ranking metadata
- `POST /v1/recommendations` — orders eligible recipe IDs and supplies short explanations
- `POST /v1/week-plans/generate` — assigns eligible IDs to specified open days

Requests and fixtures pass strict Zod validation. Provider Structured Outputs contain IDs and explanations only. Unknown IDs, duplicate selections, missing days, and over-budget weeks are rejected. Central errors contain a safe code, message, and retryable flag.

## Data transmitted

The iPhone sends the catalogue version; already hard-eligible and scheduled recipe IDs; household serving count; the applicable budget values and currency; maximum cooking minutes; disliked canonical ingredient IDs; preferred protein/style values; and relevant saved recipe IDs.

It does not send recipe notes, raw medical-allergen selections, unrelated saved data, contacts, precise location, advertising IDs, analytics, or secrets. The backend further reduces provider input to eligible candidate IDs, canonical costs/time/classifications, soft-fit flags, and the applicable budget boundary. It does not send recipe titles, sources, ingredient text, notes, or raw medical selections to the provider.

Usage metadata is limited to provider/model, latency, response ID when present, and token counts. Request bodies and preference values are not written to logs.

## Fallback and resilience

- Catalogue GET retries once only for a transient network or 5xx failure; mutation-like POST requests are not retried.
- Provider requests have a deadline, bounded candidates and output, local rate limiting, in-flight deduplication, and a short input-keyed cache.
- Provider refusal, timeout, rate limit, server error, incomplete output, invalid JSON/schema, or invalid domain selection falls back deterministically.
- The app caches the last compatible validated catalogue and otherwise restores its approved local fixture.
- The iPhone repeats hard eligibility and budget checks and commits only through its existing planning layer.

## Tests

Backend:

```sh
cd /Users/hugo/Desktop/Weeknight/backend
npm run typecheck
npm test
npm run build
```

iPhone, from the repository root:

```sh
xcodebuild \
  -project Weeknight.xcodeproj \
  -scheme Weeknight \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  clean test
```

Automated tests use stubs and mock HTTP responses. They neither require a key nor spend tokens.

## Simulator connection

1. Start the backend in stub mode and leave its Terminal window open.
2. Open `Weeknight.xcodeproj` in Xcode.
3. Choose the Weeknight scheme and iPhone 17 Simulator.
4. Run the Debug build.

Debug builds use `http://127.0.0.1:8787` and allow only local networking for this development path. Release builds do not include the backend base URL. The status card says whether the backend stub, cache, local fallback, or offline mode is active.

## Troubleshooting

- **Offline · On-device mode:** confirm `npm start` is still running from `backend/`, then tap **Retry**.
- **Port already in use:** stop the other local process with Control-C, or set `BACKEND_PORT` and the app's `WEEKNIGHT_BACKEND_BASE_URL` launch environment to the same loopback URL.
- **Invalid environment fields:** check names and numeric ranges in `.env.local`; startup errors intentionally omit values.
- **Cached catalogue:** start the backend and tap **Retry** to refresh. The app never trusts an incompatible cache schema.
- **Local fallback active:** the response failed a safety check or the provider was unavailable. Weeknight remains functional through its deterministic engine.
