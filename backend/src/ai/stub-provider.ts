import type { CatalogueRecipe } from "../contracts/catalogue.js";
import type { RecommendationRequest, WeekPlanRequest } from "../contracts/personalization.js";
import { deterministicRecommendations, deterministicWeekPlan } from "../domain/personalization.js";
import { ProviderFailure, type PersonalizationProvider, type ProviderResult } from "./provider.js";

export class StubPersonalizationProvider implements PersonalizationProvider {
  readonly mode = "stub" as const;

  async recommendations(candidates: CatalogueRecipe[], request: RecommendationRequest) {
    const started = performance.now();
    const output = deterministicRecommendations(candidates, request);
    // The stub intentionally promotes the last safe candidate so Simulator validation can prove remote ordering.
    if (output.recommendations.length > 1) {
      output.recommendations.unshift(output.recommendations.pop()!);
      output.recommendations[0]!.explanation = "Stub-selected variety pick from the validated backend catalogue.";
    }
    return this.result(output, started);
  }

  async weekPlan(candidates: CatalogueRecipe[], request: WeekPlanRequest) {
    const started = performance.now();
    const output = deterministicWeekPlan(candidates, request);
    if (!output) throw new ProviderFailure("unavailable", "Stub could not build a within-budget week");
    output.assignments.forEach((entry) => {
      entry.explanation = "Stub-selected for variety after Weeknight eligibility and budget checks.";
    });
    return this.result(output, started);
  }

  private result<T>(output: T, started: number): ProviderResult<T> {
    return {
      output,
      usage: { provider: "stub", model: "deterministic-stub-v1", latencyMs: Math.round(performance.now() - started) },
    };
  }
}
