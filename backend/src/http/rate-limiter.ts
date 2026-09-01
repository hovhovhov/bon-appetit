import { AppError } from "../errors.js";

type Bucket = { windowStartedAt: number; count: number };

export class FixedWindowRateLimiter {
  private readonly buckets = new Map<string, Bucket>();

  constructor(
    private readonly limit: number,
    private readonly windowMs = 60_000,
    private readonly now: () => number = Date.now,
  ) {}

  check(key: string): void {
    const timestamp = this.now();
    const current = this.buckets.get(key);
    if (!current || timestamp - current.windowStartedAt >= this.windowMs) {
      this.buckets.set(key, { windowStartedAt: timestamp, count: 1 });
      return;
    }
    current.count += 1;
    if (current.count > this.limit) {
      throw new AppError(429, "RATE_LIMITED", "Local request limit reached", true);
    }
  }
}
