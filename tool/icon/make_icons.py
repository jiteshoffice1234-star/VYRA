from PIL import Image
import os

SRC = "tool/icon/waze_logo.png"
RES = "android/app/src/main/res"

# Android launcher icon sizes per density bucket.
DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

im = Image.open(SRC).convert("RGBA")
w, h = im.size

# Center-crop to a square.
side = min(w, h)
left = (w - side) // 2
top = (h - side) // 2
square = im.crop((left, top, left + side, top + side))

# Launcher icons are masked (circle / squircle), so keep the logo inside a
# ~76% safe zone: 12% padding on each side.
for folder, size in DENSITIES.items():
    target = int(size * 0.76)
    resized = square.resize((target, target), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = (size - target) // 2
    canvas.paste(resized, (offset, offset))
    out_path = os.path.join(RES, folder, "ic_launcher.png")
    canvas.save(out_path)
    print("wrote", out_path, canvas.size)
