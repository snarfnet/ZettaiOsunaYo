import hashlib
import os
import time
from pathlib import Path

import jwt
import requests
from requests import RequestException


KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
APP_ID = os.environ.get("APP_ID", "6769247677")
APP_VERSION = os.environ.get("APP_VERSION", "1.0")
BUILD_NUMBER = os.environ.get("BUILD_NUMBER")
P8_PATH = os.environ.get("ASC_P8_PATH", "/tmp/asc_key.p8")
SCREENSHOT_DIR = Path("MarketingAssets/Screenshots")

SCREENSHOT_GROUPS = [
    ("APP_IPHONE_67", "iphone_69"),
    ("APP_IPHONE_65", "iphone_65"),
    ("APP_IPHONE_55", "iphone_55"),
    ("APP_IPAD_PRO_3GEN_129", "ipad_129"),
]

META = {
    "ja": {
        "description": """押すなと言われるほど、押したくなる。

「絶対押すなよ」は、巨大な赤いボタンを前に、ただ押さずに耐えるだけの緊張系ミニアプリです。

起動した瞬間からタイマーが始まり、ランダムな煽り音声があなたの指先を試します。時間が経つほど音声の頻度は上がり、赤いボタンの存在感もじわじわ増していきます。

押さずにアプリを閉じれば、耐え抜いた時間を表示。押してしまったら失敗画面へ移動し、説教音声がずっと続きます。

ちょっとした待ち時間、友だちとのネタ、謎の自制心チェックにどうぞ。""",
        "keywords": "押すな,赤いボタン,ミニゲーム,暇つぶし,耐久,音声,ネタ,ドッキリ,反射神経,自制心",
        "whatsNew": "初回リリースです。",
        "promotionalText": "押すな。絶対に押すな。あなたは何分耐えられる？",
        "marketingUrl": "https://snarfnet.github.io/",
        "supportUrl": "https://snarfnet.github.io/",
    },
    "en-US": {
        "description": """The more you are told not to press it, the more tempting it gets.

Don't Press It is a tense little mini app where you face one giant red button and try to resist.

The timer starts as soon as the app opens. Random voice lines tease you while the pressure rises over time. If you leave without pressing, the app shows how long you endured. If you press the button, you fail and the lecture voice keeps going.

Use it for quick laughs, waiting time, or a tiny test of self-control.""",
        "keywords": "button,red button,mini game,prank,voice,timer,patience,self control,casual",
        "whatsNew": "Initial release.",
        "promotionalText": "Do not press it. Seriously. How long can you last?",
        "marketingUrl": "https://snarfnet.github.io/",
        "supportUrl": "https://snarfnet.github.io/",
    },
}

META["ja"] = {
    "description": """押すなと言われるほど、押したくなる。

「絶対押すなよ」は、大きな赤いボタンを前にして、ただ押さずに耐えるミニアプリです。

アプリを開くとタイマーが動き出します。ランダムな音声があなたをあおり、時間が経つほど緊張感が上がります。押さずに閉じれば耐えた時間を表示。押してしまうと失敗画面へ進み、説教ボイスが流れます。

ちょっとした待ち時間、友だちとのネタ、自制心チェックにどうぞ。""",
    "keywords": "押すな,赤いボタン,ミニゲーム,暇つぶし,音声,タイマー,我慢,ネタ,自制心",
    "whatsNew": "初回リリースです。",
    "promotionalText": "押すな。絶対に押すな。あなたは何秒耐えられる？",
    "marketingUrl": "https://snarfnet.github.io/",
    "supportUrl": "https://snarfnet.github.io/",
}

p8 = open(P8_PATH, encoding="utf-8").read()


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        p8,
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )


def headers():
    return {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}


def api(method, path, **kwargs):
    for _ in range(6):
        response = requests.request(
            method,
            f"https://api.appstoreconnect.apple.com/v1{path}",
            headers=headers(),
            timeout=120,
            **kwargs,
        )
        if response.status_code not in (401, 429, 500, 502, 503, 504):
            return response
        time.sleep(20)
    return response


def api_json(method, path, **kwargs):
    response = api(method, path, **kwargs)
    try:
        body = response.json()
    except Exception:
        body = {}
    return response, body


def list_all(path):
    rows = []
    next_path = path
    while next_path:
        response, body = api_json("GET", next_path)
        if response.status_code != 200:
            raise RuntimeError(f"List failed {response.status_code}: {response.text[:500]}")
        rows.extend(body.get("data", []))
        next_url = body.get("links", {}).get("next")
        next_path = next_url.split("/v1", 1)[1] if next_url else None
    return rows


def find_or_create_version():
    versions = list_all(f"/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200")
    for version in versions:
        attrs = version.get("attributes", {})
        if attrs.get("versionString") == APP_VERSION:
            print(f"Found version {APP_VERSION}: {version['id']} state={attrs.get('appStoreState')}")
            return version["id"], attrs.get("appStoreState")

    response, body = api_json("POST", "/appStoreVersions", json={
        "data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": APP_VERSION},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    })
    if response.status_code not in (200, 201):
        raise RuntimeError(f"Version create failed {response.status_code}: {response.text[:500]}")
    return body["data"]["id"], "PREPARE_FOR_SUBMISSION"


def ensure_release_prerequisites(version_id):
    response = api("PATCH", f"/apps/{APP_ID}", json={
        "data": {
            "type": "apps",
            "id": APP_ID,
            "attributes": {
                "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT",
            },
        }
    })
    print(f"Content rights: {response.status_code}")

    response, body = api_json("GET", f"/apps/{APP_ID}/appInfos?limit=10")
    app_infos = body.get("data", []) if response.status_code == 200 else []
    if app_infos:
        app_info_id = app_infos[0]["id"]
        set_category(app_info_id)
        update_age_rating(app_info_id)
        update_app_info_localizations(app_info_id)

    response = api("PATCH", f"/appStoreVersions/{version_id}", json={
        "data": {
            "type": "appStoreVersions",
            "id": version_id,
            "attributes": {
                "copyright": "2026 Tokyo Nasu",
                "usesIdfa": True,
                "releaseType": "AFTER_APPROVAL",
            },
        }
    })
    print(f"Version settings: {response.status_code}")
    ensure_free_price()
    ensure_review_detail(version_id)


def set_category(app_info_id):
    response = api("PATCH", f"/appInfos/{app_info_id}", json={
        "data": {
            "type": "appInfos",
            "id": app_info_id,
            "relationships": {
                "primaryCategory": {"data": {"type": "appCategories", "id": "GAMES"}},
            },
        }
    })
    print(f"Category: {response.status_code}")


def update_age_rating(app_info_id):
    attrs = {
        "alcoholTobaccoOrDrugUseOrReferences": "NONE",
        "contests": "NONE",
        "gamblingSimulated": "NONE",
        "gunsOrOtherWeapons": "NONE",
        "medicalOrTreatmentInformation": "NONE",
        "profanityOrCrudeHumor": "INFREQUENT_OR_MILD",
        "sexualContentGraphicAndNudity": "NONE",
        "sexualContentOrNudity": "NONE",
        "horrorOrFearThemes": "INFREQUENT_OR_MILD",
        "matureOrSuggestiveThemes": "NONE",
        "violenceCartoonOrFantasy": "NONE",
        "violenceRealisticProlongedGraphicOrSadistic": "NONE",
        "violenceRealistic": "NONE",
        "messagingAndChat": False,
        "gambling": False,
        "parentalControls": False,
        "ageAssurance": False,
        "userGeneratedContent": False,
        "healthOrWellnessTopics": False,
        "unrestrictedWebAccess": False,
        "lootBox": False,
        "advertising": True,
    }
    response = api("PATCH", f"/ageRatingDeclarations/{app_info_id}", json={
        "data": {"type": "ageRatingDeclarations", "id": app_info_id, "attributes": attrs}
    })
    print(f"Age rating: {response.status_code}")


def update_app_info_localizations(app_info_id):
    response, body = api_json("GET", f"/appInfos/{app_info_id}/appInfoLocalizations?limit=20")
    if response.status_code != 200:
        return
    for loc in body.get("data", []):
        locale = loc["attributes"].get("locale")
        attrs = {
            "privacyPolicyUrl": "https://snarfnet.github.io/privacy.html",
            "subtitle": "押してはいけない赤いボタン" if locale == "ja" else "A forbidden red button",
        }
        response = api("PATCH", f"/appInfoLocalizations/{loc['id']}", json={
            "data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": attrs}
        })
        print(f"App info {locale}: {response.status_code}")


def ensure_free_price():
    response, body = api_json("GET", f"/apps/{APP_ID}/appPricePoints?filter[territory]=USA&limit=1")
    points = body.get("data", []) if response.status_code == 200 else []
    if not points:
        print("Free price: no USA price point found")
        return

    local_id = "${manualPrice0}"
    payload = {
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": APP_ID}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "appPrices", "id": local_id}]},
            },
        },
        "included": [
            {
                "type": "appPrices",
                "id": local_id,
                "attributes": {"startDate": "2026-05-13"},
                "relationships": {
                    "appPricePoint": {"data": {"type": "appPricePoints", "id": points[0]["id"]}}
                },
            }
        ],
    }
    response = api("POST", "/appPriceSchedules", json=payload)
    print(f"Free price: {response.status_code}")


def ensure_review_detail(version_id):
    attrs = {
        "contactFirstName": "Tokyo",
        "contactLastName": "Nasu",
        "contactPhone": "+1 844 209 0611",
        "contactEmail": "support@snarfnet.github.io",
        "demoAccountRequired": False,
        "notes": (
            "No login is required. The app does not call any external API. "
            "Bundled mp3 audio is played with AVAudioPlayer. "
            "This build requests App Tracking Transparency permission shortly after first launch. "
            "Google Mobile Ads SDK is started only after the ATT flow completes or if the user has already made a tracking choice."
        ),
    }
    response, body = api_json("GET", f"/appStoreVersions/{version_id}/appStoreReviewDetail")
    if response.status_code == 200 and body.get("data"):
        detail_id = body["data"]["id"]
        response = api("PATCH", f"/appStoreReviewDetails/{detail_id}", json={
            "data": {"type": "appStoreReviewDetails", "id": detail_id, "attributes": attrs}
        })
        print(f"Review detail updated: {response.status_code}")
        return

    response = api("POST", "/appStoreReviewDetails", json={
        "data": {
            "type": "appStoreReviewDetails",
            "attributes": attrs,
            "relationships": {
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}
            },
        }
    })
    print(f"Review detail created: {response.status_code}")


def ensure_localizations(version_id):
    localizations = list_all(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=200")
    existing = {item["attributes"]["locale"]: item for item in localizations}
    for locale in META:
        if locale in existing:
            continue
        response, body = api_json("POST", "/appStoreVersionLocalizations", json={
            "data": {
                "type": "appStoreVersionLocalizations",
                "attributes": {"locale": locale},
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
            }
        })
        if response.status_code in (200, 201):
            existing[locale] = body["data"]
            print(f"Localization created: {locale}")
        else:
            print(f"Localization create {locale}: {response.status_code}")
    return list(existing.values())


def update_metadata(version_id):
    for loc in ensure_localizations(version_id):
        locale = loc["attributes"]["locale"]
        meta = META.get(locale, META["en-US"])
        response = api("PATCH", f"/appStoreVersionLocalizations/{loc['id']}", json={
            "data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": meta}
        })
        if response.status_code == 409 and "whatsNew" in meta:
            meta = {key: value for key, value in meta.items() if key != "whatsNew"}
            response = api("PATCH", f"/appStoreVersionLocalizations/{loc['id']}", json={
                "data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": meta}
            })
        print(f"Metadata {locale}: {response.status_code}")


def upload_screenshots(version_id):
    for loc in ensure_localizations(version_id):
        locale = loc["attributes"]["locale"]
        print(f"Screenshots for {locale}")
        sets = list_all(f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets?limit=200")
        existing = {item["attributes"]["screenshotDisplayType"]: item["id"] for item in sets}
        for display_type, folder in SCREENSHOT_GROUPS:
            set_id = existing.get(display_type)
            if not set_id:
                response, body = api_json("POST", "/appScreenshotSets", json={
                    "data": {
                        "type": "appScreenshotSets",
                        "attributes": {"screenshotDisplayType": display_type},
                        "relationships": {
                            "appStoreVersionLocalization": {
                                "data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}
                            }
                        },
                    }
                })
                if response.status_code not in (200, 201):
                    raise RuntimeError(f"Screenshot set create failed {response.status_code}: {response.text[:500]}")
                set_id = body["data"]["id"]

            for screenshot in list_all(f"/appScreenshotSets/{set_id}/appScreenshots?limit=200"):
                api("DELETE", f"/appScreenshots/{screenshot['id']}")

            for path in sorted((SCREENSHOT_DIR / folder).glob("*.png")):
                upload_screenshot(set_id, path)


def upload_screenshot(set_id, path):
    data = path.read_bytes()
    checksum = hashlib.md5(data).hexdigest()
    response, body = api_json("POST", "/appScreenshots", json={
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileName": path.name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
        }
    })
    if response.status_code not in (200, 201):
        raise RuntimeError(f"Screenshot create failed {response.status_code}: {response.text[:500]}")
    screenshot_id = body["data"]["id"]
    for operation in body["data"]["attributes"]["uploadOperations"]:
        request_headers = {item["name"]: item["value"] for item in operation["requestHeaders"]}
        start = operation["offset"]
        end = start + operation["length"]
        upload_binary_part(operation["url"], request_headers, data[start:end])
    response = api("PATCH", f"/appScreenshots/{screenshot_id}", json={
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
        }
    })
    print(f"  {path}: {response.status_code}")


def upload_binary_part(url, headers, data):
    for attempt in range(1, 6):
        try:
            response = requests.put(url, headers=headers, data=data, timeout=120)
            if response.status_code < 500:
                return response
        except RequestException as error:
            if attempt == 5:
                raise
            print(f"  Upload retry {attempt}/5: {error}")
        time.sleep(5 * attempt)
    return response


def wait_for_build():
    if not BUILD_NUMBER:
        raise RuntimeError("BUILD_NUMBER is required unless PREPARE_APP_ONLY=1")
    for index in range(90):
        response, body = api_json(
            "GET",
            f"/builds?filter[app]={APP_ID}&filter[version]={BUILD_NUMBER}&filter[processingState]=VALID&limit=1",
        )
        if body.get("data"):
            build_id = body["data"][0]["id"]
            print(f"Build ready: {build_id}")
            return build_id
        print(f"Waiting for build processing... {index + 1}/90")
        time.sleep(30)
    raise RuntimeError(f"Build {BUILD_NUMBER} did not finish processing")


def assign_build(version_id, build_id):
    api("PATCH", f"/builds/{build_id}", json={
        "data": {"type": "builds", "id": build_id, "attributes": {"usesNonExemptEncryption": False}}
    })
    response = api("PATCH", f"/appStoreVersions/{version_id}/relationships/build", json={
        "data": {"type": "builds", "id": build_id}
    })
    print(f"Build assigned: {response.status_code}")


def wait_for_version_reviewable(version_id):
    ready_states = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}
    for index in range(30):
        response, body = api_json(
            "GET",
            f"/appStoreVersions/{version_id}?fields[appStoreVersions]=appVersionState,appStoreState",
        )
        if response.status_code != 200:
            print(f"Version state check {index + 1}/30: {response.status_code} {response.text[:300]}")
            time.sleep(30)
            continue
        attrs = body["data"]["attributes"]
        state = attrs.get("appVersionState") or attrs.get("appStoreState")
        print(f"Version state after build assignment: {state}")
        if state in ready_states:
            return
        time.sleep(30)
    raise RuntimeError("App Store version did not become reviewable after assigning the build")


def submit_for_review(version_id):
    cancel_existing_review_submissions()

    response, body = api_json("POST", "/reviewSubmissions", json={
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    })
    if response.status_code == 201:
        submission_id = body["data"]["id"]
    elif response.status_code == 409:
        submission_id = find_reusable_review_submission()
        if not submission_id:
            raise RuntimeError(f"Review submission create failed {response.status_code}: {response.text[:500]}")
        print(f"Reusing review submission: {submission_id}")
    else:
        raise RuntimeError(f"Review submission create failed {response.status_code}: {response.text[:500]}")

    ensure_review_submission_item(submission_id, version_id)

    for attempt in range(1, 31):
        response, body = api_json("PATCH", f"/reviewSubmissions/{submission_id}", json={
            "data": {"type": "reviewSubmissions", "id": submission_id, "attributes": {"submitted": True}}
        })
        if response.status_code == 200:
            print(f"Submitted for App Review: {body['data']['attributes']['state']}")
            return
        print(f"Review submit {attempt}/30: {response.status_code} {response.text[:500]}")
        if "RELATIONSHIP.REQUIRED" in response.text:
            ensure_review_submission_item(submission_id, version_id)
        time.sleep(60)
    raise RuntimeError("Review submit did not complete")


def cancel_existing_review_submissions():
    response, body = api_json("GET", f"/apps/{APP_ID}/reviewSubmissions?limit=20")
    if response.status_code != 200:
        print(f"Review submission cleanup skipped: {response.status_code}")
        return
    for submission in body.get("data", []):
        state = submission.get("attributes", {}).get("state")
        if state not in ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES"):
            continue
        response = api("PATCH", f"/reviewSubmissions/{submission['id']}", json={
            "data": {
                "type": "reviewSubmissions",
                "id": submission["id"],
                "attributes": {"canceled": True},
            }
        })
        print(f"Canceled review submission {submission['id']} ({state}): {response.status_code}")
    time.sleep(15)


def ensure_review_submission_item(submission_id, version_id):
    existing_item = find_review_submission_item(submission_id, version_id)
    if existing_item:
        print(f"Review item already exists: {existing_item}")
        return

    response = api("POST", "/reviewSubmissionItems", json={
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
            },
        }
    })
    print(f"Review item: {response.status_code} {response.text[:500]}")
    if response.status_code in (200, 201):
        return

    existing_item = find_review_submission_item(submission_id, version_id)
    if existing_item:
        print(f"Review item found after conflict: {existing_item}")
        return
    raise RuntimeError(f"Review item create failed {response.status_code}: {response.text[:500]}")


def find_review_submission_item(submission_id, version_id):
    response, body = api_json(
        "GET",
        f"/reviewSubmissions/{submission_id}/items?include=appStoreVersion&fields[reviewSubmissionItems]=state,appStoreVersion&limit=50",
    )
    if response.status_code != 200:
        print(f"Review item lookup failed: {response.status_code} {response.text[:300]}")
        return None
    for item in body.get("data", []):
        relationship = item.get("relationships", {}).get("appStoreVersion", {}).get("data")
        if relationship and relationship.get("id") == version_id:
            return item["id"]
    return None


def find_reusable_review_submission():
    response, body = api_json("GET", f"/apps/{APP_ID}/reviewSubmissions?limit=20")
    if response.status_code != 200:
        return None
    for submission in body.get("data", []):
        if submission.get("attributes", {}).get("state") in ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES"):
            return submission["id"]
    return None


def main():
    response, body = api_json("GET", f"/apps/{APP_ID}")
    if response.status_code != 200:
        raise RuntimeError(f"App lookup failed {response.status_code}: {response.text[:500]}")
    attrs = body["data"]["attributes"]
    print(f"App: {attrs.get('name')} / {attrs.get('bundleId')}")

    version_id, _ = find_or_create_version()
    ensure_release_prerequisites(version_id)
    update_metadata(version_id)
    upload_screenshots(version_id)

    if os.environ.get("PREPARE_APP_ONLY") == "1":
        print("App Store Connect metadata and screenshots are ready.")
        return

    print("Waiting for screenshot processing...")
    time.sleep(300)
    build_id = wait_for_build()
    assign_build(version_id, build_id)
    wait_for_version_reviewable(version_id)
    submit_for_review(version_id)


if __name__ == "__main__":
    main()
