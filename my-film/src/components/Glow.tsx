import React from "react";
import { useLook } from "../looks";
import { useSvgId } from "./util";

/** Big soft light glow. Blocky look uses stepped bands of light instead. */
export const Glow: React.FC<{
  x: number;
  y: number;
  r: number;
  ry?: number;
  color: string;
  opacity?: number;
}> = ({ x, y, r, ry, color, opacity = 0.5 }) => {
  const id = useSvgId("glow");
  const look = useLook();
  const o = opacity * look.glowScale;
  const rY = ry ?? r;

  if (look.grid) {
    const G = 24;
    const bands = 5;
    return (
      <g style={{ mixBlendMode: "screen" }} shapeRendering="crispEdges">
        {Array.from({ length: bands }, (_, i) => {
          const k = (bands - i) / bands;
          const w = Math.max(G, Math.round((r * k) / G) * G);
          const h = Math.max(G / 2, Math.round((rY * k) / G) * G);
          return (
            <rect
              key={i}
              x={x - w}
              y={y - h}
              width={w * 2}
              height={h * 2}
              fill={color}
              opacity={o * 0.32 * (i === 0 ? 0.6 : 1)}
            />
          );
        })}
      </g>
    );
  }

  return (
    <g style={{ mixBlendMode: look.glowBlend }}>
      <defs>
        <radialGradient id={id}>
          <stop offset="0" stopColor={color} stopOpacity={o} />
          <stop offset="0.3" stopColor={color} stopOpacity={o * 0.45} />
          <stop offset="0.65" stopColor={color} stopOpacity={o * 0.12} />
          <stop offset="1" stopColor={color} stopOpacity={0} />
        </radialGradient>
      </defs>
      <ellipse cx={x} cy={y} rx={r} ry={rY} fill={`url(#${id})`} />
    </g>
  );
};
