import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { comic } from "../fonts";
import { C } from "../theme";
import { Sfx } from "./Sfx";
import { useSvgId } from "./util";

/**
 * End title card. Normally the last 12 seconds (360 frames).
 * The word types on letter by letter, a wavy accent underline draws in,
 * then a white line, then a short accent line, then fade to black.
 * Timings are in frames from the start of the card.
 */
export const TitleCard: React.FC<{
  word: string;
  line1: string;
  line2: string;
  startAt?: number;
  letterEvery?: number;
  underlineAt?: number;
  underlineFrames?: number;
  line1At?: number;
  line2At?: number;
  fadeFrames?: number;
}> = ({
  word,
  line1,
  line2,
  startAt = 20,
  letterEvery = 7,
  underlineAt,
  underlineFrames = 24,
  line1At,
  line2At,
  fadeFrames = 50,
}) => {
  const f = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const filterId = useSvgId("ul-glow");

  const letters = word.split("");
  const typedEnd = startAt + letters.length * letterEvery;
  const uAt = underlineAt ?? typedEnd + 10;
  const l1 = line1At ?? uAt + underlineFrames + 20;
  const l2 = line2At ?? l1 + 45;

  const ulP = interpolate(f, [uAt, uAt + underlineFrames], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const ulW = Math.max(300, letters.length * 120);
  const wave = Array.from({ length: 61 }, (_, i) => {
    const x = -ulW / 2 + (i / 60) * ulW;
    const y = 12 * Math.sin(i * 0.42 - f * 0.18);
    return `${i ? "L" : "M"}${x.toFixed(1)} ${y.toFixed(1)}`;
  }).join(" ");

  const lineIn = (at: number) => {
    const o = interpolate(f, [at, at + 12], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
    return { opacity: o, transform: `translateY(${(1 - o) * 14}px)` };
  };

  const black = interpolate(f, [durationInFrames - fadeFrames, durationInFrames - 4], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ background: "#07080B", alignItems: "center", justifyContent: "center", fontFamily: comic }}>
      {letters.map((_, i) => (
        <Sfx key={i} name="type" at={startAt + i * letterEvery} volume={0.8} />
      ))}
      <Sfx name="shimmer" at={uAt} volume={0.55} />

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", marginTop: -60 }}>
        <div style={{ display: "flex", fontSize: 190, fontWeight: 700, color: C.white, height: 220, letterSpacing: 6 }}>
          {letters.map((ch, i) => {
            const at = startAt + i * letterEvery;
            if (f < at) return null;
            const s = spring({ frame: f - at, fps, config: { damping: 9, stiffness: 240 } });
            return (
              <span key={i} style={{ display: "inline-block", transform: `scale(${s}) translateY(${(1 - s) * 30}px)` }}>
                {ch}
              </span>
            );
          })}
        </div>
        <svg width={ulW + 60} height={60} viewBox={`${-ulW / 2 - 30} -30 ${ulW + 60} 60`} style={{ overflow: "visible" }}>
          <defs>
            <filter id={filterId} x="-20%" y="-200%" width="140%" height="500%">
              <feGaussianBlur stdDeviation="6" result="b" />
              <feMerge>
                <feMergeNode in="b" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          </defs>
          <path
            d={wave}
            pathLength={1}
            stroke={C.accent}
            strokeWidth={9}
            fill="none"
            strokeLinecap="round"
            strokeDasharray="1 1"
            strokeDashoffset={1 - ulP}
            filter={`url(#${filterId})`}
            opacity={ulP > 0 ? 1 : 0}
          />
        </svg>
        <div style={{ marginTop: 50, fontSize: 48, fontWeight: 700, color: C.white, ...lineIn(l1) }}>{line1}</div>
        <div
          style={{
            marginTop: 18,
            fontSize: 40,
            fontWeight: 700,
            color: C.accent,
            textShadow: `0 0 18px ${C.accent}`,
            ...lineIn(l2),
          }}
        >
          {line2}
        </div>
      </div>
      <AbsoluteFill style={{ background: "#000", opacity: black }} />
    </AbsoluteFill>
  );
};
