import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path


DEFAULT_MODEL = "gpt-4o-mini-tts"
DEFAULT_VOICE = "verse"


def post_tts(api_key: str, model: str, voice: str, text: str) -> bytes:
    payload = json.dumps(
        {
            "model": model,
            "voice": voice,
            "input": text,
            "response_format": "mp3",
        },
        ensure_ascii=False,
    ).encode("utf-8")

    request = urllib.request.Request(
        "https://api.openai.com/v1/audio/speech",
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate bundled mp3 voice files.")
    parser.add_argument("--lines", default="tools/tts_lines.json", help="Path to the line JSON file.")
    parser.add_argument("--out", default="ZettaiOsunaYo/Resources/Audio", help="Output audio folder.")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="OpenAI TTS model.")
    parser.add_argument("--voice", default=DEFAULT_VOICE, help="OpenAI TTS voice.")
    parser.add_argument("--overwrite", action="store_true", help="Regenerate files that already exist.")
    args = parser.parse_args()

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("OPENAI_API_KEY is not set.", file=sys.stderr)
        return 2

    lines_path = Path(args.lines)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    lines = json.loads(lines_path.read_text(encoding="utf-8"))
    for item in lines:
        target = out_dir / item["file"]
        if target.exists() and not args.overwrite:
            print(f"skip {target.name}")
            continue

        print(f"generate {target.name}")
        try:
            audio = post_tts(api_key, args.model, args.voice, item["text"])
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            print(f"OpenAI API error for {target.name}: {error.code} {body}", file=sys.stderr)
            return 1

        target.write_bytes(audio)

    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
