from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
BRANDING_DIR = ROOT / 'assets' / 'branding'
RES_DIR = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'

ICON_FOREGROUND = RES_DIR / 'drawable-nodpi' / 'ic_launcher_foreground.png'
SPLASH_LOGO = RES_DIR / 'drawable-nodpi' / 'splash_logo.png'
MIPMAPS = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

COLORS = {
    'ink': '#0F2028',
    'burgundy': '#8E2B30',
    'crimson': '#C94848',
    'coral': '#D65A43',
    'gold': '#F5C76E',
    'cream': '#FFF7F1',
    'rose': '#F4D8D0',
    'mist': '#F6ECE6',
    'slate': '#3C5664',
    'muted': '#7A736E',
    'white': '#FFFFFF',
}


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[index:index + 2], 16) for index in (0, 2, 4)) + (alpha,)


def lerp(start: tuple[int, int, int, int], end: tuple[int, int, int, int], factor: float) -> tuple[int, int, int, int]:
    return tuple(int(start[i] + (end[i] - start[i]) * factor) for i in range(4))


def gradient_image(size: tuple[int, int], start_hex: str, end_hex: str, *, horizontal: bool = False) -> Image.Image:
    width, height = size
    base = Image.new('RGBA', size)
    start = rgba(start_hex)
    end = rgba(end_hex)
    draw = ImageDraw.Draw(base)
    steps = width if horizontal else height
    for step in range(steps):
        ratio = step / max(steps - 1, 1)
        color = lerp(start, end, ratio)
        if horizontal:
            draw.line((step, 0, step, height), fill=color)
        else:
            draw.line((0, step, width, step), fill=color)
    return base


def rounded_gradient_box(size: tuple[int, int], radius: int, start_hex: str, end_hex: str) -> Image.Image:
    gradient = gradient_image(size, start_hex, end_hex)
    mask = Image.new('L', size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    gradient.putalpha(mask)
    return gradient


def load_font(name: str, size: int) -> ImageFont.FreeTypeFont:
    font_path = Path('C:/Windows/Fonts') / name
    return ImageFont.truetype(str(font_path), size=size)


TITLE_FONT = load_font('bahnschrift.ttf', 110)
TITLE_FONT_SMALL = load_font('bahnschrift.ttf', 78)
SUBTITLE_FONT = load_font('segoeui.ttf', 42)
CHIP_FONT = load_font('bahnschrift.ttf', 32)
BODY_FONT = load_font('segoeui.ttf', 34)
MICRO_FONT = load_font('segoeui.ttf', 24)
PHONE_TITLE_FONT = load_font('bahnschrift.ttf', 54)
PHONE_BODY_FONT = load_font('segoeui.ttf', 20)


def add_glow(canvas: Image.Image, box: tuple[int, int, int, int], color_hex: str, blur: int, alpha: int) -> None:
    glow = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    draw.ellipse(box, fill=rgba(color_hex, alpha))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(blur)))


def add_shadow(layer: Image.Image, box: tuple[int, int, int, int], radius: int, offset: tuple[int, int], alpha: int = 54) -> None:
    shadow = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    ox, oy = offset
    draw.rounded_rectangle((box[0] + ox, box[1] + oy, box[2] + ox, box[3] + oy), radius=radius, fill=(24, 7, 9, alpha))
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(24)))


def paste_with_mask(base: Image.Image, overlay: Image.Image, position: tuple[int, int]) -> None:
    base.alpha_composite(overlay, position)


def make_pencil(size: tuple[int, int]) -> Image.Image:
    width, height = size
    layer = Image.new('RGBA', (width * 2, height * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    body_box = (180, 260, 780, 500)
    draw.rounded_rectangle(body_box, radius=120, fill=rgba(COLORS['coral']))
    draw.rounded_rectangle((180, 260, 330, 500), radius=120, fill=rgba('#FF9660'))
    draw.rectangle((560, 260, 660, 500), fill=rgba(COLORS['gold']))
    draw.rectangle((660, 260, 760, 500), fill=rgba('#E95B4A'))
    draw.polygon([(760, 260), (930, 380), (760, 500)], fill=rgba('#F6DFC0'))
    draw.polygon([(930, 380), (995, 344), (970, 428)], fill=rgba(COLORS['ink']))

    rotated = layer.rotate(-36, resample=Image.Resampling.BICUBIC, center=(560, 380), expand=False)
    return rotated.resize(size, Image.Resampling.LANCZOS)


def draw_sparkle(draw: ImageDraw.ImageDraw, center: tuple[int, int], radius: int, color: tuple[int, int, int, int]) -> None:
    x, y = center
    draw.polygon([(x, y - radius), (x + radius // 3, y), (x, y + radius), (x - radius // 3, y)], fill=color)
    draw.polygon([(x - radius, y), (x, y - radius // 3), (x + radius, y), (x, y + radius // 3)], fill=color)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: int) -> str:
    paragraphs = text.split('\n')
    wrapped_paragraphs: list[str] = []

    for paragraph in paragraphs:
        words = paragraph.split()
        if not words:
            wrapped_paragraphs.append('')
            continue

        line = words[0]
        lines: list[str] = []
        for word in words[1:]:
            candidate = f'{line} {word}'
            if draw.textlength(candidate, font=font) <= max_width:
                line = candidate
            else:
                lines.append(line)
                line = word
        lines.append(line)
        wrapped_paragraphs.append('\n'.join(lines))

    return '\n'.join(wrapped_paragraphs)


def draw_document_mark(size: tuple[int, int], *, include_glow: bool) -> Image.Image:
    width, height = size
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    if include_glow:
      add_glow(layer, (40, 80, width - 20, height - 20), COLORS['coral'], blur=24, alpha=36)

    sheet_box = (90, 70, width - 110, height - 48)
    add_shadow(layer, sheet_box, radius=64, offset=(10, 16), alpha=52)
    draw.rounded_rectangle(sheet_box, radius=62, fill=rgba(COLORS['cream']))

    left_strip = (sheet_box[0], sheet_box[1] + 8, sheet_box[0] + 96, sheet_box[3])
    draw.rounded_rectangle(left_strip, radius=48, fill=rgba(COLORS['rose']))

    fold = [
        (sheet_box[2] - 118, sheet_box[1]),
        (sheet_box[2], sheet_box[1]),
        (sheet_box[2], sheet_box[1] + 118),
    ]
    draw.polygon(fold, fill=rgba('#F8E4DE'))
    draw.line((sheet_box[2] - 118, sheet_box[1], sheet_box[2], sheet_box[1] + 118), fill=rgba('#DAAAA0'), width=7)

    draw.rounded_rectangle((sheet_box[0] + 150, sheet_box[1] + 96, sheet_box[2] - 160, sheet_box[1] + 142), radius=26, fill=rgba('#BA5F60'))
    for index in range(3):
        top = sheet_box[1] + 206 + index * 100
        draw.rounded_rectangle((sheet_box[0] + 150, top, sheet_box[2] - 120, top + 38), radius=19, fill=rgba('#D7B8B8'))

    pencil = make_pencil((width, height))
    layer.alpha_composite(pencil)

    sparkle_color = rgba(COLORS['gold'])
    draw_sparkle(draw, (sheet_box[0] - 26, sheet_box[1] + 32), 26, sparkle_color)
    draw_sparkle(draw, (sheet_box[0] - 6, sheet_box[1] + 6), 18, sparkle_color)

    return layer


def make_brand_icon() -> Image.Image:
    canvas = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    add_glow(canvas, (40, 68, 984, 988), COLORS['burgundy'], blur=48, alpha=86)

    card = rounded_gradient_box((858, 858), 150, COLORS['crimson'], COLORS['burgundy'])
    paste_with_mask(canvas, card, (83, 83))

    overlay = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.rounded_rectangle((102, 102, 922, 922), radius=142, outline=rgba('#F87777', 132), width=6)
    draw.rounded_rectangle((120, 120, 904, 904), radius=134, outline=rgba('#FFFFFF', 28), width=4)
    sheen = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    sheen_draw = ImageDraw.Draw(sheen)
    sheen_draw.rounded_rectangle((132, 122, 892, 286), radius=74, fill=rgba('#FFFFFF', 34))
    overlay.alpha_composite(sheen.filter(ImageFilter.GaussianBlur(22)))
    canvas.alpha_composite(overlay)

    mark = draw_document_mark((720, 720), include_glow=False)
    canvas.alpha_composite(mark, (152, 150))
    return canvas


def make_foreground_icon(size: int) -> Image.Image:
    scale = 720 if size > 400 else 560
    mark = draw_document_mark((scale, scale), include_glow=False)
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    mark = mark.resize((int(scale * 0.9), int(scale * 0.9)), Image.Resampling.LANCZOS)
    left = (size - mark.size[0]) // 2
    top = (size - mark.size[1]) // 2
    canvas.alpha_composite(mark, (left, top))
    return canvas


def make_store_shot(file_name: str, headline: str, subtitle: str, variant: str) -> None:
    width, height = 1242, 2688
    canvas = gradient_image((width, height), '#FFF8F3', '#F3E3DD')
    draw = ImageDraw.Draw(canvas)

    for offset, alpha in ((0, 58), (160, 36), (320, 18)):
        blob = Image.new('RGBA', (width, height), (0, 0, 0, 0))
        blob_draw = ImageDraw.Draw(blob)
        blob_draw.ellipse((660 - offset, -90 + offset, 1360 + offset, 620 + offset), fill=rgba(COLORS['coral'], alpha))
        blob_draw.ellipse((-220, 1700, 520, 2380), fill=rgba(COLORS['gold'], alpha // 2))
        canvas.alpha_composite(blob.filter(ImageFilter.GaussianBlur(50)))

    logo = make_brand_icon().resize((126, 126), Image.Resampling.LANCZOS)
    canvas.alpha_composite(logo, (92, 88))
    draw.text((246, 112), 'PDF Editor Pro', font=TITLE_FONT_SMALL, fill=rgba(COLORS['ink']))
    draw.text((246, 200), 'Mobile document studio', font=SUBTITLE_FONT, fill=rgba(COLORS['muted']))

    text_box = (92, 330)
    wrapped_headline = wrap_text(draw, headline, TITLE_FONT, 1060)
    draw.multiline_text(text_box, wrapped_headline, font=TITLE_FONT, fill=rgba(COLORS['ink']), spacing=8)
    headline_bounds = draw.multiline_textbbox(text_box, wrapped_headline, font=TITLE_FONT, spacing=8)

    subtitle_y = headline_bounds[3] + 56
    wrapped_subtitle = wrap_text(draw, subtitle, SUBTITLE_FONT, 1060)
    draw.multiline_text((96, subtitle_y), wrapped_subtitle, font=SUBTITLE_FONT, fill=rgba(COLORS['slate']), spacing=10)
    subtitle_bounds = draw.multiline_textbbox((96, subtitle_y), wrapped_subtitle, font=SUBTITLE_FONT, spacing=10)

    chips = ['Premium workspace', 'Mobile-ready tools', 'Smooth PDF flow']
    chip_x = 92
    chip_y = subtitle_bounds[3] + 54
    for chip in chips:
        chip_box = draw.textbbox((0, 0), chip, font=CHIP_FONT)
        chip_width = chip_box[2] - chip_box[0] + 48
        draw.rounded_rectangle((chip_x, chip_y, chip_x + chip_width, chip_y + 62), radius=31, fill=rgba(COLORS['white'], 210))
        draw.text((chip_x + 24, chip_y + 11), chip, font=CHIP_FONT, fill=rgba(COLORS['burgundy']))
        chip_x += chip_width + 18

    phone = Image.new('RGBA', (840, 1500), (0, 0, 0, 0))
    phone_draw = ImageDraw.Draw(phone)
    phone_draw.rounded_rectangle((12, 12, 828, 1488), radius=86, fill=rgba(COLORS['ink']))
    phone_draw.rounded_rectangle((32, 32, 808, 1468), radius=72, fill=rgba(COLORS['mist']))
    phone_draw.rounded_rectangle((312, 42, 528, 74), radius=16, fill=rgba('#152C36'))

    if variant == 'home':
        draw_home_preview(phone_draw)
    elif variant == 'tools':
        draw_tools_preview(phone_draw)
    else:
        draw_cloud_preview(phone_draw)

    phone = phone.rotate(-4, resample=Image.Resampling.BICUBIC, expand=True)
    shadow = Image.new('RGBA', phone.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((40, 44, phone.size[0] - 24, phone.size[1] - 28), radius=82, fill=(14, 12, 13, 68))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(shadow, (226, 1016))
    canvas.alpha_composite(phone, (200, 960))

    footer_y = 2480
    footer = rounded_gradient_box((1058, 126), 44, COLORS['crimson'], COLORS['burgundy'])
    canvas.alpha_composite(footer, (92, footer_y))
    draw.text((136, footer_y + 26), 'Edit. Convert. Protect. Sync.', font=BODY_FONT, fill=rgba(COLORS['white']))

    output_path = BRANDING_DIR / file_name
    canvas.save(output_path)


def draw_home_preview(draw: ImageDraw.ImageDraw) -> None:
    draw.text((76, 118), 'PDF Editor Pro', font=BODY_FONT, fill=rgba(COLORS['ink']))
    draw.rounded_rectangle((72, 216, 768, 486), radius=46, fill=rgba(COLORS['crimson']))
    hero_title = wrap_text(draw, 'Professional PDF editing for mobile workflows.', PHONE_TITLE_FONT, 520)
    draw.multiline_text((116, 276), hero_title, font=PHONE_TITLE_FONT, fill=rgba(COLORS['white']), spacing=4)
    draw.text((118, 408), 'Open, annotate, sign, convert, and organize in one place.', font=PHONE_BODY_FONT, fill=rgba(COLORS['white'], 210))
    for x, label in ((74, 'Open PDF'), (292, 'Tool Suite'), (522, 'Cloud Sync')):
        draw.rounded_rectangle((x, 548, x + 182, 624), radius=28, fill=rgba(COLORS['white']))
        draw.text((x + 34, 571), label, font=MICRO_FONT, fill=rgba(COLORS['burgundy']))
    draw.text((78, 698), 'Quick Workspace', font=BODY_FONT, fill=rgba(COLORS['ink']))
    draw.rounded_rectangle((72, 752, 768, 1038), radius=42, fill=rgba(COLORS['white']))
    draw.rounded_rectangle((104, 798, 202, 896), radius=28, fill=rgba(COLORS['rose']))
    draw.text((228, 806), 'Recent PDFs', font=BODY_FONT, fill=rgba(COLORS['ink']))
    draw.text((228, 864), 'Jump back into your latest document sessions.', font=MICRO_FONT, fill=rgba(COLORS['muted']))
    draw.rounded_rectangle((72, 1088, 406, 1362), radius=42, fill=rgba(COLORS['white']))
    draw.rounded_rectangle((434, 1088, 768, 1362), radius=42, fill=rgba(COLORS['white']))
    draw.text((108, 1130), 'Annotate', font=BODY_FONT, fill=rgba(COLORS['ink']))
    draw.text((470, 1130), 'Convert', font=BODY_FONT, fill=rgba(COLORS['ink']))


def draw_tools_preview(draw: ImageDraw.ImageDraw) -> None:
    draw.text((76, 118), 'PDF Tool Suite', font=BODY_FONT, fill=rgba(COLORS['ink']))
    for index, label in enumerate(('All Tools', 'Create', 'Organize', 'Secure')):
        x = 74 + index * 176
        fill = rgba(COLORS['crimson']) if index == 0 else rgba(COLORS['white'])
        text_fill = rgba(COLORS['white']) if index == 0 else rgba(COLORS['ink'])
        draw.rounded_rectangle((x, 210, x + 156, 278), radius=28, fill=fill)
        draw.text((x + 22, 231), label, font=MICRO_FONT, fill=text_fill)
    draw.rounded_rectangle((72, 324, 768, 480), radius=34, fill=rgba(COLORS['white']))
    draw.text((112, 362), 'Everything in one premium document suite.', font=BODY_FONT, fill=rgba(COLORS['ink']))
    draw.text((112, 418), '16 tools', font=MICRO_FONT, fill=rgba(COLORS['muted']))
    tool_cards = [
        ('Image to PDF', 'Studio', COLORS['coral']),
        ('PDF to Images', 'Selectable', COLORS['gold']),
        ('Text to PDF', 'Editor', COLORS['slate']),
        ('Merge PDFs', 'Popular', COLORS['burgundy']),
    ]
    positions = [(72, 540), (430, 540), (72, 902), (430, 902)]
    for (title, badge, color_hex), (x, y) in zip(tool_cards, positions):
        draw.rounded_rectangle((x, y, x + 338, y + 300), radius=42, fill=rgba(COLORS['white']))
        draw.rounded_rectangle((x + 28, y + 28, x + 118, y + 118), radius=24, fill=rgba(color_hex, 54))
        draw.rounded_rectangle((x + 196, y + 34, x + 302, y + 78), radius=20, fill=rgba(color_hex, 42))
        draw.text((x + 214, y + 44), badge, font=MICRO_FONT, fill=rgba(color_hex))
        draw.text((x + 30, y + 168), title, font=BODY_FONT, fill=rgba(COLORS['ink']))
        draw.text((x + 30, y + 222), 'Launch tool', font=MICRO_FONT, fill=rgba(COLORS['burgundy']))


def draw_cloud_preview(draw: ImageDraw.ImageDraw) -> None:
    draw.text((76, 118), 'Cloud Hub', font=BODY_FONT, fill=rgba(COLORS['ink']))
    draw.rounded_rectangle((72, 210, 768, 466), radius=42, fill=rgba(COLORS['ink']))
    hero_title = wrap_text(draw, 'Sync PDFs beautifully across your cloud.', PHONE_TITLE_FONT, 520)
    draw.multiline_text((110, 282), hero_title, font=PHONE_TITLE_FONT, fill=rgba(COLORS['white']), spacing=4)
    draw.text((112, 418), 'Private access with Google Drive and Dropbox.', font=PHONE_BODY_FONT, fill=rgba(COLORS['white'], 210))
    draw.rounded_rectangle((72, 526, 768, 664), radius=34, fill=rgba(COLORS['white']))
    draw.text((110, 564), 'Secure  Upload  Browse', font=BODY_FONT, fill=rgba(COLORS['ink']))
    provider_cards = [('Google Drive', 'Sync PDFs to your app folder.'), ('Dropbox', 'Upload and open synced PDFs.')]
    y = 736
    for title, subtitle in provider_cards:
        draw.rounded_rectangle((72, y, 768, y + 248), radius=38, fill=rgba(COLORS['white']))
        draw.rounded_rectangle((104, y + 44, 206, y + 146), radius=26, fill=rgba(COLORS['rose']))
        draw.text((236, y + 58), title, font=BODY_FONT, fill=rgba(COLORS['ink']))
        draw.text((236, y + 116), subtitle, font=MICRO_FONT, fill=rgba(COLORS['muted']))
        draw.rounded_rectangle((544, y + 72, 720, y + 146), radius=30, fill=rgba(COLORS['rose']))
        draw.text((588, y + 94), 'Connect', font=MICRO_FONT, fill=rgba(COLORS['burgundy']))
        y += 290


def ensure_dirs() -> None:
    BRANDING_DIR.mkdir(parents=True, exist_ok=True)
    ICON_FOREGROUND.parent.mkdir(parents=True, exist_ok=True)


def main() -> None:
    ensure_dirs()

    full_icon = make_brand_icon()
    full_icon.save(BRANDING_DIR / 'pdf_editer_pro_logo.png')
    full_icon.save(BRANDING_DIR / 'pdf_editor_pro_logo.png')
    full_icon.resize((512, 512), Image.Resampling.LANCZOS).save(BRANDING_DIR / 'pdf_editer_pro_store.png')

    foreground = make_foreground_icon(432)
    foreground.save(ICON_FOREGROUND)

    splash = make_foreground_icon(320)
    splash.save(SPLASH_LOGO)

    for directory, size in MIPMAPS.items():
        output_path = RES_DIR / directory / 'ic_launcher.png'
        full_icon.resize((size, size), Image.Resampling.LANCZOS).save(output_path)

    make_store_shot(
        'store_screenshot_01_home.png',
        'Premium PDF workspace\nfor daily mobile editing.',
        'A cleaner home, quicker actions, and a smoother document flow for the work users actually do.',
        'home',
    )
    make_store_shot(
        'store_screenshot_02_tools.png',
        'A powerful tool suite\nwithout the clutter.',
        'Category tabs, richer cards, and a polished PDF workflow that feels fast and focused.',
        'tools',
    )
    make_store_shot(
        'store_screenshot_03_cloud.png',
        'Private cloud sync\nwith a premium feel.',
        'Connect personal storage, browse remote files, and move PDFs between devices with confidence.',
        'cloud',
    )


if __name__ == '__main__':
    main()
