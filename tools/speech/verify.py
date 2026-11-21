"""Checks the exported model by transcribing real recitations and comparing
with the Quran text of the app.

    python tools/speech/verify.py ENCODER DECODER TOKENS

The recitations are ayahs read by Alafasy (the audio the app plays), so the
model is tried with the same engine the app will use (sherpa-onnx). Exits
with an error if the words come out too wrong.
"""
import re
import subprocess
import sys
import tempfile
import urllib.request

import sherpa_onnx
import soundfile as sf

QURAN = "assets/quran_text.txt"
AUDIO = "https://cdn.islamic.network/quran/audio/128/ar.alafasy/{n}.mp3"

# (surah, ayah) and the number of that ayah in the whole Quran.
SAMPLES = [
    (1, 2, 2), (1, 4, 4), (1, 6, 6), (1, 7, 7),
    (112, 1, 6222), (112, 2, 6223), (112, 3, 6224),
    (113, 1, 6226), (114, 1, 6231), (114, 3, 6233), (114, 6, 6236),
]

MARKS = re.compile("[ؐ-ًؚ-ٟۖ-ۤۨ-ۭـ]")
ALEFS = re.compile("[ءآأإاٱ]")


def norm(word: str) -> str:
    word = MARKS.sub("", word)
    word = word.replace("وٰ", "").replace("ٰ", "").replace("ۥ", "")
    word = re.sub("[ۦۧ]", "ي", word)
    word = ALEFS.sub("", word)
    word = word.replace("ى", "ي").replace("ة", "ه")
    word = word.replace("ؤ", "و").replace("ئ", "ي")
    return re.sub(r"[^؀-ۿ]", "", word)


def words(text: str):
    return [w for w in (norm(x) for x in text.split()) if w]


def similarity(expected, heard):
    """1 minus the word error rate (edit distance over words)."""
    n, m = len(expected), len(heard)
    d = list(range(m + 1))
    for i in range(1, n + 1):
        prev, d[0] = d[0], i
        for j in range(1, m + 1):
            cur = min(d[j] + 1, d[j - 1] + 1, prev + (expected[i - 1] != heard[j - 1]))
            prev, d[j] = d[j], cur
    return max(0.0, 1 - d[m] / max(1, n))


def transcribe_all(encoder, decoder, tokens, wavs, ayahs):
    recognizer = sherpa_onnx.OfflineRecognizer.from_whisper(
        encoder=encoder, decoder=decoder, tokens=tokens,
        language="ar", task="transcribe", num_threads=2,
    )
    scores = []
    for (surah, ayah, _n), wav in zip(SAMPLES, wavs):
        samples, rate = sf.read(wav, dtype="float32")
        stream = recognizer.create_stream()
        stream.accept_waveform(rate, samples)
        recognizer.decode_stream(stream)
        heard = stream.result.text.strip()
        expected = words(ayahs[(surah, ayah)])
        score = similarity(expected, words(heard))
        scores.append(score)
        print(f"  {surah}:{ayah}  {score:.2f}  heard: {' '.join(words(heard))}")
    return scores


def main() -> int:
    tokens = sys.argv[1]
    candidates = []  # (name, encoder, decoder, selectable)
    for arg in sys.argv[2:]:
        name, files = arg.split("=", 1)
        encoder, decoder = files.split(",")
        candidates.append((name.removeprefix("diag:"), encoder, decoder, not name.startswith("diag:")))
    ayahs = {}
    for line in open(QURAN, encoding="utf8"):
        if line.strip():
            s, a, _page, text = line.rstrip("\n").split("|", 3)
            ayahs[(int(s), int(a))] = text
    tmp = tempfile.mkdtemp()
    wavs = []
    for _surah, _ayah, n in SAMPLES:
        mp3, wav = f"{tmp}/{n}.mp3", f"{tmp}/{n}.wav"
        urllib.request.urlretrieve(AUDIO.format(n=n), mp3)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", mp3, "-ar", "16000", "-ac", "1", wav], check=True)
        wavs.append(wav)
    chosen = None
    for name, encoder, decoder, selectable in candidates:
        print(f"== {name}")
        try:
            scores = transcribe_all(encoder, decoder, tokens, wavs, ayahs)
        except Exception as error:  # a model that does not run is a result too
            print(f"  failed to run: {error}")
            continue
        mean = sum(scores) / len(scores)
        ok = mean >= 0.85 and min(scores) >= 0.6
        print(f"  mean {mean:.3f}  min {min(scores):.2f}  {'passes' if ok else 'does not pass'}")
        if ok and selectable and chosen is None:
            chosen = name
    if chosen is None:
        print("No model that can be published recites well enough.", file=sys.stderr)
        return 1
    open("chosen.txt", "w").write(chosen)
    print("chosen:", chosen)
    return 0


if __name__ == "__main__":
    sys.exit(main())
