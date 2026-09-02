import { buildApp } from "../src/app.js";
import { loadConfig } from "../src/config.js";

if (process.env.WEEKNIGHT_LIVE_SMOKE_APPROVED !== "YES") {
  throw new Error("Live smoke test is locked. Set WEEKNIGHT_LIVE_SMOKE_APPROVED=YES only after explicit approval.");
}

const config = loadConfig();
if (config.providerMode !== "openai") throw new Error("AI_PROVIDER_MODE must be openai for a live smoke test");

const app = buildApp({ config, logger: false });
const response = await app.inject({
  method: "POST",
  url: "/v1/recommendations",
  payload: {
    schemaVersion: 1,
    catalogueVersion: "dev-2026-08-31.2",
    eligibleRecipeIDs: ["carbonara", "curry"],
    scheduledRecipeIDs: [],
    remainingBudgetMinorUnits: 3_000,
    currency: "USD",
    householdSize: 1,
    preferences: {
      maximumCookingMinutes: 45,
      dislikedIngredientIDs: [],
      preferredProteins: [],
      preferredMealStyles: ["Speedy"],
      savedRecipeIDs: [],
    },
  },
});

const body = response.json() as {
  status?: string;
  usage?: { model?: string; latencyMs?: number; responseID?: string; totalTokens?: number };
};
console.log(JSON.stringify({
  passed: response.statusCode === 200 && body.status === "openai",
  statusCode: response.statusCode,
  model: body.usage?.model,
  latencyMs: body.usage?.latencyMs,
  responseID: body.usage?.responseID,
  totalTokens: body.usage?.totalTokens,
}));
await app.close();
