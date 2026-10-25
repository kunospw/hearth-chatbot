import type { BackendApi } from "@/lib/backend/api";
import type { ProfileRow } from "@/lib/backend/database.types";
import { BackendError } from "@/lib/backend/errors";
import { profileFromRow } from "@/lib/backend/mappers";
import type { Profile } from "@/lib/domain/types";

// RLS scopes `profiles` to the signed-in user, so no explicit filter is needed
// to read; writes still target the user's own row by id.

async function uid(api: BackendApi): Promise<string> {
  const id = await api.currentUserId();
  if (!id) throw new BackendError(401, "unauthorized", "Sign in first.");
  return id;
}

export async function getProfile(api: BackendApi): Promise<Profile | null> {
  const rows = await api.select<ProfileRow>("profiles", { limit: 1 });
  const row = rows[0];
  return row ? profileFromRow(row) : null;
}

export async function setAdultContent(api: BackendApi, enabled: boolean): Promise<void> {
  await api.update("profiles", { adult_content: enabled }, { id: await uid(api) });
}

export async function setDisplayName(api: BackendApi, name: string): Promise<void> {
  await api.update("profiles", { display_name: name }, { id: await uid(api) });
}
