import { useId } from "react";

export const clamp = (v: number, a: number, b: number) =>
  Math.min(b, Math.max(a, v));
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/** SVG-safe unique id */
export const useSvgId = (prefix: string) =>
  `${prefix}-${useId().replace(/[^a-zA-Z0-9]/g, "")}`;

type Pt = [number, number];

/** Wobbly hand-drawn path through a polygon. Moves smoothly every frame. */
export const wobblePath = (
  pts: Pt[],
  frame: number,
  seed = 0,
  amp = 1.6,
  closed = true,
  step = 26,
) => {
  const out: Pt[] = [];
  const n = pts.length;
  const edges = closed ? n : n - 1;
  for (let e = 0; e < edges; e++) {
    const [x1, y1] = pts[e];
    const [x2, y2] = pts[(e + 1) % n];
    const segs = Math.max(1, Math.round(Math.hypot(x2 - x1, y2 - y1) / step));
    for (let s = 0; s < segs; s++) {
      const t = s / segs;
      out.push([x1 + (x2 - x1) * t, y1 + (y2 - y1) * t]);
    }
  }
  if (!closed) out.push(pts[n - 1]);
  const d = out
    .map(([x, y], i) => {
      const k = i * 1.37 + seed * 7.13;
      const ox =
        amp * Math.sin(frame * 0.11 + k) +
        amp * 0.5 * Math.sin(frame * 0.23 + k * 2.3);
      const oy =
        amp * Math.cos(frame * 0.13 + k * 1.9) +
        amp * 0.5 * Math.cos(frame * 0.19 + k * 3.1);
      return `${i ? "L" : "M"}${(x + ox).toFixed(1)} ${(y + oy).toFixed(1)}`;
    })
    .join(" ");
  return closed ? d + " Z" : d;
};

export const rectPts = (x: number, y: number, w: number, h: number): Pt[] => [
  [x, y],
  [x + w, y],
  [x + w, y + h],
  [x, y + h],
];

export const roundRectPts = (
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
  seg = 5,
): Pt[] => {
  const pts: Pt[] = [];
  const corners: [number, number, number][] = [
    [x + w - r, y + r, -Math.PI / 2],
    [x + w - r, y + h - r, 0],
    [x + r, y + h - r, Math.PI / 2],
    [x + r, y + r, Math.PI],
  ];
  for (const [cx, cy, a0] of corners) {
    for (let i = 0; i <= seg; i++) {
      const a = a0 + (i / seg) * (Math.PI / 2);
      pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
    }
  }
  return pts;
};

export const circlePts = (cx: number, cy: number, r: number, n = 24): Pt[] =>
  Array.from({ length: n }, (_, i) => {
    const a = (i / n) * Math.PI * 2;
    return [cx + r * Math.cos(a), cy + r * Math.sin(a)] as Pt;
  });
