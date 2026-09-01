# ADR 0001: Local backend and optional AI boundary

- Status: Accepted for Milestone 4
- Date: 2026-09-01

## Context

Weeknight's iPhone application already owns deterministic planning, eligibility, budget, and shopping calculations. Milestone 4 needs a validated remote recipe catalogue and optional AI-assisted ordering without placing a provider credential in the app or weakening those rules.

## Decision

Use a small TypeScript/Node.js backend in `backend/`, served by Fastify on the loopback interface for local development. Keep the SwiftUI app and its domain layer native. The backend exposes a small versioned JSON API and accesses its catalogue through a repository protocol.

The AI provider is server-side because this keeps the API key out of the iPhone bundle and centralizes model configuration, timeouts, output bounds, rate limits, caching, usage metadata, and provider error handling.

Before a provider request, the iPhone's deterministic engine creates a hard-eligible recipe-ID allow-list. The backend loads its validated catalogue and intersects it with that allow-list, removes scheduled recipes, and applies the candidate bound. It never sends hard-ineligible catalogue records or raw medical selections to the provider. After AI output, the backend validates its strict schema, IDs, uniqueness, required days, and budget. The iPhone then repeats hard eligibility and plan/budget validation before committing through the existing domain layer.

Use Responses API Structured Outputs with strict JSON Schemas so the model may return only recipe-ID selections and short explanations—not free-form recipe objects. Schema validation is necessary but not sufficient, so every response also undergoes domain validation.

The Milestone 3 engine remains mandatory. Disabled, unconfigured, unavailable, slow, rate-limited, refused, incomplete, malformed, ineligible, or over-budget provider output resolves to a deterministic backend result or the on-device engine. The product remains usable offline.

## Consequences

- The backend and app can evolve independently behind versioned contracts.
- Development fixtures are explicitly unverified and cannot silently become production content.
- AI can influence ordering and selection among eligible IDs, but cannot establish safety, pricing, quantities, or totals.
- A future production service will need authentication, production hosting, durable storage, monitoring, production-cleared content, privacy review, and service budgets. None is authorized or implemented here.
