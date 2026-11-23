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

// ---------- full alphabet for the chalkboard ----------
Object.assign(GLYPHS, {
  B: ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
  C: ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
  E: ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
  F: ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
  G: ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
  H: ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
  I: ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
  J: ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
  K: ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
  L: ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
  M: ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
  N: ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
  O: ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
  P: ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
  Q: ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
  R: ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
  S: ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
  T: ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
  U: ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
  V: ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
  W: ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
  X: ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
  Z: ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
  "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
  "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
  "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
  "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
  "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
  "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
  "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
  ".": ["00000", "00000", "00000", "00000", "00000", "00000", "00100"],
  "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
  "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
  "%": ["11001", "11010", "00010", "00100", "01000", "01011", "10011"],
  "=": ["00000", "00000", "11111", "00000", "11111", "00000", "00000"],
  "?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
});

/** wooden ruler with tick marks */
export const rulerTex = () =>
  pixelTexture("ruler", 4, 32, (ctx, rnd) => {
    for (let y = 0; y < 32; y++)
      for (let x = 0; x < 4; x++) {
        ctx.fillStyle = shade("#D2A866", 0.9 + rnd(`${x},${y}`) * 0.2);
        ctx.fillRect(x, y, 1, 1);
      }
    ctx.fillStyle = "#5A3A1A";
    for (let y = 1; y < 32; y += 2) ctx.fillRect(0, y, y % 8 === 1 ? 2 : 1, 1);
  });

/** light wooden desk top */
export const deskTex = () =>
  pixelTexture("desk", 16, 16, (ctx, rnd) => {
    for (let y = 0; y < 16; y++)
      for (let x = 0; x < 16; x++) {
        const grain = Math.sin(y * 1.3 + Math.sin(x * 0.4) * 2) * 0.06;
        ctx.fillStyle = shade("#8A5A32", 0.9 + grain + rnd(`${x},${y}`) * 0.12);
        ctx.fillRect(x, y, 1, 1);
      }
  });

/** painted classroom wall: dark teal plaster blocks */
export const classWallTex = (repeat: [number, number]) =>
  pixelTexture(
    "classwall",
    16,
    16,
    (ctx, rnd) => {
      for (let y = 0; y < 16; y++)
        for (let x = 0; x < 16; x++) {
          ctx.fillStyle = shade("#2E4A4A", 0.88 + rnd(`${x},${y}`) * 0.24);
          ctx.fillRect(x, y, 1, 1);
        }
      ctx.fillStyle = "#223838";
      ctx.fillRect(0, 15, 16, 1);
      ctx.fillRect(15, 0, 1, 16);
    },
    repeat,
  );

/** classroom floor: checker tiles */
export const tileFloorTex = (repeat: [number, number]) =>
  pixelTexture(
    "tilefloor",
    16,
    16,
    (ctx, rnd) => {
      for (let y = 0; y < 16; y++)
        for (let x = 0; x < 16; x++) {
          const dark = (Math.floor(x / 8) + Math.floor(y / 8)) % 2 === 0;
          ctx.fillStyle = shade(
            dark ? "#3C3A44" : "#57535E",
            0.9 + rnd(`${x},${y}`) * 0.2,
          );
          ctx.fillRect(x, y, 1, 1);
        }
    },
    repeat,
  );

/**
 * Chalkboard with chalky pixel writing. `lines` are drawn top to bottom;
 * `draw` can add simple diagrams (in board pixels, 128 x 64).
 */
export const chalkboardTex = (
  key: string,
  lines: { text: string; x: number; y: number; px?: number; color?: string }[],
  draw?: (
    ctx: CanvasRenderingContext2D,
    rnd: (k: string | number) => number,
  ) => void,
) =>
  pixelTexture(`board-${key}`, 128, 64, (ctx, rnd) => {
    for (let y = 0; y < 64; y++)
      for (let x = 0; x < 128; x++) {
        ctx.fillStyle = shade("#1F3A2C", 0.85 + rnd(`${x},${y}`) * 0.25);
        ctx.fillRect(x, y, 1, 1);
      }
    // old smudges
    ctx.fillStyle = "rgba(255,255,255,0.05)";
    for (let i = 0; i < 6; i++)
      ctx.fillRect(rnd(`sx${i}`) * 110, rnd(`sy${i}`) * 55, 18, 5);
    lines.forEach((l) =>
      drawText(ctx, l.text, l.x, l.y, l.px ?? 1, l.color ?? "#ECECE4"),
    );
    draw?.(ctx, rnd);
  });
