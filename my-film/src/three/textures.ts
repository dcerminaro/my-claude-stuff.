import * as THREE from "three";
import { random } from "remotion";

/**
 * Pixel-art textures generated in code (no image files).
 * Everything uses nearest-neighbour filtering for the crisp block look.
 * Textures are cached, and deterministic thanks to seeded random().
 */
const cache = new Map<string, THREE.CanvasTexture>();

type Draw = (
  ctx: CanvasRenderingContext2D,
  rnd: (k: string | number) => number,
) => void;

export const pixelTexture = (
  key: string,
  w: number,
  h: number,
  draw: Draw,
  repeat?: [number, number],
) => {
  const ck = `${key}:${repeat?.join("x") ?? ""}`;
  const hit = cache.get(ck);
  if (hit) return hit;
  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext("2d")!;
  draw(ctx, (k) => random(`${key}-${k}`));
  const tex = new THREE.CanvasTexture(canvas);
  tex.magFilter = THREE.NearestFilter;
  tex.minFilter = THREE.NearestFilter;
  tex.generateMipmaps = false;
  tex.colorSpace = THREE.SRGBColorSpace;
  if (repeat) {
    tex.wrapS = THREE.RepeatWrapping;
    tex.wrapT = THREE.RepeatWrapping;
    tex.repeat.set(repeat[0], repeat[1]);
  }
  cache.set(ck, tex);
  return tex;
};

const hex = (c: string) => new THREE.Color(c);
const shade = (c: string, k: number) =>
  `#${hex(c).multiplyScalar(k).getHexString()}`;

/** noisy single colour, like a block's surface */
export const noiseTex = (color: string, amount = 0.08, size = 8) =>
  pixelTexture(`noise-${color}-${amount}-${size}`, size, size, (ctx, rnd) => {
    for (let y = 0; y < size; y++)
      for (let x = 0; x < size; x++) {
        ctx.fillStyle = shade(
          color,
          1 - amount + rnd(`${x},${y}`) * amount * 2,
        );
        ctx.fillRect(x, y, 1, 1);
      }
  });

/** wooden floor planks */
export const planksTex = (repeat: [number, number]) =>
  pixelTexture(
    "planks",
    16,
    16,
    (ctx, rnd) => {
      const base = ["#5A3A22", "#62412A", "#523320"];
      for (let row = 0; row < 4; row++) {
        const c = base[row % 3];
        for (let y = 0; y < 4; y++)
          for (let x = 0; x < 16; x++) {
            ctx.fillStyle = shade(c, 0.9 + rnd(`${row}-${x}-${y}`) * 0.2);
            ctx.fillRect(x, row * 4 + y, 1, 1);
          }
        ctx.fillStyle = "#2E1C10";
        ctx.fillRect(0, row * 4 + 3, 16, 1);
        const seam = Math.floor(rnd(`seam${row}`) * 14) + 1;
        ctx.fillRect(seam, row * 4, 1, 3);
      }
    },
    repeat,
  );

/** dark stone-brick wall */
export const wallTex = (repeat: [number, number]) =>
  pixelTexture(
    "wall",
    16,
    16,
    (ctx, rnd) => {
      for (let y = 0; y < 16; y++)
        for (let x = 0; x < 16; x++) {
          ctx.fillStyle = shade("#3A4058", 0.85 + rnd(`${x},${y}`) * 0.3);
          ctx.fillRect(x, y, 1, 1);
        }
      ctx.fillStyle = "#22263A";
      for (let r = 0; r < 4; r++) {
        ctx.fillRect(0, r * 4 + 3, 16, 1);
        const off = r % 2 ? 4 : 0;
        ctx.fillRect((off + 7) % 16, r * 4, 1, 3);
        ctx.fillRect((off + 15) % 16, r * 4, 1, 3);
      }
    },
    repeat,
  );

/** road surface with a dashed centre line */
export const roadTex = (repeat: [number, number]) =>
  pixelTexture(
    "road",
    16,
    16,
    (ctx, rnd) => {
      for (let y = 0; y < 16; y++)
        for (let x = 0; x < 16; x++) {
          ctx.fillStyle = shade("#34343C", 0.8 + rnd(`${x},${y}`) * 0.4);
          ctx.fillRect(x, y, 1, 1);
        }
    },
    repeat,
  );

export const sidewalkTex = (repeat: [number, number]) =>
  pixelTexture(
    "sidewalk",
    16,
    16,
    (ctx, rnd) => {
      for (let y = 0; y < 16; y++)
        for (let x = 0; x < 16; x++) {
          ctx.fillStyle = shade("#6A6A74", 0.88 + rnd(`${x},${y}`) * 0.24);
          ctx.fillRect(x, y, 1, 1);
        }
      ctx.fillStyle = "#44444C";
      ctx.fillRect(0, 15, 16, 1);
      ctx.fillRect(15, 0, 1, 16);
    },
    repeat,
  );

/** building facade; `lit` true returns the window-light (emissive) map */
export const facadeTex = (
  seed: number,
  cols: number,
  rows: number,
  color: string,
  lit: boolean,
) =>
  pixelTexture(
    `facade-${seed}-${cols}-${rows}-${color}-${lit}`,
    cols * 4,
    rows * 4,
    (ctx, rnd) => {
      for (let y = 0; y < rows * 4; y++)
        for (let x = 0; x < cols * 4; x++) {
          ctx.fillStyle = lit
            ? "#000"
            : shade(color, 0.85 + rnd(`${x},${y}`) * 0.3);
          ctx.fillRect(x, y, 1, 1);
        }
      for (let r = 0; r < rows; r++)
        for (let c = 0; c < cols; c++) {
          const on = rnd(`w${c}-${r}`) < 0.32;
          ctx.fillStyle = on ? "#FFD25A" : lit ? "#000" : "#141826";
          ctx.fillRect(c * 4 + 1, r * 4 + 1, 2, 2);
        }
    },
  );

/** soft round glow for light halos (smooth, not pixelated) */
export const glowTex = () => {
  const key = "glow";
  const hit = cache.get(key);
  if (hit) return hit;
  const s = 128;
  const canvas = document.createElement("canvas");
  canvas.width = s;
  canvas.height = s;
  const ctx = canvas.getContext("2d")!;
  const g = ctx.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
  g.addColorStop(0, "rgba(255,255,255,1)");
  g.addColorStop(0.25, "rgba(255,255,255,0.45)");
  g.addColorStop(0.6, "rgba(255,255,255,0.1)");
  g.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, s, s);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  cache.set(key, tex);
  return tex;
};

// ---------- tiny 5x7 pixel font for the phone screen ----------
const GLYPHS: Record<string, string[]> = {
  "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
  "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
  "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
  "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
  ":": ["00000", "00100", "00100", "00000", "00100", "00100", "00000"],
  D: ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
  A: ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
  Y: ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
  " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
};

const drawText = (
  ctx: CanvasRenderingContext2D,
  text: string,
  x: number,
  y: number,
  px: number,
  color: string,
) => {
  ctx.fillStyle = color;
  [...text].forEach((ch, i) => {
    const g = GLYPHS[ch] ?? GLYPHS[" "];
    g.forEach((row, ry) =>
      [...row].forEach((b, rx) => {
        if (b === "1") ctx.fillRect(x + (i * 6 + rx) * px, y + ry * px, px, px);
      }),
    );
  });
};

/** phone screen: big time, day label, bell icon */
export const phoneScreenTex = () =>
  pixelTexture("phone-screen", 48, 96, (ctx) => {
    const g = ctx.createLinearGradient(0, 0, 0, 96);
    g.addColorStop(0, "#DCE8FF");
    g.addColorStop(1, "#8FB0F0");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, 48, 96);
    drawText(ctx, "5:00", 1, 26, 2, "#10131C");
    drawText(ctx, "DAY 2", 10, 48, 1, "#3B3F57");
    // bell
    ctx.fillStyle = "#10131C";
    ctx.fillRect(22, 62, 4, 2);
    ctx.fillRect(20, 64, 8, 4);
    ctx.fillRect(18, 68, 12, 6);
    ctx.fillRect(16, 74, 16, 2);
    ctx.fillRect(22, 77, 4, 2);
  });
