-- Lumen tries a Nemotron model (free on Ollama Cloud) to compare tone with Gemma.
update public.models set ollama_model = 'nemotron-3-super' where id = 'lumen';
