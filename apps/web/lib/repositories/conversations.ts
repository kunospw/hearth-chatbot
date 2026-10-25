import type { BackendApi } from "@/lib/backend/api";
import type { ConversationRow } from "@/lib/backend/database.types";
import { BackendError } from "@/lib/backend/errors";
import { conversationFromRow, conversationToRow } from "@/lib/backend/mappers";
import type { ChatMode, Conversation } from "@/lib/domain/types";
import { listMessages } from "./messages";

async function uid(api: BackendApi): Promise<string> {
  const id = await api.currentUserId();
  if (!id) throw new BackendError(401, "unauthorized", "Sign in first.");
  return id;
}

/** All conversations (newest first), without their messages loaded. */
export async function listConversations(api: BackendApi): Promise<Conversation[]> {
  const rows = await api.select<ConversationRow>("conversations", {
    orderBy: "updated_at",
    ascending: false,
  });
  return rows.map((r) => conversationFromRow(r, []));
}

/** One conversation with its messages loaded. */
export async function getConversation(
  api: BackendApi,
  id: string,
): Promise<Conversation | null> {
  const rows = await api.select<ConversationRow>("conversations", { eq: { id }, limit: 1 });
  const row = rows[0];
  if (!row) return null;
  const messages = await listMessages(api, id);
  return conversationFromRow(row, messages);
}

export async function createConversation(
  api: BackendApi,
  args: { characterId: string; mode?: ChatMode; personaId?: string | null; title?: string },
): Promise<Conversation> {
  const now = new Date().toISOString();
  const conversation: Conversation = {
    id: crypto.randomUUID(),
    characterId: args.characterId,
    title: args.title ?? "New chat",
    updatedAt: now,
    messages: [],
    pinned: false,
    mode: args.mode ?? "chat",
    archived: false,
    personaId: args.personaId ?? null,
  };
  await api.upsert("conversations", conversationToRow(conversation, await uid(api)));
  return conversation;
}

export async function setMode(api: BackendApi, id: string, mode: ChatMode): Promise<void> {
  await api.update("conversations", { mode }, { id });
}

export async function renameConversation(
  api: BackendApi,
  id: string,
  title: string,
): Promise<void> {
  await api.update("conversations", { title }, { id });
}

export async function setPinned(api: BackendApi, id: string, pinned: boolean): Promise<void> {
  await api.update("conversations", { pinned }, { id });
}

export async function setArchived(
  api: BackendApi,
  id: string,
  archived: boolean,
): Promise<void> {
  await api.update("conversations", { archived }, { id });
}

export async function setPersona(
  api: BackendApi,
  id: string,
  personaId: string | null,
): Promise<void> {
  await api.update("conversations", { persona_id: personaId }, { id });
}

/** Bumps updated_at so the conversation sorts to the top. */
export async function touchConversation(api: BackendApi, id: string): Promise<void> {
  await api.update("conversations", { updated_at: new Date().toISOString() }, { id });
}

/** Deletes the conversation; its messages cascade in the database. */
export async function deleteConversation(api: BackendApi, id: string): Promise<void> {
  await api.delete("conversations", { id });
}
