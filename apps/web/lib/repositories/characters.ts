import type { BackendApi } from "@/lib/backend/api";
import type { CharacterRow } from "@/lib/backend/database.types";
import { BackendError } from "@/lib/backend/errors";
import { characterFromRow, characterToRow } from "@/lib/backend/mappers";
import type { Character } from "@/lib/domain/types";

async function uid(api: BackendApi): Promise<string> {
  const id = await api.currentUserId();
  if (!id) throw new BackendError(401, "unauthorized", "Sign in first.");
  return id;
}

export async function listCharacters(api: BackendApi): Promise<Character[]> {
  const rows = await api.select<CharacterRow>("characters", {
    orderBy: "updated_at",
    ascending: false,
  });
  return rows.map(characterFromRow);
}

export async function saveCharacter(
  api: BackendApi,
  character: Character,
  portraitUrl?: string | null,
): Promise<void> {
  await api.upsert("characters", characterToRow(character, await uid(api), portraitUrl));
}

export async function setCharacterArchived(
  api: BackendApi,
  id: string,
  archived: boolean,
): Promise<void> {
  await api.update("characters", { archived }, { id });
}

/** Deletes the character; conversations and messages cascade in the database. */
export async function deleteCharacter(api: BackendApi, id: string): Promise<void> {
  await api.delete("characters", { id });
}
