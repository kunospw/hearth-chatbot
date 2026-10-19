-- Ollama answered 402 for deepseek-v4.1-flash: "this model is not included in your
-- free usage" and suggested gemma4:31b-cloud. Ember now uses that; Lumen and Atlas
-- use the gpt-oss models, which are the other widely free ones. If one of them
-- also says 402, the app shows Ollama's message: change the name here (or
-- upgrade at https://ollama.com/upgrade to use the DeepSeek / Kimi ones).
update public.models set ollama_model = 'gemma4:31b-cloud' where id = 'ember';
update public.models set ollama_model = 'gpt-oss:20b' where id = 'lumen';
update public.models set ollama_model = 'gpt-oss:120b' where id = 'atlas';
