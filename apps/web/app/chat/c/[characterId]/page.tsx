import { ChatScreen } from "@/components/chat/chat-screen";

export default async function ChatCharacterPage({
  params,
}: {
  params: Promise<{ characterId: string }>;
}) {
  const { characterId } = await params;
  return <ChatScreen characterId={characterId} />;
}
