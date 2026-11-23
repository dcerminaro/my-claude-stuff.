import React from "react";
import {
  AbsoluteFill,
  interpolate,
  random,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { useLook } from "../looks";

/** Radial speed lines for big hits. Use inside a <Sequence>. */
export const SpeedLines: React.FC<{
  cx: number;
  cy: number;
  count?: number;
}> = ({ cx, cy, count = 32 }) => {
  const f = useCurrentFrame();
  const look = useLook();
  const { durationInFrames, width: W, height: H } = useVideoConfig();
  const p = f / durationInFrames;
  const o = interpolate(p, [0, 0.15, 0.7, 1], [0, 1, 0.8, 0]);
  return (
    <AbsoluteFill>
      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`}>
        <g filter={look.lineFilter ? `url(#${look.lineFilter})` : undefined}>
          {Array.from({ length: count }, (_, i) => {
            const a = (i / count) * Math.PI * 2 + random(`a${i}`) * 0.15;
            const r0 = 230 + random(`r${i}`) * 140 + p * 160;
            const r1 = r0 + 300 + random(`l${i}`) * 500;
            const w = (2 + random(`w${i}`) * 6) * (look.grid ? 2.5 : 1);
            return (
              <line
                key={i}
                x1={cx + Math.cos(a) * r0}
                y1={cy + Math.sin(a) * r0}
                x2={cx + Math.cos(a) * r1}
                y2={cy + Math.sin(a) * r1}
                stroke={look.speed}
                strokeWidth={w}
                strokeLinecap={look.grid ? "butt" : "round"}
                opacity={o * (0.5 + 0.5 * random(`o${i}`))}
              />
            );
          })}
        </g>
      </svg>
    </AbsoluteFill>
  );
};

/** White flash for impacts. Use inside a short <Sequence>. */
export const Flash: React.FC<{ strength?: number }> = ({ strength = 0.85 }) => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const o = interpolate(f, [0, durationInFrames], [strength, 0], {
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill
      style={{ background: "#fff", opacity: o, mixBlendMode: "screen" }}
    />
  );
};
