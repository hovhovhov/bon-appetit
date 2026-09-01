# Milestone 4 validation record

- Date: September 1, 2026
- Primary device: iPhone 17 Simulator, iOS 26.5
- Xcode: 26.6 (build 17F113)
- Backend runtime: Node.js 25.2.1, npm 11.6.2
- Provider mode: deterministic stub
- Live API calls: none

## Automated results

- Backend TypeScript typecheck: passed
- Backend Vitest suite: 24 passed, 0 failed
- Backend production compilation: passed
- Native clean build and test: passed
- Swift unit/store/transport suite: 52 passed, 0 failed
- UI suite: 18 passed, 0 failed
- Milestone 1–3 regression UI journeys: 15 passed unchanged
- Release iPhone Simulator build: passed

The expected timeout-path URLSession diagnostic appeared during its mock transport test; that test passed and represents the intentionally simulated timeout.

## Simulator scenarios

Validated with the loopback backend in stub mode:

1. The app loaded the schema-validated remote development catalogue.
2. Discover used the backend stub's ordering and displayed a short preference explanation.
3. Week generation selected only known, eligible IDs for all open days.
4. The iPhone recalculated and committed Plan, budget, and Shopping through the existing deterministic domain layer.
5. A deliberately invented recommendation ID was rejected and produced an honest local fallback.
6. An unreachable backend preserved an interactive on-device catalogue and exposed Retry.
7. The complete Milestone 1–3 UI suite passed with backend integration disabled for its canonical deterministic launch states.

## Accessibility and design review

- The new status surface has semantic text, a named Retry action, a 44-by-44-point Retry target, and a 44-point minimum container height.
- It uses native SwiftUI controls and Dynamic Type fonts, does not introduce custom motion, and exposes loading, connected, cached, fallback, and unavailable states in text rather than color alone.
- Existing large-Dynamic-Type journeys still pass.
- Compared with `design-reference/discover.png` and `design-reference/homepage.png`, Milestone 4 retains the approved cream/forest palette, rounded cards, visible actions, native tab bar, and strong content hierarchy.
- Intentional deviation: remote development records use Weeknight-owned native placeholders instead of reference photography because the supplied photography is not verified for shipping.

## Screenshot evidence

- `artifacts/milestone-4/screenshots/18-discover-backend-catalogue.png`
- `artifacts/milestone-4/screenshots/19-backend-personalized-explanations.png`
- `artifacts/milestone-4/screenshots/20-backend-generated-week.png`
- `artifacts/milestone-4/screenshots/21-honest-local-fallback.png`
- `artifacts/milestone-4/screenshots/22-backend-unavailable-recovery.png`

## Security and privacy checks

- `.env.local`, dependency output, build output, coverage, and logs are ignored by Git.
- The Release app Info.plist contains neither a backend URL nor a local-network exception.
- The repository and Release bundle contain no key-shaped value.
- Backend logging excludes request bodies and redacts authorization, API-key, secret, medical/allergen, and access-token fields.
- Automated tests use mocks/stubs and do not require or spend an API key.
- The live smoke script was not run and remains locked behind an explicit approval flag.

## Remaining production work (out of scope)

Public hosting, authentication, a production database, production-cleared catalogue and media, operational monitoring, privacy/security review, durable production rate/spend limits, and live-provider validation remain deliberately unimplemented.
