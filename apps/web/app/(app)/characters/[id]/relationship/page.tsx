import { RelationshipJournal } from "@/components/relationship/relationship-journal";

export default async function RelationshipPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <RelationshipJournal characterId={id} />;
}
