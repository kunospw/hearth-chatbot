import { ConversationChat } from "@/components/chat/conversation-chat";

export default async function ConversationPage({
  params,
}: {
  params: Promise<{ conversationId: string }>;
}) {
  const { conversationId } = await params;
  return <ConversationChat conversationId={conversationId} />;
}
