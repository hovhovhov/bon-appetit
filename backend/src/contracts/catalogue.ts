import { z } from "zod";

export const AllergenSchema = z.enum(["Milk", "Egg", "Fish", "Wheat", "Soy", "Sesame"]);
export const DietarySchema = z.enum(["Vegetarian", "Vegan", "Pescatarian", "Gluten-free"]);
export const ApplianceSchema = z.enum(["Stovetop", "Oven", "Microwave", "Air fryer", "Blender"]);
export const ProteinSchema = z.enum(["Chicken", "Beef", "Pork", "Fish", "Vegetarian"]);
export const MealStyleSchema = z.enum([
  "Speedy",
  "Healthy comfort",
  "Family favorite",
  "Fakeaway",
  "Meat-free",
  "Protein-packed",
  "Treat night",
]);
export const AisleSchema = z.enum(["Produce", "Meat & fish", "Chilled & dairy", "Pantry"]);

export const CatalogueIngredientSchema = z
  .object({
    id: z.string().regex(/^[a-z0-9-]+$/),
    canonicalName: z.string().min(1).max(120),
    displayName: z.string().min(1).max(120),
    aisle: AisleSchema,
    displayQuantity: z.string().min(1).max(80),
    estimatedCostMinorUnits: z.number().int().nonnegative(),
  })
  .strict();

export const CatalogueRecipeSchema = z
  .object({
    id: z.string().regex(/^[a-z0-9-]+$/),
    version: z.number().int().positive(),
    title: z.string().min(1).max(160),
    source: z
      .object({
        name: z.string().min(1).max(120),
        url: z.string().url().nullable(),
        attribution: z.string().min(1).max(500),
        rightsStatus: z.enum(["development-fixture-unverified", "production-cleared"]),
        clearance: z.enum(["development-only", "production-cleared"]),
      })
      .strict(),
    image: z
      .object({
        kind: z.enum(["native-placeholder", "rights-cleared-local"]),
        identifier: z.string().min(1).max(80),
        rightsStatus: z.enum(["weeknight-owned-placeholder", "production-cleared"]),
      })
      .strict(),
    activeMinutes: z.number().int().min(1).max(360),
    defaultServings: z.number().int().min(1).max(20),
    estimatedCost: z
      .object({
        minorUnits: z.number().int().nonnegative(),
        currency: z.string().regex(/^[A-Z]{3}$/),
        source: z.string().min(1).max(120),
        freshnessDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
        confidence: z.enum(["low", "medium", "high"]),
      })
      .strict(),
    tags: z.array(z.string().min(1).max(80)).max(12),
    rationale: z.string().min(1).max(500),
    ingredients: z.array(CatalogueIngredientSchema).min(1).max(80),
    cookingSteps: z.array(z.string().min(1).max(1_000)).min(1).max(40),
    allergens: z.array(AllergenSchema).max(20),
    dietaryClassifications: z.array(DietarySchema).max(20),
    requiredAppliances: z.array(ApplianceSchema).max(20),
    protein: ProteinSchema,
    mealStyles: z.array(MealStyleSchema).max(20),
    ranking: z
      .object({
        basePriority: z.number().int().min(-100).max(100),
        varietyGroup: z.string().min(1).max(80),
      })
      .strict(),
  })
  .strict()
  .superRefine((recipe, context) => {
    const ingredientTotal = recipe.ingredients.reduce(
      (sum, ingredient) => sum + ingredient.estimatedCostMinorUnits,
      0,
    );
    if (ingredientTotal !== recipe.estimatedCost.minorUnits) {
      context.addIssue({
        code: "custom",
        path: ["estimatedCost", "minorUnits"],
        message: "Recipe cost must equal canonical ingredient costs",
      });
    }
    if (
      recipe.source.clearance === "development-only" &&
      recipe.source.rightsStatus === "production-cleared"
    ) {
      context.addIssue({ code: "custom", path: ["source"], message: "Development content is not production-cleared" });
    }
    const ingredientIDs = recipe.ingredients.map((ingredient) => ingredient.id);
    if (new Set(ingredientIDs).size !== ingredientIDs.length) {
      context.addIssue({ code: "custom", path: ["ingredients"], message: "Ingredient IDs must be unique per recipe" });
    }
  });

export const CatalogueSchema = z
  .object({
    schemaVersion: z.literal(1),
    catalogueVersion: z.string().regex(/^dev-\d{4}-\d{2}-\d{2}\.\d+$/),
    environment: z.literal("development"),
    recipes: z.array(CatalogueRecipeSchema).min(1).max(500),
  })
  .strict()
  .superRefine((catalogue, context) => {
    const IDs = catalogue.recipes.map((recipe) => recipe.id);
    if (new Set(IDs).size !== IDs.length) {
      context.addIssue({ code: "custom", path: ["recipes"], message: "Recipe IDs must be globally unique" });
    }
  });

export type Catalogue = z.infer<typeof CatalogueSchema>;
export type CatalogueRecipe = z.infer<typeof CatalogueRecipeSchema>;
