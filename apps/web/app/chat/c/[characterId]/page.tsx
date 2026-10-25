import { NewChat } from "@/components/chat/new-chat";

export default async function NewChatPage({
  params,
}: {
  params: Promise<{ characterId: string }>;
}) {
  const { characterId } = await params;
  return <NewChat characterId={characterId} />;
}
