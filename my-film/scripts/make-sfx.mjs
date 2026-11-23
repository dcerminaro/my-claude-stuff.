// Generates every sound effect for the channel from pure maths (oscillators,
// seeded noise and envelopes). No samples or recordings are used, so the
// output is 100% original and safe for YouTube.
//
// Run:  node scripts/make-sfx.mjs
// Output: public/sfx/*.wav (44.1kHz, 16-bit, mono)

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SR = 44100;
const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.join(here, "..", "public", "sfx");
fs.mkdirSync(outDir, { recursive: true });

// ---------- helpers ----------
const mulberry32 = (seed) => () => {
  seed |= 0;
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

const TAU = Math.PI * 2;
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

// one-pole low-pass filter
const lowpass = () => {
  let y = 0;
  return (x, fc) => {
    const a = 1 - Math.exp((-TAU * fc) / SR);
    y += a * (x - y);
    return y;
  };
};

const make = (seconds, fn) => {
  const n = Math.round(seconds * SR);
  const buf = new Float32Array(n);
  for (let i = 0; i < n; i++) buf[i] = fn(i / SR, i);
  return buf;
};

const writeWav = (name, data, gain = 1) => {
  // short fade at both ends to avoid clicks
  const fade = Math.min(64, data.length / 4);
  const pcm = Buffer.alloc(data.length * 2);
  for (let i = 0; i < data.length; i++) {
    let v = data[i] * gain;
    if (i < fade) v *= i / fade;
    if (i > data.length - fade) v *= (data.length - i) / fade;
    v = Math.tanh(v); // soft clip
    pcm.writeInt16LE(Math.round(clamp(v, -1, 1) * 32767), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + pcm.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(SR, 24);
  header.writeUInt32LE(SR * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(pcm.length, 40);
  fs.writeFileSync(path.join(outDir, `${name}.wav`), Buffer.concat([header, pcm]));
  console.log(`wrote public/sfx/${name}.wav`);
};

// ---------- sounds ----------

// pop: bubbly upward blip for rep counters
{
  let ph = 0;
  const rnd = mulberry32(1);
  writeWav(
    "pop",
    make(0.18, (t) => {
      const f = 420 + 760 * (1 - Math.exp(-t * 45));
      ph += (TAU * f) / SR;
      const amp = Math.exp(-t * 26) * Math.min(1, t * 500);
      const click = t < 0.004 ? (rnd() * 2 - 1) * 0.4 : 0;
      return Math.sin(ph) * amp + click;
    }),
    0.8,
  );
}

// whoosh: filtered noise swell for cuts and fast moves
{
  const rnd = mulberry32(2);
  const lpHi = lowpass();
  const lpLo = lowpass();
  const T = 0.5;
  writeWav(
    "whoosh",
    make(T, (t) => {
      const u = t / T;
      const n = rnd() * 2 - 1;
      const fc = 400 + 3200 * Math.sin(Math.PI * u) ** 2;
      const band = lpHi(n, fc) - lpLo(n, fc * 0.25);
      return band * Math.sin(Math.PI * u) ** 2 * 2.6;
    }),
    0.9,
  );
}

// hit: punchy low impact for big moments
{
  let ph = 0;
  const rnd = mulberry32(3);
  const lp = lowpass();
  writeWav(
    "hit",
    make(0.7, (t) => {
      const f = 160 * Math.exp(-t * 9) + 42;
      ph += (TAU * f) / SR;
      const body = Math.sin(ph) * Math.exp(-t * 5.5);
      const crack = lp(rnd() * 2 - 1, 2500) * Math.exp(-t * 45) * 1.6;
      return (body + crack) * 1.8;
    }),
    0.9,
  );
}

// step: soft footstep thump
{
  let ph = 0;
  const rnd = mulberry32(4);
  const lp = lowpass();
  writeWav(
    "step",
    make(0.14, (t) => {
      const f = 100 * Math.exp(-t * 12) + 55;
      ph += (TAU * f) / SR;
      const body = Math.sin(ph) * Math.exp(-t * 32);
      const scuff = lp(rnd() * 2 - 1, 900) * Math.exp(-t * 55) * 0.9;
      return body + scuff;
    }),
    0.9,
  );
}

// type: tiny key click for title letters
{
  const rnd = mulberry32(5);
  const lp = lowpass();
  writeWav(
    "type",
    make(0.06, (t) => {
      const n = rnd() * 2 - 1;
      const hp = n - lp(n, 1800);
      const tick = Math.sin(TAU * 2300 * t) * Math.exp(-t * 140) * 0.35;
      return hp * Math.exp(-t * 160) + tick;
    }),
    0.7,
  );
}

// alarm: two quick phone beeps
{
  writeWav(
    "alarm",
    make(0.32, (t) => {
      const on = (t > 0 && t < 0.1) || (t > 0.16 && t < 0.26);
      if (!on) return 0;
      const local = t < 0.13 ? t : t - 0.16;
      const env = Math.min(1, local * 300) * Math.min(1, (0.1 - local) * 300);
      return Math.tanh(4 * Math.sin(TAU * 1046 * t)) * 0.35 * env;
    }),
    0.8,
  );
}

// drone: dark, wobbling swell for the shadow
{
  const rnd = mulberry32(6);
  const lp = lowpass();
  const T = 2.6;
  const freqs = [49, 49.7, 73.4, 98.6];
  const phases = freqs.map(() => 0);
  writeWav(
    "drone",
    make(T, (t) => {
      const bend = 1 - 0.04 * t;
      let s = 0;
      freqs.forEach((f, i) => {
        phases[i] += (TAU * f * bend) / SR;
        s += Math.sin(phases[i]) + 0.3 * Math.sin(2 * phases[i]);
      });
      s /= freqs.length;
      const trem = 1 + 0.35 * Math.sin(TAU * 3.2 * t);
      const env = Math.min(1, t / 0.7) * Math.min(1, (T - t) / 0.9);
      const breath = lp(rnd() * 2 - 1, 350) * 1.5;
      return (s * trem + breath) * env * 1.3;
    }),
    0.9,
  );
}

// shimmer: rising sparkle for the title underline
{
  const notes = [1046.5, 1318.5, 1568, 2093];
  const T = 1.1;
  writeWav(
    "shimmer",
    make(T, (t) => {
      let s = 0;
      notes.forEach((f, i) => {
        const t0 = i * 0.07;
        if (t < t0) return;
        const lt = t - t0;
        const env = Math.min(1, lt * 400) * Math.exp(-lt * 4.5);
        s += (Math.sin(TAU * f * lt) + 0.25 * Math.sin(TAU * 2 * f * lt)) * env;
      });
      return s * 0.3;
    }),
    0.8,
  );
}

// hum: quiet electric room tone (loops seamlessly: whole cycles in 3s)
{
  writeWav(
    "hum",
    make(3, (t) => {
      return (
        0.5 * Math.sin(TAU * 60 * t) +
        0.3 * Math.sin(TAU * 120 * t) +
        0.12 * Math.sin(TAU * 180 * t)
      ) * 0.3;
    }),
    1,
  );
}
