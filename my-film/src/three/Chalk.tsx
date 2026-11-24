import React from "react";
import { BOARD } from "./Classroom";

/** board pixel (0..128, 0..64) -> world position on the chalkboard surface */
export const boardPos = (
  px: number,
  py: number,
  lift = 0.04,
): [number, number, number] => {
  const k = BOARD.w / 128;
  return [
    BOARD.x - BOARD.w / 2 + px * k,
    BOARD.y + BOARD.h / 2 - py * k,
    BOARD.z + lift,
  ];
};

/**
 * A chalk line drawn through board-pixel points, revealed from start to
 * end as `p` goes 0 -> 1 (constant drawing speed along the line).
 */
export const ChalkLine: React.FC<{
  pts: [number, number][];
  p: number;
  color?: string;
  width?: number; // world units
}> = ({ pts, p, color = "#F2F2EA", width = 0.07 }) => {
  const segs = pts.slice(1).map((b, i) => {
    const a = boardPos(...pts[i]);
    const c = boardPos(...b);
    return { a, c, len: Math.hypot(c[0] - a[0], c[1] - a[1]) };
  });
  const total = segs.reduce((n, s) => n + s.len, 0);
  let drawn = Math.max(0, Math.min(1, p)) * total;
  return (
    <group>
      {segs.map((s, i) => {
        const k = Math.max(0, Math.min(1, drawn / s.len));
        drawn -= s.len;
        if (k <= 0) return null;
        const ex = s.a[0] + (s.c[0] - s.a[0]) * k;
        const ey = s.a[1] + (s.c[1] - s.a[1]) * k;
        const len = s.len * k;
        const ang = Math.atan2(ey - s.a[1], ex - s.a[0]);
        return (
          <mesh
            key={i}
            position={[
              (s.a[0] + ex) / 2,
              (s.a[1] + ey) / 2,
              s.a[2] + 0.001 * i,
            ]}
            rotation={[0, 0, ang]}
          >
            <boxGeometry args={[len + width * 0.6, width, 0.01]} />
            <meshBasicMaterial color={color} toneMapped={false} />
          </mesh>
        );
      })}
    </group>
  );
};

/** a chalk arrow from `a` to `b` (board pixels), drawn as `p` goes 0 -> 1 */
export const ChalkArrow: React.FC<{
  a: [number, number];
  b: [number, number];
  p: number;
  color?: string;
  head?: number; // arrowhead length in board pixels
}> = ({ a, b, p, color, head = 4 }) => {
  const ang = Math.atan2(b[1] - a[1], b[0] - a[0]);
  const h1: [number, number] = [
    b[0] - head * Math.cos(ang - 0.6),
    b[1] - head * Math.sin(ang - 0.6),
  ];
  const h2: [number, number] = [
    b[0] - head * Math.cos(ang + 0.6),
    b[1] - head * Math.sin(ang + 0.6),
  ];
  const shaft = Math.min(1, p / 0.8);
  const tip = Math.max(0, (p - 0.8) / 0.2);
  return (
    <group>
      <ChalkLine pts={[a, b]} p={shaft} color={color} />
      <ChalkLine pts={[b, h1]} p={tip} color={color} />
      <ChalkLine pts={[b, h2]} p={tip} color={color} />
    </group>
  );
};
