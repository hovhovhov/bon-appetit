import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { z } from "zod";

const localEnvironmentPath = resolve(process.cwd(), ".env.local");
if (existsSync(localEnvironmentPath)) {
  process.loadEnvFile(localEnvironmentPath);
}

const EnvironmentSchema = z.object({
  AI_PROVIDER_MODE: z.enum(["stub", "openai"]).default("stub"),
  OPENAI_API_KEY: z.string().min(1).optional(),
  OPENAI_MODEL: z.string().min(1).default("gpt-5.6-luna"),
  BACKEND_HOST: z.string().default("127.0.0.1"),
  BACKEND_PORT: z.coerce.number().int().min(1).max(65_535).default(8787),
  AI_REQUEST_TIMEOUT_MS: z.coerce.number().int().min(250).max(30_000).default(4_000),
  AI_MAX_OUTPUT_TOKENS: z.coerce.number().int().min(64).max(1_024).default(400),
  AI_MAX_CANDIDATES: z.coerce.number().int().min(1).max(50).default(20),
  BACKEND_RATE_LIMIT_PER_MINUTE: z.coerce.number().int().min(1).max(10_000).default(120),
  AI_CACHE_TTL_SECONDS: z.coerce.number().int().min(1).max(3_600).default(120),
  BACKEND_TEST_SCENARIO: z.enum(["normal", "invalid-recommendations"]).default("normal"),
});

export type BackendConfig = {
  providerMode: "stub" | "openai";
  openAIKey?: string;
  openAIModel: string;
  host: string;
  port: number;
  providerTimeoutMs: number;
  maxOutputTokens: number;
  maxCandidates: number;
  rateLimitPerMinute: number;
  cacheTtlMs: number;
  testScenario: "normal" | "invalid-recommendations";
};

export function loadConfig(environment: NodeJS.ProcessEnv = process.env): BackendConfig {
  const parsed = EnvironmentSchema.safeParse(environment);
  if (!parsed.success) {
    const fields = parsed.error.issues.map((issue) => issue.path.join(".")).join(", ");
    throw new Error(`Invalid backend environment fields: ${fields}`);
  }
  if (parsed.data.AI_PROVIDER_MODE === "openai" && !parsed.data.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY is required when AI_PROVIDER_MODE=openai");
  }
  return {
    providerMode: parsed.data.AI_PROVIDER_MODE,
    ...(parsed.data.OPENAI_API_KEY ? { openAIKey: parsed.data.OPENAI_API_KEY } : {}),
    openAIModel: parsed.data.OPENAI_MODEL,
    host: parsed.data.BACKEND_HOST,
    port: parsed.data.BACKEND_PORT,
    providerTimeoutMs: parsed.data.AI_REQUEST_TIMEOUT_MS,
    maxOutputTokens: parsed.data.AI_MAX_OUTPUT_TOKENS,
    maxCandidates: parsed.data.AI_MAX_CANDIDATES,
    rateLimitPerMinute: parsed.data.BACKEND_RATE_LIMIT_PER_MINUTE,
    cacheTtlMs: parsed.data.AI_CACHE_TTL_SECONDS * 1_000,
    testScenario: parsed.data.BACKEND_TEST_SCENARIO,
  };
}
