from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
BACKDROP = ROOT / "MarketingAssets" / "Backgrounds" / "screenshot-backdrop-imagegen.png"
BUTTON_ASSET = ROOT / "MarketingAssets" / "Buttons" / "real-button.png"
OUT = ROOT / "MarketingAssets" / "Screenshots"
FONT = Path("C:/Windows/Fonts/NotoSansJP-VF.ttf")
FONT_FALLBACK = Path("C:/Windows/Fonts/yumindb.ttf")

DEVICES = {
    "iphone_69": (1320, 2868),
    "iphone_67": (1290, 2796),
    "iphone_65": (1242, 2688),
    "iphone_55": (1242, 2208),
    "ipad_129": (2048, 2732),
}

SCENES = [
    {
        "name": "01-home",
        "headline": "押すなと言われたら",
        "sub": "巨大な赤いボタンと、あなたの自制心だけ。",
        "state": "home",
        "caption": "00分42秒",
    },
    {
        "name": "02-voice",
        "headline": "小声で煽ってくる",
        "sub": "ランダム音声が、指先をじわじわ試す。",
        "state": "voice",
        "caption": "「……今、近づいたよな？」",
    },
    {
        "name": "03-tension",
        "headline": "耐えるほど追い込まれる",
        "sub": "経過時間に合わせて音声の頻度が上がる。",
        "state": "tension",
        "caption": "02分18秒",
    },
    {
        "name": "04-failed",
        "headline": "押したら終わり",
        "sub": "説教音声が、ずっと終わらない。",
        "state": "failed",
        "caption": "押したな",
    },
    {
        "name": "05-survived",
        "headline": "押さずに去れ",
        "sub": "終了した瞬間、耐え抜いた時間を記録。",
        "state": "survived",
        "caption": "あなたは3分7秒耐え抜きました",
    },
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT if FONT.exists() else FONT_FALLBACK
    return ImageFont.truetype(str(path), size=size)


def fit_text(draw, text, max_width, start_size, min_size, bold=False):
    size = start_size
    while size >= min_size:
        f = font(size, bold)
        if draw.textbbox((0, 0), text, font=f)[2] <= max_width:
            return f
        size -= 2
    return font(min_size, bold)


def cover(image: Image.Image, size):
    w, h = image.size
    tw, th = size
    scale = max(tw / w, th / h)
    nw, nh = int(w * scale), int(h * scale)
    resized = image.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return resized.crop((left, top, left + tw, top + th))


def rounded_rect(draw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_button(base, cx, cy, radius, intensity=1.0):
    if BUTTON_ASSET.exists():
        button = Image.open(BUTTON_ASSET).convert("RGBA")
        target = radius * 2
        button.thumbnail((target, target), Image.Resampling.LANCZOS)
        glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        for i in range(8, 0, -1):
            r = int(radius * (1 + i * 0.17))
            alpha = int(12 * intensity * i)
            gd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 0, 0, alpha))
        base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius // 4)))
        base.alpha_composite(button, (int(cx - button.width / 2), int(cy - button.height / 2)))
        return

    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(9, 0, -1):
        r = int(radius * (1 + i * 0.18))
        alpha = int(18 * intensity * i)
        gd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 0, 0, alpha))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius // 5)))

    d = ImageDraw.Draw(base)
    d.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(116, 0, 0, 255))
    inset = int(radius * 0.09)
    d.ellipse((cx - radius + inset, cy - radius + inset, cx + radius - inset, cy + radius - inset), fill=(210, 0, 0, 255))
    d.ellipse((cx - radius + inset * 2, cy - radius + inset * 2, cx + radius - inset * 2, cy + radius - inset * 2), fill=(246, 18, 15, 255))
    d.ellipse((cx - radius // 2, cy - radius // 2, cx + radius // 4, cy - radius // 8), fill=(255, 125, 110, 68))


def draw_phone_ui(base, scene):
    w, h = base.size
    d = ImageDraw.Draw(base)
    ad_h = int(h * 0.064)
    safe_bottom = ad_h + int(h * 0.035)

    d.rectangle((0, h - ad_h, w, h), fill=(4, 4, 5, 238))
    d.rectangle((0, h - ad_h, w, h - ad_h + 2), fill=(255, 255, 255, 28))

    margin = int(w * 0.075)
    top = int(h * 0.09)
    headline_f = fit_text(d, scene["headline"], w - margin * 2, int(w * 0.089), int(w * 0.052), True)
    sub_f = fit_text(d, scene["sub"], w - margin * 2, int(w * 0.039), int(w * 0.027))
    d.text((margin, top), scene["headline"], font=headline_f, fill=(255, 255, 255, 255))
    d.text((margin, top + int(w * 0.11)), scene["sub"], font=sub_f, fill=(232, 226, 222, 215))

    panel_top = int(h * 0.245)
    panel_bottom = h - safe_bottom
    panel_margin = int(w * 0.055)
    rounded_rect(d, (panel_margin, panel_top, w - panel_margin, panel_bottom), int(w * 0.035), (0, 0, 0, 132), (255, 255, 255, 24), 2)

    if scene["state"] in ("home", "voice", "tension"):
        title = "絶対押すなよ"
        title_f = fit_text(d, title, w - margin * 2, int(w * 0.056), int(w * 0.038), True)
        timer_f = font(int(w * 0.056), True)
        d.text((w / 2, panel_top + int(h * 0.065)), title, font=title_f, anchor="mm", fill=(255, 255, 255, 255))
        d.text((w / 2, panel_top + int(h * 0.115)), scene["caption"], font=timer_f, anchor="mm", fill=(255, 55, 45, 255))
        button_r = int(w * (0.2 if scene["state"] != "tension" else 0.215))
        draw_button(base, w // 2, int(panel_top + (panel_bottom - panel_top) * 0.52), button_r, 1.25)
        btn_f = font(int(w * 0.068), True)
        d.text((w / 2, int(panel_top + (panel_bottom - panel_top) * 0.52)), "押すな", font=btn_f, anchor="mm", fill=(255, 255, 255, 255))
        bottom_label = "指、近い" if scene["state"] != "voice" else scene["caption"]
        label_f = fit_text(d, bottom_label, w - margin * 2, int(w * 0.04), int(w * 0.028), True)
        d.text((w / 2, panel_bottom - int(h * 0.07)), bottom_label, font=label_f, anchor="mm", fill=(255, 255, 255, 190))

    elif scene["state"] == "failed":
        failed_f = fit_text(d, scene["caption"], w - margin * 2, int(w * 0.115), int(w * 0.075), True)
        d.text((w / 2, panel_top + int(h * 0.16)), scene["caption"], font=failed_f, anchor="mm", fill=(255, 35, 35, 255))
        d.text((w / 2, panel_top + int(h * 0.25)), "やると思った。ほんとに押した。", font=fit_text(d, "やると思った。ほんとに押した。", w - margin * 2, int(w * 0.042), int(w * 0.03), True), anchor="mm", fill=(255, 255, 255, 218))
        draw_button(base, w // 2, int(panel_top + (panel_bottom - panel_top) * 0.58), int(w * 0.16), 0.95)
        d.line((int(w * 0.34), int(panel_top + (panel_bottom - panel_top) * 0.49), int(w * 0.66), int(panel_top + (panel_bottom - panel_top) * 0.67)), fill=(255, 255, 255, 230), width=max(8, w // 90))
        d.line((int(w * 0.66), int(panel_top + (panel_bottom - panel_top) * 0.49), int(w * 0.34), int(panel_top + (panel_bottom - panel_top) * 0.67)), fill=(255, 255, 255, 230), width=max(8, w // 90))

    else:
        survived_f = fit_text(d, "耐え抜いた", w - margin * 2, int(w * 0.09), int(w * 0.06), True)
        d.text((w / 2, panel_top + int(h * 0.15)), "耐え抜いた", font=survived_f, anchor="mm", fill=(255, 255, 255, 255))
        cap_f = fit_text(d, scene["caption"], w - margin * 2, int(w * 0.052), int(w * 0.034), True)
        d.text((w / 2, panel_top + int(h * 0.25)), scene["caption"], font=cap_f, anchor="mm", fill=(255, 64, 58, 255))
        d.text((w / 2, panel_top + int(h * 0.33)), "押さずに去る。いちばん強い。", font=fit_text(d, "押さずに去る。いちばん強い。", w - margin * 2, int(w * 0.04), int(w * 0.03), True), anchor="mm", fill=(255, 255, 255, 195))
        draw_button(base, w // 2, int(panel_top + (panel_bottom - panel_top) * 0.64), int(w * 0.13), 0.75)


def make_screenshot(size, scene):
    bg = cover(Image.open(BACKDROP).convert("RGBA"), size)
    overlay = Image.new("RGBA", size, (0, 0, 0, 30))
    bg.alpha_composite(overlay)
    draw_phone_ui(bg, scene)
    return bg.convert("RGB")


def main():
    if not BACKDROP.exists():
        raise SystemExit(f"Missing backdrop: {BACKDROP}")

    for device, size in DEVICES.items():
        out_dir = OUT / device
        out_dir.mkdir(parents=True, exist_ok=True)
        for scene in SCENES:
            image = make_screenshot(size, scene)
            image.save(out_dir / f"{scene['name']}.png", quality=95)
            print(out_dir / f"{scene['name']}.png")


if __name__ == "__main__":
    main()
