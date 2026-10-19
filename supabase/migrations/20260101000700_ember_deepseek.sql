-- Ember tries DeepSeek (needs Ollama usage credits; the 402 "not included in your free
-- usage" error means the credits ran out or are not set up). Lumen and Atlas unchanged.
update public.models set ollama_model = 'deepseek-v4.1-flash' where id = 'ember';
