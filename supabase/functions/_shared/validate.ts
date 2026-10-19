// Strict input checking. Everything from the app is untrusted.

export class BadRequestError extends Error {
  readonly code: string;
  constructor(code: string, message?: string) {
    super(message ?? code);
    this.name = 'BadRequestError';
    this.code = code;
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type Obj = Record<string, unknown>;

export function obj(v: unknown, what = 'body'): Obj {
  if (v === null || typeof v !== 'object' || Array.isArray(v)) throw new BadRequestError('bad_request', `${what} must be an object`);
  return v as Obj;
}

export function uuid(v: unknown, field: string): string {
  if (typeof v !== 'string' || !UUID.test(v)) throw new BadRequestError('bad_request', `${field} must be a uuid`);
  return v.toLowerCase();
}

export function optUuid(v: unknown, field: string): string | undefined {
  return v === undefined || v === null ? undefined : uuid(v, field);
}

export function oneOf<T extends string>(v: unknown, allowed: readonly T[], field: string): T {
  if (typeof v !== 'string' || !(allowed as readonly string[]).includes(v)) {
    throw new BadRequestError('bad_request', `${field} must be one of ${allowed.join(', ')}`);
  }
  return v as T;
}

export function text(v: unknown, field: string, max: number, o: { min?: number; trim?: boolean } = {}): string {
  if (typeof v !== 'string') throw new BadRequestError('bad_request', `${field} must be text`);
  const t = o.trim === false ? v : v.trim();
  if (t.length < (o.min ?? 0)) throw new BadRequestError('bad_request', `${field} is too short`);
  if (t.length > max) throw new BadRequestError('bad_request', `${field} is too long`);
  return t;
}

export function optText(v: unknown, field: string, max: number): string | undefined {
  return v === undefined || v === null ? undefined : text(v, field, max, { trim: false });
}

export function int(v: unknown, field: string, min: number, max: number): number {
  if (typeof v !== 'number' || !Number.isInteger(v) || v < min || v > max) {
    throw new BadRequestError('bad_request', `${field} must be a whole number from ${min} to ${max}`);
  }
  return v;
}

export function bool(v: unknown, field: string): boolean {
  if (typeof v !== 'boolean') throw new BadRequestError('bad_request', `${field} must be true or false`);
  return v;
}

/** A finite number clamped into [min, max] (settings are forgiving, not fatal). */
export function clampNumber(v: unknown, min: number, max: number, fallback: number): number {
  if (typeof v !== 'number' || !Number.isFinite(v)) return fallback;
  return Math.min(max, Math.max(min, v));
}
