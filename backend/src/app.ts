import Fastify, { type FastifyInstance } from "fastify";
import { ZodError } from "zod";
import { StubPersonalizationProvider } from "./ai/stub-provider.js";
import { OpenAIResponsesProvider } from "./ai/openai-provider.js";
import type { PersonalizationProvider } from "./ai/provider.js";
import { developmentCatalogue } from "./catalog/fixture.js";
import {
  ValidatedFixtureCatalogueRepository,
  type RecipeCatalogueRepository,
} from "./catalog/repository.js";
import { loadConfig, type BackendConfig } from "./config.js";
import {
  RecommendationRequestSchema,
  WeekPlanRequestSchema,
} from "./contracts/personalization.js";
import { AppError } from "./errors.js";
import { FixedWindowRateLimiter } from "./http/rate-limiter.js";
import { PersonalizationService } from "./services/personalization-service.js";

export type AppDependencies = {
  config?: BackendConfig;
  repository?: RecipeCatalogueRepository;
  provider?: PersonalizationProvider;
  logger?: boolean;
  rateLimiter?: FixedWindowRateLimiter;
};

export function buildApp(dependencies: AppDependencies = {}): FastifyInstance {
  const config = dependencies.config ?? loadConfig();
  const repository = dependencies.repository ?? new ValidatedFixtureCatalogueRepository(developmentCatalogue);
  const provider = dependencies.provider ?? makeProvider(config);
  const service = new PersonalizationService(repository, provider, config);
  const rateLimiter = dependencies.rateLimiter ?? new FixedWindowRateLimiter(config.rateLimitPerMinute);

  const app = Fastify({
    logger: dependencies.logger === false
      ? false
      : {
          level: "info",
          redact: {
            paths: ["req.headers.authorization", "req.headers.cookie", "apiKey", "openAIKey"],
            censor: "[REDACTED]",
          },
        },
    requestTimeout: config.providerTimeoutMs + 2_000,
    bodyLimit: 128 * 1_024,
    genReqId: () => crypto.randomUUID(),
  });

  app.addHook("onRequest", async (request) => {
    rateLimiter.check(`${request.ip}:${request.method}:${request.routeOptions.url ?? request.url}`);
  });

  app.get("/v1/health", async () => ({
    status: "ok",
    service: "weeknight-local-backend",
    apiVersion: "v1",
    providerMode: config.providerMode,
  }));

  app.get("/v1/catalog/recipes", async () => repository.load());

  app.post("/v1/recommendations", async (request) => {
    const parsed = RecommendationRequestSchema.parse(request.body);
    if (config.testScenario === "invalid-recommendations") {
      return {
        schemaVersion: 1,
        catalogueVersion: parsed.catalogueVersion,
        status: "stub",
        recommendations: [{ recipeID: "invented-id", explanation: "Deliberately invalid local test response.", softFitSignals: [] }],
        usage: null,
      };
    }
    return service.recommendations(parsed);
  });

  app.post("/v1/week-plans/generate", async (request) => {
    const parsed = WeekPlanRequestSchema.parse(request.body);
    return service.weekPlan(parsed);
  });

  app.setNotFoundHandler(async (_request, reply) => {
    return reply.status(404).send({
      error: { code: "NOT_FOUND", message: "Route not found", retryable: false },
    });
  });

  app.setErrorHandler(async (error, request, reply) => {
    if (error instanceof ZodError) {
      return reply.status(400).send({
        error: { code: "BAD_REQUEST", message: "Request failed runtime validation", retryable: false },
      });
    }
    if (error instanceof AppError) {
      return reply.status(error.statusCode).send({
        error: { code: error.code, message: error.message, retryable: error.retryable },
      });
    }
    request.log.error(
      { requestID: request.id, errorType: error instanceof Error ? error.name : "UnknownError" },
      "request_failed",
    );
    return reply.status(500).send({
      error: { code: "INTERNAL_ERROR", message: "The local service could not complete the request", retryable: false },
    });
  });

  return app;
}

function makeProvider(config: BackendConfig): PersonalizationProvider {
  if (config.providerMode === "openai") return new OpenAIResponsesProvider(config);
  return new StubPersonalizationProvider();
}
