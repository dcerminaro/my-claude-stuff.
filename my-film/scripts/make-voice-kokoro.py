"""
Free voiceover for Caesar using Kokoro (open-source, Apache 2.0, commercial
use allowed), with word timings from Whisper (faster-whisper, MIT).

Run (from my-film/):
  .venv-voice/bin/python scripts/make-voice-kokoro.py voice/<film-id>.json
  .venv-voice/bin/python scripts/make-voice-kokoro.py --samples "Some line" bm_george bm_fable ...

Writes: public/voice/<film-id>/<line-id>.wav and src/voice/<film-id>.ts
(the same timing format as scripts/make-voice.mjs, so films don't change).

One-time setup (see CLAUDE.md "Voice"):
  python3 -m venv .venv-voice
  .venv-voice/bin/pip install kokoro-onnx soundfile faster-whisper
  model files in .voice-models/ (kokoro-v1.0.onnx, voices-v1.0.bin)
"""

import difflib
import json
import os
import sys
from pathlib import Path

os.environ.setdefault("HF_HUB_DISABLE_XET", "1")  # plain HTTP downloads through the proxy

import numpy as np
import soundfile as sf
from faster_whisper import WhisperModel
from kokoro_onnx import Kokoro

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / ".voice-models"

_kokoro = None
_whisper = None


def kokoro():
    global _kokoro
    if _kokoro is None:
        _kokoro = Kokoro(str(MODELS / "kokoro-v1.0.onnx"), str(MODELS / "voices-v1.0.bin"))
    return _kokoro


def whisper():
    global _whisper
    if _whisper is None:
        _whisper = WhisperModel("base.en", device="cpu", compute_type="int8", download_root=str(MODELS / "whisper"))
    return _whisper


def speak(text, voice, speed, out_path):
    samples, sr = kokoro().create(text, voice=voice, speed=speed, lang="en-gb")
    sf.write(str(out_path), samples, sr)
    return len(samples) / sr


def char_timings(text, audio_path, duration):
    """Exact-ish start/end time for every character of `text`."""
    audio, sr = sf.read(str(audio_path), dtype="float32")
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    # resample to Whisper's 16 kHz
    n = int(len(audio) * 16000 / sr)
    audio16 = np.interp(np.linspace(0, len(audio) - 1, n), np.arange(len(audio)), audio).astype(np.float32)
    segments, _ = whisper().transcribe(audio16, word_timestamps=True, language="en")
    w_letters, w_times = [], []
    for seg in segments:
        for w in seg.words or []:
            letters = [c for c in w.word.lower() if c.isalnum()]
            for i, c in enumerate(letters):
                w_letters.append(c)
                w_times.append(w.start + (i + 0.5) / len(letters) * (w.end - w.start))

    s_idx = [i for i, c in enumerate(text) if c.isalnum()]
    s_letters = [text[i].lower() for i in s_idx]
    times = [None] * len(s_idx)
    sm = difflib.SequenceMatcher(None, s_letters, w_letters, autojunk=False)
    for a, b, n in sm.get_matching_blocks():
        for k in range(n):
            times[a + k] = w_times[b + k]

    # fill gaps (numbers spoken as words, etc.) by linear interpolation
    first = w_times[0] if w_times else 0.05
    last = w_times[-1] if w_times else duration - 0.1
    known = [(i, t) for i, t in enumerate(times) if t is not None] or [(0, first), (len(times) - 1, last)]
    if known[0][0] != 0:
        known.insert(0, (0, min(first, known[0][1])))
    if known[-1][0] != len(times) - 1:
        known.append((len(times) - 1, max(last, known[-1][1])))
    for (i0, t0), (i1, t1) in zip(known, known[1:]):
        for i in range(i0, i1 + 1):
            if times[i] is None:
                times[i] = t0 + (t1 - t0) * (i - i0) / max(1, i1 - i0)

    # keep monotonic
    for i in range(1, len(times)):
        times[i] = max(times[i], times[i - 1] + 0.01)

    chars = []
    letter_k = 0
    prev_end = times[0] - 0.04 if times else 0.0
    for i, c in enumerate(text):
        if c.isalnum():
            t = times[letter_k]
            nxt = times[letter_k + 1] if letter_k + 1 < len(times) else t + 0.08
            start = t - 0.035
            end = min(nxt - 0.035, t + 0.12)
            letter_k += 1
        else:
            start = prev_end
            end = prev_end + (0.02 if c == " " else 0.06)
        start, end = round(max(0.0, start), 3), round(max(start + 0.01, end), 3)
        chars.append([c, start, end])
        prev_end = end
    return chars


def to_words(chars):
    words, cur = [], None
    for c, s, e in chars:
        if c == " ":
            if cur:
                words.append(cur)
            cur = None
            continue
        if cur is None:
            cur = {"text": "", "start": s, "end": e}
        cur["text"] += c
        cur["end"] = e
    if cur:
        words.append(cur)
    return words


def samples(text, voices):
    out = ROOT / "out" / "voice-samples"
    out.mkdir(parents=True, exist_ok=True)
    for v in voices:
        p = out / f"{v}.wav"
        d = speak(text, v, 0.95, p)
        print(f"{p.relative_to(ROOT)}  {d:.2f}s")


def main():
    args = sys.argv[1:]
    if args and args[0] == "--samples":
        samples(args[1], args[2:])
        return
    script_path = args[0]
    script = json.loads((ROOT / script_path).read_text())
    film = script["film"]
    voice = script.get("kokoroVoice", "bm_george")
    speed = script.get("kokoroSpeed", 0.95)
    out_dir = ROOT / "public" / "voice" / film
    out_dir.mkdir(parents=True, exist_ok=True)

    lines = []
    for line in script["lines"]:
        text = line.get("say", line["text"])  # "say" lets pronunciation differ from subtitles
        wav = out_dir / f"{line['id']}.wav"
        dur = speak(text, voice, line.get("speed", speed), wav)
        chars = char_timings(line["text"], wav, dur)
        lines.append(
            {
                "id": line["id"],
                "text": line["text"],
                "src": f"voice/{film}/{line['id']}.wav",
                "duration": round(dur, 3),
                "chars": chars,
                "words": to_words(chars),
            }
        )
        print(f"voiced {line['id']} ({dur:.2f}s): {line['text']}")

    track = {"film": film, "placeholder": False, "voiceId": f"kokoro:{voice}", "lines": lines}
    ts = (
        f"// Generated by scripts/make-voice-kokoro.py from {script_path}. Do not edit by hand.\n"
        'import type { VoiceTrack } from "./types";\n\n'
        f"export const voice: VoiceTrack = {json.dumps(track, indent=2)};\n"
    )
    out_ts = ROOT / "src" / "voice" / f"{film}.ts"
    out_ts.write_text(ts)
    print(f"wrote {out_ts.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
