import { createHash } from "node:crypto";
import type { RecipeCatalogueRepository } from "../catalog/repository.js";
import type { BackendConfig } from "../config.js";
import type { RecommendationRequest, WeekPlanRequest } from "../contracts/personalization.js";
import {
  deterministicRecommendations,
  deterministicWeekPlan,
  eligibleCandidates,
  validateRecommendationOutput,
  validateWeekPlanOutput,
} from "../domain/personalization.js";
import type { PersonalizationProvider, ProviderUsage } from "../ai/provider.js";

export type PersonalizationStatus = "stub" | "openai" | "fallback";

type RecommendationResponse = {
  schemaVersion: 1;
  catalogueVersion: string;
  status: PersonalizationStatus;
  fallbackReason?: string;
  recommendations: Array<{ recipeID: string; explanation: string; softFitSignals: string[] }>;
  usage: ProviderUsage | null;
};

type WeekPlanResponse = {
  schemaVersion: 1;
  catalogueVersion: string;
  status: PersonalizationStatus;
  outcome: "success" | "unable";
  fallbackReason?: string;
  assignments: Array<{ day: string; recipeID: string; explanation: string }>;
  message?: string;
  usage: ProviderUsage | null;
};

type CacheEntry<T> = { expiresAt: number; value: T };

export class PersonalizationService {
  private readonly cache = new Map<string, CacheEntry<unknown>>();
  private readonly inFlight = new Map<string, Promise<unknown>>();

  constructor(
    private readonly repository: RecipeCatalogueRepository,
    private readonly provider: PersonalizationProvider,
    private readonly config: BackendConfig,
    private readonly now: () => number = Date.now,
  ) {}

  recommendations(request: RecommendationRequest): Promise<RecommendationResponse> {
    return this.deduplicated("recommendations-v1", request, () => this.performRecommendations(request));
  }

  weekPlan(request: WeekPlanRequest): Promise<WeekPlanResponse> {
    return this.deduplicated("week-plans-generate-v1", request, () => this.performWeekPlan(request));
  }

  private async performRecommendations(request: RecommendationRequest): Promise<RecommendationResponse> {
    const catalogue = await this.repository.load();
    const candidates = eligibleCandidates(
      catalogue,
      request.eligibleRecipeIDs,
      request.scheduledRecipeIDs,
      this.config.maxCandidates,
    );
    const fallback = deterministicRecommendations(candidates, request);
    if (candidates.length === 0 || request.catalogueVersion !== catalogue.catalogueVersion) {
      return {
        schemaVersion: 1,
        catalogueVersion: catalogue.catalogueVersion,
        status: "fallback",
        fallbackReason: candidates.length === 0 ? "no-eligible-candidates" : "catalogue-version-mismatch",
        recommendations: fallback.recommendations,
        usage: null,
      };
    }
    try {
      const result = await this.provider.recommendations(candidates, request);
      const validated = validateRecommendationOutput(result.output, candidates);
      return {
        schemaVersion: 1,
        catalogueVersion: catalogue.catalogueVersion,
        status: this.provider.mode,
        recommendations: validated.recommendations,
        usage: result.usage,
      };
    } catch (error) {
      return {
        schemaVersion: 1,
        catalogueVersion: catalogue.catalogueVersion,
        status: "fallback",
        fallbackReason: safeReason(error),
        recommendations: fallback.recommendations,
        usage: null,
      };
    }
  }

  private async performWeekPlan(request: WeekPlanRequest): Promise<WeekPlanResponse> {
    const catalogue = await this.repository.load();
    const candidates = eligibleCandidates(
      catalogue,
      request.eligibleRecipeIDs,
      request.scheduledRecipeIDs,
      this.config.maxCandidates,
    );
    const fallback = deterministicWeekPlan(candidates, request);
    if (request.catalogueVersion !== catalogue.catalogueVersion) {
      return this.fallbackWeek(catalogue.catalogueVersion, fallback, "catalogue-version-mismatch");
    }
    try {
      const result = await this.provider.weekPlan(candidates, request);
      const validated = validateWeekPlanOutput(result.output, candidates, request);
      return {
        schemaVersion: 1,
        catalogueVersion: catalogue.catalogueVersion,
        status: this.provider.mode,
        outcome: "success",
        assignments: validated.assignments,
        usage: result.usage,
      };
    } catch (error) {
      return this.fallbackWeek(catalogue.catalogueVersion, fallback, safeReason(error));
    }
  }

  private fallbackWeek(
    catalogueVersion: string,
    fallback: ReturnType<typeof deterministicWeekPlan>,
    reason: string,
  ): WeekPlanResponse {
    if (!fallback) {
      return {
        schemaVersion: 1,
        catalogueVersion,
        status: "fallback",
        outcome: "unable",
        fallbackReason: reason,
        assignments: [],
        message: "No eligible combination fits the current deterministic budget and plan rules.",
        usage: null,
      };
    }
    return {
      schemaVersion: 1,
      catalogueVersion,
      status: "fallback",
      outcome: "success",
      fallbackReason: reason,
      assignments: fallback.assignments,
      usage: null,
    };
  }

  private deduplicated<T>(namespace: string, input: unknown, operation: () => Promise<T>): Promise<T> {
    const key = `${namespace}:${hashStable(input)}`;
    const cached = this.cache.get(key) as CacheEntry<T> | undefined;
    if (cached && cached.expiresAt > this.now()) return Promise.resolve(cached.value);
    const existing = this.inFlight.get(key) as Promise<T> | undefined;
    if (existing) return existing;
    const pending = operation()
      .then((value) => {
        this.cache.set(key, { expiresAt: this.now() + this.config.cacheTtlMs, value });
        return value;
      })
      .finally(() => this.inFlight.delete(key));
    this.inFlight.set(key, pending);
    return pending;
  }
}

function safeReason(error: unknown): string {
  if (error && typeof error === "object" && "kind" in error && typeof error.kind === "string") return error.kind;
  if (error && typeof error === "object" && "reason" in error && typeof error.reason === "string") return error.reason;
  return "invalid-provider-result";
}

function hashStable(input: unknown): string {
  const normalize = (value: unknown): unknown => {
    if (Array.isArray(value)) return value.map(normalize);
    if (value && typeof value === "object") {
      return Object.fromEntries(
        Object.entries(value as Record<string, unknown>)
          .sort(([left], [right]) => left.localeCompare(right))
          .map(([key, nested]) => [key, normalize(nested)]),
      );
    }
    return value;
  };
  return createHash("sha256").update(JSON.stringify(normalize(input))).digest("hex");
}
