from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
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
        "state": "playing",
        "timer": "00:18",
        "best": "01:12",
        "calm": "24 pt",
        "event": "赤い点滅",
        "event_detail": "深呼吸でゲージを落ち着かせる",
        "action": "深呼吸",
        "progress": 0.60,
    },
    {
        "name": "02-missions",
        "state": "missions",
        "timer": "00:00",
        "best": "03:18",
        "calm": "0 pt",
        "event": "今日の修行",
        "event_detail": "日替わり3本をクリア",
        "action": "任務",
        "progress": 0.20,
    },
    {
        "name": "03-actions",
        "state": "actions",
        "timer": "01:04",
        "best": "03:18",
        "calm": "56 pt",
        "event": "指が近い",
        "event_detail": "目をそらして誘惑を切る",
        "action": "目をそらす",
        "progress": 0.75,
    },
    {
        "name": "04-failed",
        "state": "failed",
        "timer": "00:24",
        "best": "03:18",
        "calm": "18 pt",
        "event": "押したな",
        "event_detail": "失敗も記録。次はもう少し耐える。",
        "action": "失敗",
        "progress": 0.36,
    },
    {
        "name": "05-survived",
        "state": "survived",
        "timer": "03:00",
        "best": "03:18",
        "calm": "91 pt",
        "event": "耐え抜いた",
        "event_detail": "任務クリア。称号と履歴を保存。",
        "action": "達成",
        "progress": 1.0,
    },
]


def font(size: int) -> ImageFont.FreeTypeFont:
    path = FONT if FONT.exists() else FONT_FALLBACK
    return ImageFont.truetype(str(path), size=size)


def fit(draw, text, max_width, start, minimum):
    size = start
    while size >= minimum:
        candidate = font(size)
        if draw.textbbox((0, 0), text, font=candidate)[2] <= max_width:
            return candidate
        size -= 2
    return font(minimum)


def panel(draw, xy, scale, fill=(13, 13, 16, 255)):
    draw.rounded_rectangle(xy, radius=int(8 * scale), fill=fill, outline=(54, 54, 62, 255), width=max(1, int(1.5 * scale)))


def background(size, intensity):
    w, h = size
    base = Image.new("RGBA", size, (5, 5, 7, 255))
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    center = (w // 2, int(h * 0.35))
    for i in range(18, 0, -1):
        r = int(max(w, h) * i / 18)
        alpha = int((3 + intensity * 7) * i)
        gd.ellipse((center[0] - r, center[1] - r, center[0] + r, center[1] + r), fill=(180, 0, 0, alpha))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(max(18, w // 20))))
    draw = ImageDraw.Draw(base)
    stripe_gap = max(14, int(h * 0.018))
    for y in range(0, h, stripe_gap):
        draw.rectangle((0, y, w, y + 2), fill=(48, 8, 8, 255))
    return base


def draw_stat(draw, xy, title, value, scale):
    panel(draw, xy, scale, (30, 30, 34, 255))
    x1, y1, x2, y2 = xy
    draw.text(((x1 + x2) / 2, y1 + int(13 * scale)), title, font=font(int(18 * scale)), anchor="mt", fill=(150, 150, 158, 255))
    value_font = fit(draw, value, x2 - x1 - int(12 * scale), int(27 * scale), int(17 * scale))
    draw.text(((x1 + x2) / 2, y1 + int(45 * scale)), value, font=value_font, anchor="mt", fill=(245, 245, 248, 255))


def draw_button(base, cx, cy, r, scale, label="押すな"):
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(7, 0, -1):
        rr = int(r * (1 + i * 0.17))
        gd.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(255, 0, 0, 13 * i))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(max(12, int(r * 0.22)))))
    draw = ImageDraw.Draw(base)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(95, 0, 0, 255), outline=(255, 255, 255, 55), width=max(2, int(3 * scale)))
    inset = int(r * 0.11)
    draw.ellipse((cx - r + inset, cy - r + inset, cx + r - inset, cy + r - inset), fill=(232, 12, 10, 255))
    draw.ellipse((cx - int(r * 0.48), cy - int(r * 0.58), cx + int(r * 0.16), cy - int(r * 0.12)), fill=(255, 155, 140, 80))
    draw.text((cx, cy - int(8 * scale)), label, font=font(int(55 * scale)), anchor="mm", fill=(255, 255, 255, 255))
    draw.text((cx, cy + int(44 * scale)), "DON'T", font=font(int(20 * scale)), anchor="mm", fill=(255, 255, 255, 180))


def mission_tile(draw, xy, title, detail, time_text, done, active, scale):
    fill = (112, 22, 20, 255) if active else ((30, 45, 34, 255) if done else (27, 27, 31, 255))
    panel(draw, xy, scale, fill)
    x1, y1, x2, y2 = xy
    mark = "✓" if done else "○"
    draw.text((x1 + int(12 * scale), y1 + int(12 * scale)), mark, font=font(int(22 * scale)), fill=(120, 255, 150, 255) if done else (165, 165, 172, 255))
    draw.text((x1 + int(40 * scale), y1 + int(12 * scale)), title, font=font(int(21 * scale)), fill=(248, 248, 250, 255))
    draw.text((x1 + int(12 * scale), y1 + int(48 * scale)), detail, font=font(int(16 * scale)), fill=(174, 174, 182, 255))
    draw.text((x2 - int(12 * scale), y2 - int(12 * scale)), time_text, font=font(int(17 * scale)), anchor="rb", fill=(215, 215, 222, 255))


def action_button(draw, xy, title, points, active, scale):
    fill = (245, 245, 248, 255) if active else (31, 31, 36, 255)
    text = (15, 15, 18, 255) if active else (255, 255, 255, 230)
    draw.rounded_rectangle(xy, radius=int(8 * scale), fill=fill)
    x1, y1, x2, y2 = xy
    draw.text(((x1 + x2) / 2, y1 + int(18 * scale)), title, font=font(int(21 * scale)), anchor="mt", fill=text)
    draw.text(((x1 + x2) / 2, y1 + int(57 * scale)), f"+{points}", font=font(int(17 * scale)), anchor="mt", fill=text)


def draw_screen(scene, size):
    w, h = size
    scale = w / 1320
    base = background(size, scene["progress"])
    draw = ImageDraw.Draw(base)
    ad_h = int(54 * scale)
    content_w = min(w - int(54 * scale), int(860 * scale))
    left = (w - content_w) // 2
    right = left + content_w
    y = int(58 * scale)

    draw.text((w / 2, y), "絶対押すなよ", font=fit(draw, "絶対押すなよ", content_w, int(48 * scale), int(32 * scale)), anchor="mt", fill=(255, 255, 255, 255))
    draw.text((w / 2, y + int(62 * scale)), "赤いボタンを押さずに、任務とイベントを越える。", font=font(int(22 * scale)), anchor="mt", fill=(196, 196, 204, 255))
    y += int(120 * scale)

    gap = int(10 * scale)
    stat_w = (content_w - gap * 3) // 4
    for i, (title, value) in enumerate([("現在", scene["timer"]), ("ベスト", scene["best"]), ("冷静", scene["calm"]), ("対処", "4/6")]):
        x = left + i * (stat_w + gap)
        draw_stat(draw, (x, y, x + stat_w, y + int(75 * scale)), title, value, scale)
    y += int(93 * scale)

    panel(draw, (left, y, right, y + int(150 * scale)), scale)
    draw.text((left + int(16 * scale), y + int(14 * scale)), "今日の修行", font=font(int(25 * scale)), fill=(255, 255, 255, 250))
    draw.text((right - int(16 * scale), y + int(16 * scale)), "1/3", font=font(int(25 * scale)), anchor="rt", fill=(255, 255, 255, 230))
    tile_y = y + int(54 * scale)
    tile_w = (content_w - int(52 * scale)) // 3
    missions = [("初級 10秒", "短く耐える", "00:10"), ("冷静キープ", "行動を使う", "00:45"), ("1分耐久", "称号を狙う", "01:00")]
    for i, item in enumerate(missions):
        x = left + int(16 * scale) + i * (tile_w + int(10 * scale))
        mission_tile(draw, (x, tile_y, x + tile_w, tile_y + int(78 * scale)), item[0], item[1], item[2], i == 0, i == 1 and scene["state"] == "missions", scale)
    y += int(168 * scale)

    if scene["state"] in ("missions", "actions"):
        panel(draw, (left, y, right, y + int(190 * scale)), scale)
        draw.text((left + int(16 * scale), y + int(14 * scale)), "チャレンジ任務", font=font(int(25 * scale)), fill=(255, 255, 255, 250))
        grid_y = y + int(54 * scale)
        grid_w = (content_w - int(42 * scale)) // 2
        mission_tile(draw, (left + int(16 * scale), grid_y, left + int(16 * scale) + grid_w, grid_y + int(112 * scale)), "30秒の壁", "煽りを聞きながら耐える", "00:30", True, False, scale)
        mission_tile(draw, (left + int(26 * scale) + grid_w, grid_y, right - int(16 * scale), grid_y + int(112 * scale)), "赤い誘惑", "強めで2分", "02:00", False, True, scale)
        y += int(208 * scale)

    button_r = int(145 * scale if scene["state"] in ("missions", "actions") else 168 * scale)
    button_y = y + button_r + int(18 * scale)
    draw_button(base, w // 2, button_y, button_r, scale)
    draw.text((w / 2, button_y + button_r + int(34 * scale)), "30秒の壁: 00:30まで耐える", font=font(int(24 * scale)), anchor="mt", fill=(255, 255, 255, 200))
    y = button_y + button_r + int(78 * scale)

    panel(draw, (left, y, right, y + int(112 * scale)), scale, (82, 0, 0, 255) if scene["state"] != "survived" else (0, 66, 36, 255))
    draw.text((left + int(16 * scale), y + int(12 * scale)), "緊急イベント", font=font(int(24 * scale)), fill=(255, 255, 255, 250))
    draw.text((right - int(16 * scale), y + int(15 * scale)), "最高5コンボ", font=font(int(18 * scale)), anchor="rt", fill=(255, 230, 110, 255))
    draw.text((left + int(16 * scale), y + int(52 * scale)), scene["event"], font=font(int(27 * scale)), fill=(255, 255, 255, 255))
    draw.text((left + int(16 * scale), y + int(86 * scale)), scene["event_detail"], font=font(int(18 * scale)), fill=(205, 205, 212, 255))
    y += int(128 * scale)

    panel(draw, (left, y, right, y + int(126 * scale)), scale)
    draw.text((left + int(16 * scale), y + int(12 * scale)), "押さないための行動", font=font(int(24 * scale)), fill=(255, 255, 255, 250))
    action_y = y + int(52 * scale)
    action_w = (content_w - int(52 * scale)) // 3
    for i, (title, points) in enumerate([("深呼吸", 3), ("目をそらす", 4), ("3秒数える", 5)]):
        x = left + int(16 * scale) + i * (action_w + int(10 * scale))
        action_button(draw, (x, action_y, x + action_w, action_y + int(58 * scale)), title, points, title == scene["action"], scale)
    y += int(142 * scale)

    bar_y = y + int(10 * scale)
    draw.text((left, bar_y - int(30 * scale)), "緊張ゲージ", font=font(int(23 * scale)), fill=(255, 255, 255, 245))
    draw.text((right, bar_y - int(30 * scale)), f"{int(scene['progress'] * 100)}%", font=font(int(23 * scale)), anchor="rt", fill=(255, 100, 70, 245))
    draw.rounded_rectangle((left, bar_y, right, bar_y + int(14 * scale)), radius=int(7 * scale), fill=(40, 40, 45, 255))
    draw.rounded_rectangle((left, bar_y, left + int(content_w * scene["progress"]), bar_y + int(14 * scale)), radius=int(7 * scale), fill=(255, 75, 45, 235))

    ad_top = h - ad_h
    draw.rectangle((0, ad_top, w, h), fill=(4, 4, 5, 255))
    draw.rectangle((0, ad_top, w, ad_top + 2), fill=(32, 32, 36, 255))
    return base.convert("RGB")


def main():
    for device, size in DEVICES.items():
        out_dir = OUT / device
        out_dir.mkdir(parents=True, exist_ok=True)
        for scene in SCENES:
            path = out_dir / f"{scene['name']}.png"
            draw_screen(scene, size).save(path, quality=95)
            print(path)


if __name__ == "__main__":
    main()
