import { Overline } from "@/components/ui/overline";

export default function ChatsPage() {
  return (
    <div className="flex flex-col gap-4">
      <Overline>Chats</Overline>
      <h1 className="t-display">Your chats</h1>
      <p className="t-body text-muted">
        Conversations you start will appear here. The chats list and the
        chat/story screen are the next screens to land.
      </p>
    </div>
  );
}
