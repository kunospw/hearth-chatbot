import { CharacterDetail } from "@/components/characters/character-detail";

export default async function CharacterDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <CharacterDetail characterId={id} />;
}
