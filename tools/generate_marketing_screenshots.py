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
        "sub": "赤いボタンを前に、耐えるだけなのに妙に悔しい。",
        "mode": "30秒チャレンジ",
        "timer": "00:12",
        "status": "まだ見てるだけ",
    },
    {
        "name": "02-modes",
        "headline": "4つの遊び方",
        "sub": "短時間、長期戦、煽り強め。気分でモードを選べます。",
        "mode": "モード選択",
        "timer": "通常  30秒  耐久  強め",
        "status": "今日はどれで耐える？",
    },
    {
        "name": "03-achievements",
        "headline": "記録と実績",
        "sub": "ベストタイム、称号、最近の挑戦をアプリ内に保存。",
        "mode": "押さない達人",
        "timer": "BEST 03:18",
        "status": "30秒 / 1分 / 3分 / 5勝",
    },
    {
        "name": "04-failed",
        "headline": "押したら負け",
        "sub": "失敗も記録。次はもう少しだけ耐えたくなる。",
        "mode": "押したな",
        "timer": "00:24",
        "status": "やると思った。でも記録は残した。",
    },
    {
        "name": "05-survived",
        "headline": "耐え抜いた",
        "sub": "退室または目標達成で記録。次の称号を狙えます。",
        "mode": "目標達成",
        "timer": "03:00",
        "status": "ベスト更新",
    },
]


def font(size: int) -> ImageFont.FreeTypeFont:
    path = FONT if FONT.exists() else FONT_FALLBACK
    return ImageFont.truetype(str(path), size=size)


def fit_text(draw, text, max_width, start_size, min_size):
    size = start_size
    while size >= min_size:
        candidate = font(size)
        if draw.textbbox((0, 0), text, font=candidate)[2] <= max_width:
            return candidate
        size -= 2
    return font(min_size)


def cover(image: Image.Image, size):
    w, h = image.size
    tw, th = size
    scale = max(tw / w, th / h)
    resized = image.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - tw) // 2
    top = (resized.height - th) // 2
    return resized.crop((left, top, left + tw, top + th))


def draw_panel(draw, xy, radius, fill=(0, 0, 0, 150)):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=(255, 255, 255, 32), width=2)


def draw_button(base, cx, cy, radius):
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(9, 0, -1):
        r = int(radius * (1 + i * 0.15))
        gd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 0, 0, 15 * i))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius // 4)))

    if BUTTON_ASSET.exists():
        button = Image.open(BUTTON_ASSET).convert("RGBA")
        button.thumbnail((radius * 2, radius * 2), Image.Resampling.LANCZOS)
        base.alpha_composite(button, (int(cx - button.width / 2), int(cy - button.height / 2)))
        return

    draw = ImageDraw.Draw(base)
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(112, 0, 0, 255))
    inset = radius // 10
    draw.ellipse((cx - radius + inset, cy - radius + inset, cx + radius - inset, cy + radius - inset), fill=(230, 8, 6, 255))
    draw.ellipse((cx - radius // 2, cy - radius // 2, cx + radius // 4, cy - radius // 8), fill=(255, 130, 120, 72))


def draw_tile(draw, xy, title, value, scale):
    draw_panel(draw, xy, int(8 * scale), (255, 255, 255, 24))
    x1, y1, x2, y2 = xy
    draw.text(((x1 + x2) / 2, y1 + 18 * scale), title, font=font(int(22 * scale)), anchor="mt", fill=(255, 255, 255, 145))
    value_font = fit_text(draw, value, x2 - x1 - 20 * scale, int(34 * scale), int(20 * scale))
    draw.text(((x1 + x2) / 2, y1 + 55 * scale), value, font=value_font, anchor="mt", fill=(255, 255, 255, 255))


def draw_ui(base, scene):
    w, h = base.size
    scale = w / 1320
    draw = ImageDraw.Draw(base)
    ad_h = int(h * 0.064)
    bottom = h - ad_h - int(30 * scale)
    margin = int(w * 0.07)

    draw.rectangle((0, h - ad_h, w, h), fill=(4, 4, 5, 238))
    draw.rectangle((0, h - ad_h, w, h - ad_h + 2), fill=(255, 255, 255, 28))

    top = int(h * 0.075)
    headline_font = fit_text(draw, scene["headline"], w - margin * 2, int(72 * scale), int(46 * scale))
    sub_font = fit_text(draw, scene["sub"], w - margin * 2, int(34 * scale), int(25 * scale))
    draw.text((margin, top), scene["headline"], font=headline_font, fill=(255, 255, 255, 255))
    draw.text((margin, top + int(95 * scale)), scene["sub"], font=sub_font, fill=(235, 226, 220, 218))

    panel_top = int(h * 0.22)
    panel_margin = int(w * 0.055)
    draw_panel(draw, (panel_margin, panel_top, w - panel_margin, bottom), int(18 * scale))

    tile_top = panel_top + int(35 * scale)
    gap = int(12 * scale)
    tile_w = int((w - panel_margin * 2 - gap * 4) / 3)
    x = panel_margin + gap
    draw_tile(draw, (x, tile_top, x + tile_w, tile_top + int(105 * scale)), "現在", scene["timer"], scale)
    x += tile_w + gap
    draw_tile(draw, (x, tile_top, x + tile_w, tile_top + int(105 * scale)), "ベスト", "03:18", scale)
    x += tile_w + gap
    draw_tile(draw, (x, tile_top, x + tile_w, tile_top + int(105 * scale)), "称号", scene["mode"], scale)

    button_y = int(panel_top + (bottom - panel_top) * 0.48)
    draw_button(base, w // 2, button_y, int(w * 0.18))
    button_font = font(int(70 * scale))
    draw.text((w / 2, button_y - int(12 * scale)), "押すな", font=button_font, anchor="mm", fill=(255, 255, 255, 255))
    draw.text((w / 2, button_y + int(48 * scale)), "DON'T", font=font(int(28 * scale)), anchor="mm", fill=(255, 255, 255, 185))

    status_font = fit_text(draw, scene["status"], w - margin * 2, int(38 * scale), int(25 * scale))
    draw.text((w / 2, button_y + int(w * 0.245)), scene["status"], font=status_font, anchor="mm", fill=(255, 255, 255, 210))

    bar_x1 = panel_margin + int(42 * scale)
    bar_x2 = w - panel_margin - int(42 * scale)
    bar_y = bottom - int(205 * scale)
    draw.rounded_rectangle((bar_x1, bar_y, bar_x2, bar_y + int(18 * scale)), radius=int(9 * scale), fill=(255, 255, 255, 35))
    fill_w = int((bar_x2 - bar_x1) * (0.42 if scene["name"] == "01-home" else 0.82))
    draw.rounded_rectangle((bar_x1, bar_y, bar_x1 + fill_w, bar_y + int(18 * scale)), radius=int(9 * scale), fill=(255, 70, 45, 230))

    badges = ["30秒", "1分", "3分", "5勝"]
    badge_y = bottom - int(145 * scale)
    badge_w = int((bar_x2 - bar_x1 - gap * 3) / 4)
    for idx, badge in enumerate(badges):
        bx = bar_x1 + idx * (badge_w + gap)
        fill = (255, 70, 45, 95) if idx < 3 else (255, 255, 255, 35)
        draw.rounded_rectangle((bx, badge_y, bx + badge_w, badge_y + int(58 * scale)), radius=int(8 * scale), fill=fill)
        draw.text((bx + badge_w / 2, badge_y + int(29 * scale)), badge, font=font(int(24 * scale)), anchor="mm", fill=(255, 255, 255, 230))


def make_screenshot(size, scene):
    bg = cover(Image.open(BACKDROP).convert("RGBA"), size)
    bg.alpha_composite(Image.new("RGBA", size, (0, 0, 0, 45)))
    draw_ui(bg, scene)
    return bg.convert("RGB")


def main():
    if not BACKDROP.exists():
        raise SystemExit(f"Missing backdrop: {BACKDROP}")
    for device, size in DEVICES.items():
        out_dir = OUT / device
        out_dir.mkdir(parents=True, exist_ok=True)
        for scene in SCENES:
            path = out_dir / f"{scene['name']}.png"
            make_screenshot(size, scene).save(path, quality=95)
            print(path)


if __name__ == "__main__":
    main()
