// Runs an action at most once per interval, always delivering the latest call:
// the first call runs immediately, calls inside the window merge into one
// trailing run. Throttles streaming updates to ~60ms.
// Port of lib/core/util/throttler.dart.

export class Throttler {
  private timer: ReturnType<typeof setTimeout> | null = null;
  private pending: (() => void) | null = null;

  constructor(private readonly intervalMs: number) {}

  run(action: () => void): void {
    if (this.timer === null) {
      action();
      this.timer = setTimeout(() => this.tick(), this.intervalMs);
    } else {
      this.pending = action;
    }
  }

  private tick(): void {
    this.timer = null;
    const p = this.pending;
    this.pending = null;
    if (p) {
      p();
      this.timer = setTimeout(() => this.tick(), this.intervalMs);
    }
  }

  /** Runs any pending action now (e.g. when a stream finishes). */
  flush(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    const p = this.pending;
    this.pending = null;
    p?.();
  }

  cancel(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    this.pending = null;
  }
}
