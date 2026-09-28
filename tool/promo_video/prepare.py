"""Turns the frames written by test/video_screens_test.dart into the
assets scene.html expects (img/, fonts/, icon.png).

    python3 tool/promo_video/prepare.py <frames-dir>
"""
import os
import shutil
import sys

from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(os.path.dirname(here))
frames = sys.argv[1]

os.makedirs(f'{here}/img', exist_ok=True)
for name in os.listdir(frames):
    if not name.endswith('.png'):
        continue
    im = Image.open(f'{frames}/{name}').convert('RGB')
    if name.startswith('v22-share-card'):
        im.save(f'{here}/img/share.jpg', quality=94)
    else:
        im.resize((720, 1560), Image.LANCZOS).save(f'{here}/img/{name[:-4]}.jpg', quality=92)

os.makedirs(f'{here}/fonts', exist_ok=True)
for w in ['Regular', 'Medium', 'Semibold', 'Bold']:
    shutil.copy(f'{root}/assets/fonts/DiodrumArabic-{w}.ttf', f'{here}/fonts/')
shutil.copy(
    f'{root}/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    f'{here}/icon.png',
)
