# TTS generation

Set `OPENAI_API_KEY`, then run:

```powershell
python tools/generate_tts.py
```

The script creates mp3 files in:

```text
ZettaiOsunaYo/Resources/Audio
```

It uses OpenAI TTS during development only. The iOS app itself does not call any API.

For local placeholder audio without an API key on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File tools/generate_local_sapi.ps1
```
