from PIL import Image
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'icon', 'app_icon.png')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

SIZES = {
    'drawable-mdpi': 24,
    'drawable-hdpi': 36,
    'drawable-xhdpi': 48,
    'drawable-xxhdpi': 72,
    'drawable-xxxhdpi': 96,
}


def is_logo_pixel(r, g, b, a):
    if a < 20:
        return False
    if r > 235 and g > 235 and b > 235:
        return False
    return True


def load_logo(size):
    img = Image.open(SRC).convert('RGBA')
    return img.resize((size, size), Image.Resampling.LANCZOS)


def save_silhouette(size, folder):
    src = load_logo(size)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    src_px = src.load()
    out_px = out.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = src_px[x, y]
            if is_logo_pixel(r, g, b, a):
                out_px[x, y] = (255, 255, 255, 255)
    path = os.path.join(RES, folder)
    os.makedirs(path, exist_ok=True)
    out.save(os.path.join(path, 'ic_notification.png'), 'PNG')


def save_color_icon(size, folder, name):
    src = load_logo(size)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    src_px = src.load()
    out_px = out.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = src_px[x, y]
            if is_logo_pixel(r, g, b, a):
                out_px[x, y] = (r, g, b, 255)
    path = os.path.join(RES, folder)
    os.makedirs(path, exist_ok=True)
    out.save(os.path.join(path, f'{name}.png'), 'PNG')


if __name__ == '__main__':
    for folder, size in SIZES.items():
        save_silhouette(size, folder)
        save_color_icon(size, folder, 'ic_notification_color')

    save_color_icon(256, 'drawable', 'ic_notification_large')
    print('Generated notification icons from app_icon.png')
