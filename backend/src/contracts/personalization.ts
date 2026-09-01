import { z } from "zod";
import { MealStyleSchema, ProteinSchema } from "./catalogue.js";

const RecipeIDSchema = z.string().regex(/^[a-z0-9-]+$/);
const DaySchema = z.enum(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]);

export const SoftPreferencesSchema = z
  .object({
    maximumCookingMinutes: z.number().int().min(1).max(360),
    dislikedIngredientIDs: z.array(RecipeIDSchema).max(100),
    preferredProteins: z.array(ProteinSchema).max(10),
    preferredMealStyles: z.array(MealStyleSchema).max(20),
    savedRecipeIDs: z.array(RecipeIDSchema).max(500),
  })
  .strict();

export const RecommendationRequestSchema = z
  .object({
    schemaVersion: z.literal(1),
    catalogueVersion: z.string().min(1).max(80),
    eligibleRecipeIDs: z.array(RecipeIDSchema).min(1).max(50),
    scheduledRecipeIDs: z.array(RecipeIDSchema).max(50),
    remainingBudgetMinorUnits: z.number().int(),
    currency: z.string().regex(/^[A-Z]{3}$/),
    householdSize: z.number().int().min(1).max(20),
    preferences: SoftPreferencesSchema,
  })
  .strict();

export const WeekPlanRequestSchema = z
  .object({
    schemaVersion: z.literal(1),
    catalogueVersion: z.string().min(1).max(80),
    eligibleRecipeIDs: z.array(RecipeIDSchema).min(1).max(50),
    scheduledRecipeIDs: z.array(RecipeIDSchema).max(50),
    openDays: z.array(DaySchema).min(1).max(7),
    currentSpendMinorUnits: z.number().int().nonnegative(),
    budgetMinorUnits: z.number().int().nonnegative(),
    currency: z.string().regex(/^[A-Z]{3}$/),
    householdSize: z.number().int().min(1).max(20),
    preferences: SoftPreferencesSchema,
  })
  .strict()
  .superRefine((request, context) => {
    if (new Set(request.openDays).size !== request.openDays.length) {
      context.addIssue({ code: "custom", path: ["openDays"], message: "Open days must be unique" });
    }
  });

export const AIRecommendationOutputSchema = z
  .object({
    recommendations: z
      .array(
        z
          .object({
            recipeID: RecipeIDSchema,
            explanation: z.string().min(1).max(180),
            softFitSignals: z.array(z.string().min(1).max(80)).max(4),
          })
          .strict(),
      )
      .min(1)
      .max(50),
  })
  .strict();

export const AIWeekPlanOutputSchema = z
  .object({
    assignments: z
      .array(
        z
          .object({
            day: DaySchema,
            recipeID: RecipeIDSchema,
            explanation: z.string().min(1).max(180),
          })
          .strict(),
      )
      .min(1)
      .max(7),
  })
  .strict();

export type RecommendationRequest = z.infer<typeof RecommendationRequestSchema>;
export type WeekPlanRequest = z.infer<typeof WeekPlanRequestSchema>;
export type AIRecommendationOutput = z.infer<typeof AIRecommendationOutputSchema>;
export type AIWeekPlanOutput = z.infer<typeof AIWeekPlanOutputSchema>;

export const recommendationJSONSchema = {
  type: "object",
  additionalProperties: false,
  required: ["recommendations"],
  properties: {
    recommendations: {
      type: "array",
      minItems: 1,
      maxItems: 50,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["recipeID", "explanation", "softFitSignals"],
        properties: {
          recipeID: { type: "string" },
          explanation: { type: "string", maxLength: 180 },
          softFitSignals: { type: "array", maxItems: 4, items: { type: "string", maxLength: 80 } },
        },
      },
    },
  },
} as const;

export const weekPlanJSONSchema = {
  type: "object",
  additionalProperties: false,
  required: ["assignments"],
  properties: {
    assignments: {
      type: "array",
      minItems: 1,
      maxItems: 7,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["day", "recipeID", "explanation"],
        properties: {
          day: { type: "string", enum: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"] },
          recipeID: { type: "string" },
          explanation: { type: "string", maxLength: 180 },
        },
      },
    },
  },
} as const;
