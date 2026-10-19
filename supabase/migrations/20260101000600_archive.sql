-- Archive: hide a character or a chat without deleting it.
alter table public.characters add column archived boolean not null default false;
alter table public.conversations add column archived boolean not null default false;
