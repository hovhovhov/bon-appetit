import { describe, expect, it } from "vitest";
import { ProviderFailure } from "../src/ai/provider.js";
import { developmentCatalogue } from "../src/catalog/fixture.js";
import { ValidatedFixtureCatalogueRepository } from "../src/catalog/repository.js";
import { RecommendationRequestSchema } from "../src/contracts/personalization.js";
import {
  PersonalizationValidationError,
  eligibleCandidates,
  validateRecommendationOutput,
  validateWeekPlanOutput,
} from "../src/domain/personalization.js";
import { PersonalizationService } from "../src/services/personalization-service.js";
import {
  RecordingProvider,
  recommendationRequest,
  testConfig,
  weekPlanRequest,
} from "./support.js";

const repository = new ValidatedFixtureCatalogueRepository(developmentCatalogue);

describe("deterministic eligibility boundaries", () => {
  it("sends only client-hard-eligible, unscheduled, known candidates to the provider", async () => {
    const provider = new RecordingProvider();
    const service = new PersonalizationService(repository, provider, testConfig());
    await service.recommendations({
      ...recommendationRequest,
      eligibleRecipeIDs: ["carbonara", "honeysoy", "invented-id"],
    });
    expect(provider.recommendationCandidates.map((recipe) => recipe.id)).toEqual(["carbonara"]);
  });

  it("does not accept raw medical selections in the minimal backend request", () => {
    const request = { ...recommendationRequest, medicalAllergens: ["Milk"] };
    expect(RecommendationRequestSchema.safeParse(request).success).toBe(false);
  });

  it("rejects unknown, ineligible, and duplicate recommendation IDs", () => {
    const candidates = eligibleCandidates(developmentCatalogue, ["carbonara", "curry"], [], 20);
    expect(() => validateRecommendationOutput({ recommendations: [
      { recipeID: "invented-id", explanation: "No", softFitSignals: [] },
    ] }, candidates)).toThrow(PersonalizationValidationError);
    expect(() => validateRecommendationOutput({ recommendations: [
      { recipeID: "carbonara", explanation: "One", softFitSignals: [] },
      { recipeID: "carbonara", explanation: "Two", softFitSignals: [] },
    ] }, candidates)).toThrow("duplicate-recipe-id");
  });

  it("rejects duplicate selections, missing days, and over-budget AI weeks", () => {
    const candidates = eligibleCandidates(developmentCatalogue, weekPlanRequest.eligibleRecipeIDs, [], 20);
    expect(() => validateWeekPlanOutput({ assignments: [
      { day: "Thursday", recipeID: "carbonara", explanation: "One" },
      { day: "Friday", recipeID: "carbonara", explanation: "Two" },
    ] }, candidates, weekPlanRequest)).toThrow("duplicate-recipe-id");
    expect(() => validateWeekPlanOutput({ assignments: [
      { day: "Thursday", recipeID: "carbonara", explanation: "One" },
    ] }, candidates, weekPlanRequest)).toThrow("missing-required-day");
    expect(() => validateWeekPlanOutput({ assignments: [
      { day: "Thursday", recipeID: "steak", explanation: "One" },
      { day: "Friday", recipeID: "curry", explanation: "Two" },
    ] }, candidates, { ...weekPlanRequest, budgetMinorUnits: 5_000 })).toThrow("over-budget");
  });
});

describe("safe provider fallback", () => {
  it.each([
    ["refusal", "refusal"],
    ["timeout", "timeout"],
    ["rate limit", "rate-limit"],
    ["server", "server-error"],
    ["invalid JSON", "invalid-json"],
    ["incomplete", "incomplete"],
  ] as const)("falls back deterministically on %s", async (_label, kind) => {
    const provider = new RecordingProvider();
    provider.failure = new ProviderFailure(kind, "test failure");
    const result = await new PersonalizationService(repository, provider, testConfig())
      .recommendations(recommendationRequest);
    expect(result.status).toBe("fallback");
    expect(result.fallbackReason).toBe(kind);
    expect(result.recommendations.length).toBeGreaterThan(0);
  });

  it("falls back after schema-valid but domain-invalid provider output", async () => {
    const provider = new RecordingProvider();
    provider.recommendationOutput = {
      recommendations: [{ recipeID: "invented-id", explanation: "Unsafe", softFitSignals: [] }],
    };
    const result = await new PersonalizationService(repository, provider, testConfig())
      .recommendations(recommendationRequest);
    expect(result.status).toBe("fallback");
    expect(result.fallbackReason).toBe("unknown-or-ineligible-recipe-id");
  });

  it("falls back from an invalid or over-budget week before anything reaches a plan", async () => {
    const provider = new RecordingProvider();
    provider.weekOutput = { assignments: [
      { day: "Thursday", recipeID: "steak", explanation: "Unsafe cost" },
      { day: "Friday", recipeID: "curry", explanation: "Unsafe cost" },
    ] };
    const result = await new PersonalizationService(repository, provider, testConfig())
      .weekPlan({ ...weekPlanRequest, budgetMinorUnits: 5_000 });
    expect(result.status).toBe("fallback");
    expect(result.assignments.every((entry) => entry.recipeID !== "steak")).toBe(true);
  });

  it("caches identical completed requests and deduplicates identical in-flight work", async () => {
    const provider = new RecordingProvider();
    let release!: () => void;
    provider.delay = new Promise<void>((resolve) => { release = resolve; });
    const service = new PersonalizationService(repository, provider, testConfig());
    const first = service.recommendations(recommendationRequest);
    const second = service.recommendations(recommendationRequest);
    release();
    await Promise.all([first, second]);
    await service.recommendations(recommendationRequest);
    expect(provider.recommendationCalls).toBe(1);
  });
});
