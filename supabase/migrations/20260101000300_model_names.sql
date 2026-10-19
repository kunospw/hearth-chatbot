-- Real Ollama Cloud models (checked against https://ollama.com/api/tags on 2026-10-17).
-- Ollama renames and retires cloud models: edit `ollama_model` here or in the
-- dashboard whenever one disappears. The app only ever sees the friendly names.
update public.models set ollama_model = 'deepseek-v4.1-flash', busy = false where id = 'ember';
update public.models set ollama_model = 'deepseek-v4-pro:0813', busy = false where id = 'lumen';
update public.models set ollama_model = 'kimi-k3', busy = false where id = 'atlas';
