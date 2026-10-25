import { CharacterEditor } from "@/components/characters/character-editor";

export default async function CharacterEditPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <CharacterEditor characterId={id} />;
}
