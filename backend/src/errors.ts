export type ErrorCode =
  | "BAD_REQUEST"
  | "RATE_LIMITED"
  | "CATALOGUE_INVALID"
  | "NOT_FOUND"
  | "INTERNAL_ERROR";

export class AppError extends Error {
  constructor(
    readonly statusCode: number,
    readonly code: ErrorCode,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
    this.name = "AppError";
  }
}

const sensitiveKey = /(authorization|api[-_]?key|secret|medical|allergen|(^|[-_])token$|accessToken$|refreshToken$)/i;

export function redact(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(redact);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, nested]) => [
        key,
        sensitiveKey.test(key) ? "[REDACTED]" : redact(nested),
      ]),
    );
  }
  return value;
}
