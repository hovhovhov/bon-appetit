import { CatalogueSchema, type Catalogue } from "../contracts/catalogue.js";
import { AppError } from "../errors.js";

export interface RecipeCatalogueRepository {
  load(): Promise<Catalogue>;
}

export class ValidatedFixtureCatalogueRepository implements RecipeCatalogueRepository {
  constructor(private readonly input: unknown) {}

  async load(): Promise<Catalogue> {
    const parsed = CatalogueSchema.safeParse(this.input);
    if (!parsed.success) {
      throw new AppError(500, "CATALOGUE_INVALID", "The development catalogue failed validation");
    }
    return parsed.data;
  }
}
