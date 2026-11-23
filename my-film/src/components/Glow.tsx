import React from "react";
import { useSvgId } from "./util";

/** Big soft light glow (SVG). Additive "screen" blending. */
export const Glow: React.FC<{
  x: number;
  y: number;
  r: number;
  ry?: number;
  color: string;
  opacity?: number;
}> = ({ x, y, r, ry, color, opacity = 0.5 }) => {
  const id = useSvgId("glow");
  return (
    <g style={{ mixBlendMode: "screen" }}>
      <defs>
        <radialGradient id={id}>
          <stop offset="0" stopColor={color} stopOpacity={opacity} />
          <stop offset="0.3" stopColor={color} stopOpacity={opacity * 0.45} />
          <stop offset="0.65" stopColor={color} stopOpacity={opacity * 0.12} />
          <stop offset="1" stopColor={color} stopOpacity={0} />
        </radialGradient>
      </defs>
      <ellipse cx={x} cy={y} rx={r} ry={ry ?? r} fill={`url(#${id})`} />
    </g>
  );
};
