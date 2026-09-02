import type { BackendConfig } from "../src/config.js";
import type { CatalogueRecipe } from "../src/contracts/catalogue.js";
import type {
  AIRecommendationOutput,
  AIWeekPlanOutput,
  RecommendationRequest,
  WeekPlanRequest,
} from "../src/contracts/personalization.js";
import type { PersonalizationProvider, ProviderResult } from "../src/ai/provider.js";

export const testConfig = (overrides: Partial<BackendConfig> = {}): BackendConfig => ({
  providerMode: "stub",
  openAIModel: "test-model",
  host: "127.0.0.1",
  port: 8787,
  providerTimeoutMs: 250,
  maxOutputTokens: 200,
  maxCandidates: 20,
  rateLimitPerMinute: 120,
  cacheTtlMs: 10_000,
  testScenario: "normal",
  ...overrides,
});

export const recommendationRequest: RecommendationRequest = {
  schemaVersion: 1,
  catalogueVersion: "dev-2026-08-31.2",
  eligibleRecipeIDs: ["carbonara", "curry", "caesar", "chopped", "steak"],
  scheduledRecipeIDs: ["honeysoy", "chilli", "stirfry"],
  remainingBudgetMinorUnits: 5_000,
  currency: "USD",
  householdSize: 1,
  preferences: {
    maximumCookingMinutes: 45,
    dislikedIngredientIDs: [],
    preferredProteins: ["Pork"],
    preferredMealStyles: ["Speedy"],
    savedRecipeIDs: ["curry"],
  },
};

export const weekPlanRequest: WeekPlanRequest = {
  schemaVersion: 1,
  catalogueVersion: "dev-2026-08-31.2",
  eligibleRecipeIDs: ["carbonara", "curry", "caesar", "chopped", "steak"],
  scheduledRecipeIDs: ["honeysoy", "chilli", "stirfry"],
  openDays: ["Thursday", "Friday"],
  currentSpendMinorUnits: 3_990,
  budgetMinorUnits: 8_000,
  currency: "USD",
  householdSize: 1,
  preferences: recommendationRequest.preferences,
};

export class RecordingProvider implements PersonalizationProvider {
  readonly mode = "stub" as const;
  recommendationCalls = 0;
  weekCalls = 0;
  recommendationCandidates: CatalogueRecipe[] = [];
  weekCandidates: CatalogueRecipe[] = [];
  recommendationOutput?: AIRecommendationOutput;
  weekOutput?: AIWeekPlanOutput;
  failure?: Error;
  delay?: Promise<void>;

  async recommendations(candidates: CatalogueRecipe[], _request: RecommendationRequest) {
    this.recommendationCalls += 1;
    this.recommendationCandidates = candidates;
    if (this.delay) await this.delay;
    if (this.failure) throw this.failure;
    return this.result(
      this.recommendationOutput ?? {
        recommendations: candidates.map((recipe) => ({ recipeID: recipe.id, explanation: "Mock safe explanation.", softFitSignals: [] })),
      },
    );
  }

  async weekPlan(candidates: CatalogueRecipe[], request: WeekPlanRequest) {
    this.weekCalls += 1;
    this.weekCandidates = candidates;
    if (this.failure) throw this.failure;
    return this.result(
      this.weekOutput ?? {
        assignments: request.openDays.map((day, index) => ({
          day,
          recipeID: candidates[index]!.id,
          explanation: "Mock safe assignment.",
        })),
      },
    );
  }

  private result<T>(output: T): ProviderResult<T> {
    return { output, usage: { provider: "stub", model: "recording-test", latencyMs: 0 } };
  }
}
