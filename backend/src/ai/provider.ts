import type { CatalogueRecipe } from "../contracts/catalogue.js";
import type {
  AIRecommendationOutput,
  AIWeekPlanOutput,
  RecommendationRequest,
  WeekPlanRequest,
} from "../contracts/personalization.js";

export type ProviderUsage = {
  provider: "stub" | "openai";
  model: string;
  latencyMs: number;
  responseID?: string;
  inputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
};

export type ProviderResult<T> = { output: T; usage: ProviderUsage };

export type ProviderFailureKind =
  | "refusal"
  | "timeout"
  | "rate-limit"
  | "server-error"
  | "invalid-json"
  | "invalid-schema"
  | "incomplete"
  | "unavailable";

export class ProviderFailure extends Error {
  constructor(readonly kind: ProviderFailureKind, message: string) {
    super(message);
    this.name = "ProviderFailure";
  }
}

export interface PersonalizationProvider {
  readonly mode: "stub" | "openai";
  recommendations(
    candidates: CatalogueRecipe[],
    request: RecommendationRequest,
  ): Promise<ProviderResult<AIRecommendationOutput>>;
  weekPlan(
    candidates: CatalogueRecipe[],
    request: WeekPlanRequest,
  ): Promise<ProviderResult<AIWeekPlanOutput>>;
}
