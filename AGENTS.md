# Weeknight project rules

- Build the product only with native Swift and SwiftUI, for iPhone.
- Backend code may use a separate server-appropriate language and runtime; keep it outside the native iPhone target.
- Follow this authority order: current approved request, `docs/WEEKNIGHT_NATIVE_IOS_IMPLEMENTATION_PLAN.md`, `docs/WEEKNIGHT_DESIGN_HANDOFF.md`, PNG references, then exported design material.
- Treat the weekly plan as the source of truth. Derive budget, completion, and shopping totals from it.
- Keep hard eligibility and financial calculations deterministic before and after optional AI selection.
- Treat all AI output as untrusted until both schema validation and domain validation pass.
- Every AI-assisted feature must retain a deterministic fallback.
- Never place API secrets in the iPhone application, Git history, screenshots, logs, fixtures, or documentation.
- Use only safe, rights-cleared assets in the application target.
- Do not deploy externally, create accounts, make purchases, or activate paid services without explicit approval.
- Complete only the currently approved milestone; do not start later roadmap work.
- Build, test, and validate in the iOS Simulator before reporting completion.
