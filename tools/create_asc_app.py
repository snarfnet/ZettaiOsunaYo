import os
import time

import jwt
import requests


KEY_ID = os.environ.get("ASC_KEY_ID", "WDXGY9WX55")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "2be0734f-943a-4d61-9dc9-5d9045c46fec")
P8_PATH = os.environ.get("ASC_P8_PATH", "/tmp/asc_key.p8")
BUNDLE_ID = os.environ.get("APP_BUNDLE_ID", "com.tokyonasu.zettaiosunayo")
APP_NAME = os.environ.get("APP_NAME", "絶対押すなよ")
APP_SKU = os.environ.get("APP_SKU", "zettaiosunayo")
BASE_URL = "https://api.appstoreconnect.apple.com/v1"


with open(P8_PATH, encoding="utf-8") as file:
    p8 = file.read()


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        p8,
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )


def headers():
    return {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}


def api_json(method, path, **kwargs):
    response = requests.request(method, f"{BASE_URL}{path}", headers=headers(), timeout=120, **kwargs)
    try:
        body = response.json()
    except Exception:
        body = {}
    return response, body


def main():
    response, body = api_json("GET", f"/apps?filter[bundleId]={BUNDLE_ID}&limit=1")
    if response.status_code != 200:
        raise RuntimeError(f"App lookup failed {response.status_code}: {response.text[:500]}")

    if body.get("data"):
        app = body["data"][0]
        print(f"App already exists: {app['attributes'].get('name')} ({app['id']})")
        return

    payload = {
        "data": {
            "type": "apps",
            "attributes": {
                "bundleId": BUNDLE_ID,
                "name": APP_NAME,
                "primaryLocale": "ja",
                "sku": APP_SKU,
            },
        }
    }
    response, body = api_json("POST", "/apps", json=payload)
    if response.status_code not in (200, 201):
        raise RuntimeError(f"App create failed {response.status_code}: {response.text[:800]}")

    app = body["data"]
    print(f"App created: {app['attributes'].get('name')} ({app['id']})")


if __name__ == "__main__":
    main()
