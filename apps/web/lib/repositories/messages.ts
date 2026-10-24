import type { BackendApi } from "@/lib/backend/api";
import type { MessageRow } from "@/lib/backend/database.types";
import { BackendError } from "@/lib/backend/errors";
import { messageFromRow, messageToRow } from "@/lib/backend/mappers";
import type { Message } from "@/lib/domain/types";

async function uid(api: BackendApi): Promise<string> {
  const id = await api.currentUserId();
  if (!id) throw new BackendError(401, "unauthorized", "Sign in first.");
  return id;
}

export async function listMessages(
  api: BackendApi,
  conversationId: string,
): Promise<Message[]> {
  const rows = await api.select<MessageRow>("messages", {
    eq: { conversation_id: conversationId },
    orderBy: "seq",
    ascending: true,
  });
  return rows.map(messageFromRow);
}

export async function saveMessage(
  api: BackendApi,
  message: Message,
  conversationId: string,
): Promise<void> {
  await api.upsert("messages", messageToRow(message, conversationId, await uid(api)));
}

/** Saves several messages in order (used when flushing before a turn). */
export async function saveMessages(
  api: BackendApi,
  messages: Message[],
  conversationId: string,
): Promise<void> {
  if (messages.length === 0) return;
  const id = await uid(api);
  await api.upsert(
    "messages",
    messages.map((m) => messageToRow(m, conversationId, id)),
  );
}

export async function deleteMessage(api: BackendApi, id: string): Promise<void> {
  await api.delete("messages", { id });
}
