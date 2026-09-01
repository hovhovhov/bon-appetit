import { describe, expect, it } from "vitest";
import { OpenAIResponsesProvider } from "../src/ai/openai-provider.js";
import { adversarialRecipeFixture } from "../src/catalog/fixture.js";
import { recommendationRequest, testConfig } from "./support.js";

const completedResponse = (text: string) => new Response(JSON.stringify({
  id: "resp_test_safe",
  status: "completed",
  output: [{ type: "message", content: [{ type: "output_text", text }] }],
  usage: { input_tokens: 10, output_tokens: 8, total_tokens: 18 },
}), { status: 200, headers: { "content-type": "application/json" } });

describe("OpenAI Responses API adapter", () => {
  it("uses strict structured output and excludes adversarial recipe text and medical data", async () => {
    let capturedBody = "";
    const mockFetch: typeof fetch = async (_input, init) => {
      capturedBody = String(init?.body);
      return completedResponse(JSON.stringify({ recommendations: [
        { recipeID: adversarialRecipeFixture.id, explanation: "A safe eligible selection.", softFitSignals: [] },
      ] }));
    };
    const provider = new OpenAIResponsesProvider(
      testConfig({ providerMode: "openai", openAIKey: "unit-test-not-a-secret" }),
      mockFetch,
    );
    const result = await provider.recommendations([adversarialRecipeFixture], {
      ...recommendationRequest,
      eligibleRecipeIDs: [adversarialRecipeFixture.id],
    });
    const body = JSON.parse(capturedBody) as Record<string, unknown>;
    expect(JSON.stringify(body)).not.toContain(adversarialRecipeFixture.title);
    expect(JSON.stringify(body)).not.toContain(adversarialRecipeFixture.source.name);
    expect(JSON.stringify(body)).not.toContain(adversarialRecipeFixture.ingredients[0]!.displayName);
    expect(JSON.stringify(body)).not.toContain("medicalAllergens");
    expect(body).toMatchObject({
      model: "test-model",
      store: false,
      text: { format: { type: "json_schema", strict: true } },
    });
    expect(result.output.recommendations[0]?.recipeID).toBe("adversarial-data-only");
    expect(result.usage.totalTokens).toBe(18);
  });

  it("fails closed on invalid JSON, invalid schema, refusal, incomplete output, and rate limits", async () => {
    const config = testConfig({ providerMode: "openai", openAIKey: "unit-test-not-a-secret" });
    const cases: Array<[typeof fetch, string]> = [
      [async () => completedResponse("not-json"), "invalid-json"],
      [async () => completedResponse("{}"), "invalid-schema"],
      [async () => new Response(JSON.stringify({ status: "completed", output: [{ content: [{ type: "refusal", refusal: "no" }] }] }), { status: 200 }), "refusal"],
      [async () => new Response(JSON.stringify({ status: "incomplete", output: [] }), { status: 200 }), "incomplete"],
      [async () => new Response("{}", { status: 429 }), "rate-limit"],
    ];
    for (const [mockFetch, expected] of cases) {
      const provider = new OpenAIResponsesProvider(config, mockFetch);
      await expect(provider.recommendations([adversarialRecipeFixture], recommendationRequest))
        .rejects.toMatchObject({ kind: expected });
    }
  });

  it("enforces a bounded provider timeout", async () => {
    const mockFetch: typeof fetch = async (_input, init) => new Promise((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () => reject(new DOMException("Aborted", "AbortError")));
    });
    const provider = new OpenAIResponsesProvider(
      testConfig({ providerMode: "openai", openAIKey: "unit-test-not-a-secret", providerTimeoutMs: 10 }),
      mockFetch,
    );
    await expect(provider.recommendations([adversarialRecipeFixture], recommendationRequest))
      .rejects.toMatchObject({ kind: "timeout" });
  });
});
