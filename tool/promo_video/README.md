# Promo video

The app tour video (about two minutes, no sound). The pictures are screens
the app draws itself, so the video can be re-made after any change.

1. Render the screens (any empty folder):

   ```bash
   VIDEO_FRAMES=/tmp/frames TZ=Asia/Riyadh flutter test test/video_screens_test.dart
   ```

2. Turn them into the scene's assets, then serve this folder:

   ```bash
   python3 tool/promo_video/prepare.py /tmp/frames
   cd tool/promo_video && python3 -m http.server 8795
   ```

3. Render every frame (30 fps, four parallel pages) for each shape, with
   Playwright installed (`PW` is the path to its package):

   ```bash
   PW=/path/to/playwright node render.js landscape /tmp/fr-land   # 1920x1080
   PW=/path/to/playwright node render.js portrait  /tmp/fr-port   # 1080x1920
   ```

4. Encode:

   ```bash
   ffmpeg -framerate 30 -i /tmp/fr-land/f%05d.jpg -c:v libx264 -preset slow \
     -crf 25 -pix_fmt yuv420p -movflags +faststart -an promo.mp4
   ```

The texts and timing are in `SCENES` at the top of the script in
`scene.html`. `img/`, `fonts/` and `icon.png` are generated and not
committed.
