import argparse
from pathlib import Path


PROJECT = Path("project.yml")
TEST_APP_ID = "ca-app-pub-3940256099942544~1458002511"
TEST_BANNER_ID = "ca-app-pub-3940256099942544/2934735716"


def replace_value(text: str, key: str, value: str) -> str:
    lines = []
    replaced = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith(f"{key}:"):
            indent = line[: len(line) - len(line.lstrip())]
            lines.append(f'{indent}{key}: "{value}"')
            replaced = True
        else:
            lines.append(line)
    if not replaced:
        raise RuntimeError(f"{key} was not found in project.yml")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Set AdMob IDs in project.yml before xcodegen.")
    parser.add_argument("--app-id", default=TEST_APP_ID)
    parser.add_argument("--banner-id", default=TEST_BANNER_ID)
    args = parser.parse_args()

    text = PROJECT.read_text(encoding="utf-8")
    text = replace_value(text, "GADApplicationIdentifier", args.app_id)
    text = replace_value(text, "ZETTAI_BOTTOM_BANNER_AD_UNIT_ID", args.banner_id)
    PROJECT.write_text(text, encoding="utf-8")
    print("AdMob IDs configured.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
