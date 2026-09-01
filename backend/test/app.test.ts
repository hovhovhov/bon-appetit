import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";
import { redact } from "../src/errors.js";
import { FixedWindowRateLimiter } from "../src/http/rate-limiter.js";
import { recommendationRequest, testConfig } from "./support.js";

describe("versioned HTTP API", () => {
  it("serves health and validated catalogue endpoints", async () => {
    const app = buildApp({ config: testConfig(), logger: false });
    const health = await app.inject({ method: "GET", url: "/v1/health" });
    expect(health.statusCode).toBe(200);
    expect(health.json()).toMatchObject({ status: "ok", providerMode: "stub", apiVersion: "v1" });
    const catalogue = await app.inject({ method: "GET", url: "/v1/catalog/recipes" });
    expect(catalogue.statusCode).toBe(200);
    expect(catalogue.json().recipes).toHaveLength(8);
    await app.close();
  });

  it("returns typed validation errors without echoing request data", async () => {
    const app = buildApp({ config: testConfig(), logger: false });
    const response = await app.inject({ method: "POST", url: "/v1/recommendations", payload: { secret: "do-not-echo" } });
    expect(response.statusCode).toBe(400);
    expect(response.body).not.toContain("do-not-echo");
    expect(response.json()).toEqual({
      error: { code: "BAD_REQUEST", message: "Request failed runtime validation", retryable: false },
    });
    await app.close();
  });

  it("rate-limits by route and client with a typed retryable response", async () => {
    let now = 0;
    const limiter = new FixedWindowRateLimiter(1, 60_000, () => now);
    const app = buildApp({ config: testConfig(), logger: false, rateLimiter: limiter });
    expect((await app.inject({ method: "POST", url: "/v1/recommendations", payload: recommendationRequest })).statusCode).toBe(200);
    const limited = await app.inject({ method: "POST", url: "/v1/recommendations", payload: recommendationRequest });
    expect(limited.statusCode).toBe(429);
    expect(limited.json().error).toMatchObject({ code: "RATE_LIMITED", retryable: true });
    now = 60_001;
    expect((await app.inject({ method: "POST", url: "/v1/recommendations", payload: recommendationRequest })).statusCode).toBe(200);
    await app.close();
  });
});

describe("structured secret and medical-data redaction", () => {
  it("redacts sensitive keys recursively without mutating safe usage metadata", () => {
    const input = {
      authorization: "Bearer secret",
      OPENAI_API_KEY: "secret",
      nested: { medicalAllergens: ["Milk"], model: "safe-model", totalTokens: 12 },
    };
    expect(redact(input)).toEqual({
      authorization: "[REDACTED]",
      OPENAI_API_KEY: "[REDACTED]",
      nested: { medicalAllergens: "[REDACTED]", model: "safe-model", totalTokens: 12 },
    });
  });
});
