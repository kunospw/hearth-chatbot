// Load → run the engine → commit, retrying when someone else changed the
// relationship in between (optimistic locking on `version`).
import { diffRelationship, isEmptyPatch } from './engine/persist.ts';
import type { Relationship } from './engine/models.ts';
import { NotFoundError, VersionConflictError, type Store } from './store.ts';

export async function mutate<T>(
  store: Store,
  userId: string,
  relationshipId: string,
  fn: (r: Relationship) => { next: Relationship; result: T },
  attempts = 4,
): Promise<{ relationship: Relationship; result: T }> {
  for (let i = 0; i < attempts; i++) {
    const r = await store.loadRelationship(userId, relationshipId);
    if (r === null) throw new NotFoundError('relationship');
    const { next, result } = fn(r);
    const patch = diffRelationship(r, next);
    if (isEmptyPatch(patch)) return { relationship: r, result };
    try {
      return { relationship: await store.commit(userId, r, patch), result };
    } catch (e) {
      if (e instanceof VersionConflictError && i < attempts - 1) continue;
      throw e;
    }
  }
  throw new VersionConflictError();
}
