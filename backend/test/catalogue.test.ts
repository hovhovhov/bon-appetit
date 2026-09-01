import { describe, expect, it } from "vitest";
import { adversarialRecipeFixture, developmentCatalogue } from "../src/catalog/fixture.js";
import { ValidatedFixtureCatalogueRepository } from "../src/catalog/repository.js";
import { CatalogueSchema } from "../src/contracts/catalogue.js";

describe("validated development catalogue", () => {
  it("accepts every complete development fixture and marks it non-production", async () => {
    const catalogue = await new ValidatedFixtureCatalogueRepository(developmentCatalogue).load();
    expect(catalogue.recipes).toHaveLength(8);
    expect(catalogue.recipes.every((recipe) => recipe.source.clearance === "development-only")).toBe(true);
    expect(catalogue.recipes.every((recipe) => recipe.image.rightsStatus === "weeknight-owned-placeholder")).toBe(true);
  });

  it("rejects a cost that does not equal canonical ingredient costs", async () => {
    const invalid = structuredClone(developmentCatalogue);
    invalid.recipes[0]!.estimatedCost.minorUnits += 1;
    await expect(new ValidatedFixtureCatalogueRepository(invalid).load()).rejects.toMatchObject({
      code: "CATALOGUE_INVALID",
    });
  });

  it("rejects duplicate recipe IDs and malformed records", () => {
    const duplicate = structuredClone(developmentCatalogue);
    duplicate.recipes.push(structuredClone(duplicate.recipes[0]!));
    expect(CatalogueSchema.safeParse(duplicate).success).toBe(false);
    expect(CatalogueSchema.safeParse({ schemaVersion: 1, catalogueVersion: "bad", recipes: [] }).success).toBe(false);
  });

  it("validates instruction-like fixture text only as bounded catalogue data", () => {
    const adversarial = structuredClone(developmentCatalogue);
    adversarial.recipes.push(adversarialRecipeFixture);
    const parsed = CatalogueSchema.parse(adversarial);
    expect(parsed.recipes.at(-1)?.title).toContain("IGNORE PRIOR RULES");
    expect(parsed.recipes.at(-1)?.id).toBe("adversarial-data-only");
  });
});
