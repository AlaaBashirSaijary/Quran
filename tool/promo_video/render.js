// node render.js <landscape|portrait> <outDir>
// Renders every frame of scene.html at 30 fps with 4 parallel pages.
const { chromium } = require(process.env.PW);
const fs = require('fs');
const mode = process.argv[2], out = process.argv[3];
const FPS = 30, WORKERS = 4;
const size = mode === 'portrait' ? { width: 1080, height: 1920 } : { width: 1920, height: 1080 };
(async () => {
  fs.mkdirSync(out, { recursive: true });
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const probe = await b.newPage({ viewport: size });
  await probe.goto('http://localhost:8795/scene.html?mode=' + mode);
  const total = await probe.evaluate(() => TOTAL);
  await probe.close();
  const frames = Math.floor(total * FPS);
  console.log('frames', frames);
  let next = 0, done = 0;
  await Promise.all(Array.from({ length: WORKERS }, async () => {
    const p = await b.newPage({ viewport: size });
    await p.goto('http://localhost:8795/scene.html?mode=' + mode);
    await p.evaluate(() => document.fonts.ready);
    for (;;) {
      const i = next++;
      if (i >= frames) break;
      await p.evaluate(t => renderAt(t), i / FPS);
      await p.screenshot({ path: `${out}/f${String(i).padStart(5, '0')}.jpg`, type: 'jpeg', quality: 92 });
      if (++done % 300 === 0) console.log('done', done);
    }
  }));
  await b.close();
  console.log('finished');
})();
