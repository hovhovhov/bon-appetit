import type { Catalogue, CatalogueRecipe } from "../contracts/catalogue.js";
import type {
  AIRecommendationOutput,
  AIWeekPlanOutput,
  RecommendationRequest,
  WeekPlanRequest,
} from "../contracts/personalization.js";

export class PersonalizationValidationError extends Error {
  constructor(readonly reason: string) {
    super(reason);
    this.name = "PersonalizationValidationError";
  }
}

export function eligibleCandidates(
  catalogue: Catalogue,
  eligibleRecipeIDs: string[],
  scheduledRecipeIDs: string[],
  maxCandidates: number,
): CatalogueRecipe[] {
  const allowed = new Set(eligibleRecipeIDs);
  const scheduled = new Set(scheduledRecipeIDs);
  return catalogue.recipes
    .filter((recipe) => allowed.has(recipe.id) && !scheduled.has(recipe.id))
    .slice(0, maxCandidates);
}

function scaledCost(recipe: CatalogueRecipe, householdSize: number): number {
  return Math.floor((recipe.estimatedCost.minorUnits * householdSize + recipe.defaultServings / 2) / recipe.defaultServings);
}

function deterministicScore(
  recipe: CatalogueRecipe,
  request: RecommendationRequest | WeekPlanRequest,
): number {
  let score = recipe.ranking.basePriority;
  const preferences = request.preferences;
  if (recipe.activeMinutes <= preferences.maximumCookingMinutes) score += 20;
  else score -= 30;
  if (preferences.preferredProteins.includes(recipe.protein)) score += 16;
  if (recipe.mealStyles.some((style) => preferences.preferredMealStyles.includes(style))) score += 12;
  if (recipe.ingredients.some((entry) => preferences.dislikedIngredientIDs.includes(entry.id))) score -= 24;
  if (preferences.savedRecipeIDs.includes(recipe.id)) score += 5;
  return score;
}

export function deterministicRecommendations(
  candidates: CatalogueRecipe[],
  request: RecommendationRequest,
): AIRecommendationOutput {
  return {
    recommendations: candidates
      .map((recipe, originalIndex) => ({ recipe, originalIndex, score: deterministicScore(recipe, request) }))
      .sort((left, right) => right.score - left.score || left.originalIndex - right.originalIndex || left.recipe.id.localeCompare(right.recipe.id))
      .map(({ recipe }) => ({
        recipeID: recipe.id,
        explanation: deterministicExplanation(recipe, request),
        softFitSignals: recipe.mealStyles.filter((style) => request.preferences.preferredMealStyles.includes(style)).slice(0, 2),
      })),
  };
}

function deterministicExplanation(
  recipe: CatalogueRecipe,
  request: RecommendationRequest | WeekPlanRequest,
): string {
  if (request.preferences.preferredProteins.includes(recipe.protein)) {
    return `Backend match for your ${recipe.protein.toLowerCase()} preference.`;
  }
  const style = recipe.mealStyles.find((entry) => request.preferences.preferredMealStyles.includes(entry));
  if (style) return `Backend match for your ${style.toLowerCase()} meal style.`;
  if (recipe.activeMinutes <= request.preferences.maximumCookingMinutes) {
    return `Backend pick within your ${request.preferences.maximumCookingMinutes}-minute preference.`;
  }
  return "Backend pick from recipes already approved by Weeknight’s hard rules.";
}

export function deterministicWeekPlan(
  candidates: CatalogueRecipe[],
  request: WeekPlanRequest,
): AIWeekPlanOutput | null {
  const ranked = candidates
    .map((recipe, originalIndex) => ({ recipe, originalIndex, score: deterministicScore(recipe, request) }))
    .sort((left, right) => right.score - left.score || left.originalIndex - right.originalIndex);
  const chosen: CatalogueRecipe[] = [];
  let spend = request.currentSpendMinorUnits;
  for (const candidate of ranked) {
    const cost = scaledCost(candidate.recipe, request.householdSize);
    if (spend + cost <= request.budgetMinorUnits) {
      chosen.push(candidate.recipe);
      spend += cost;
      if (chosen.length === request.openDays.length) break;
    }
  }
  if (chosen.length !== request.openDays.length) return null;
  return {
    assignments: request.openDays.map((day, index) => ({
      day,
      recipeID: chosen[index]!.id,
      explanation: deterministicExplanation(chosen[index]!, request),
    })),
  };
}

export function validateRecommendationOutput(
  output: AIRecommendationOutput,
  candidates: CatalogueRecipe[],
): AIRecommendationOutput {
  const allowed = new Set(candidates.map((recipe) => recipe.id));
  const IDs = output.recommendations.map((entry) => entry.recipeID);
  if (new Set(IDs).size !== IDs.length) throw new PersonalizationValidationError("duplicate-recipe-id");
  if (IDs.some((id) => !allowed.has(id))) throw new PersonalizationValidationError("unknown-or-ineligible-recipe-id");
  return output;
}

export function validateWeekPlanOutput(
  output: AIWeekPlanOutput,
  candidates: CatalogueRecipe[],
  request: WeekPlanRequest,
): AIWeekPlanOutput {
  const allowed = new Map(candidates.map((recipe) => [recipe.id, recipe]));
  const IDs = output.assignments.map((entry) => entry.recipeID);
  const days = output.assignments.map((entry) => entry.day);
  if (new Set(IDs).size !== IDs.length) throw new PersonalizationValidationError("duplicate-recipe-id");
  if (new Set(days).size !== days.length) throw new PersonalizationValidationError("duplicate-day");
  if (output.assignments.length !== request.openDays.length || request.openDays.some((day) => !days.includes(day))) {
    throw new PersonalizationValidationError("missing-required-day");
  }
  if (IDs.some((id) => !allowed.has(id))) throw new PersonalizationValidationError("unknown-or-ineligible-recipe-id");
  const addedSpend = IDs.reduce((sum, id) => sum + scaledCost(allowed.get(id)!, request.householdSize), 0);
  if (request.currentSpendMinorUnits + addedSpend > request.budgetMinorUnits) {
    throw new PersonalizationValidationError("over-budget");
  }
  return output;
}
