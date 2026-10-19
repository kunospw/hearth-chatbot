-- Which persona you play as in a chat (remembered per chat, so a chat you
-- switched to another persona keeps it on every device).
alter table public.conversations
  add column persona_id uuid references public.personas on delete set null;

-- You can only pick a persona of your own.
drop policy conversations_own on public.conversations;
create policy conversations_own on public.conversations for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.characters c where c.id = character_id and c.user_id = auth.uid())
    and (persona_id is null or exists (
      select 1 from public.personas p where p.id = persona_id and p.user_id = auth.uid()))
  );
