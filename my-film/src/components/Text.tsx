import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { comic } from "../fonts";
import { BAR, C } from "../theme";

const fade = (f: number, d: number, edge: number) =>
  interpolate(f, [0, edge, d - edge, d], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

/** Narrator: small, white, top centre. Max 8 words. Use inside a <Sequence>. */
export const NarratorText: React.FC<{ text: string; fadeFrames?: number }> = ({ text, fadeFrames = 8 }) => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  if (text.trim().split(/\s+/).length > 8) throw new Error(`Narrator line over 8 words: "${text}"`);
  const o = fade(f, durationInFrames, fadeFrames);
  return (
    <div
      style={{
        position: "absolute",
        top: BAR + 34,
        left: 0,
        right: 0,
        textAlign: "center",
        fontFamily: comic,
        fontWeight: 700,
        fontSize: 40,
        color: C.white,
        opacity: o,
        transform: `translateY(${(1 - o) * 8}px)`,
        textShadow: "0 2px 10px rgba(0,0,0,0.8)",
      }}
    >
      {text}
    </div>
  );
};

/** The shadow's voice: accent colour, placed beside the shadow. Use inside a <Sequence>. */
export const ShadowText: React.FC<{ text: string; x: number; y: number; width?: number }> = ({
  text,
  x,
  y,
  width = 420,
}) => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const o = fade(f, durationInFrames, 8);
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width,
        textAlign: "right",
        fontFamily: comic,
        fontWeight: 700,
        fontSize: 46,
        lineHeight: 1.15,
        color: C.accent,
        opacity: o,
        transform: `translate(${Math.sin(f * 0.21) * 1.2}px, ${Math.cos(f * 0.17) * 1.2}px) scale(${0.92 + 0.08 * o})`,
        transformOrigin: "right center",
        textShadow: `0 0 18px ${C.accent}, 0 0 40px rgba(155,92,255,0.5)`,
      }}
    >
      {text}
    </div>
  );
};

/** Small game-style DAY counter, top left. `since` = frames since the day changed. */
export const DayCounter: React.FC<{ day: number; since: number }> = ({ day, since }) => {
  const { fps } = useVideoConfig();
  const s = spring({ frame: since, fps, config: { damping: 9, stiffness: 220 } });
  const scale = interpolate(s, [0, 1], [1.35, 1]);
  return (
    <div
      style={{
        position: "absolute",
        left: 48,
        top: BAR + 26,
        fontFamily: comic,
        fontWeight: 700,
        color: C.white,
        border: `2px solid ${C.outline}`,
        borderRadius: 10,
        padding: "4px 14px",
        background: "rgba(0,0,0,0.4)",
        transform: `scale(${scale})`,
        transformOrigin: "left center",
        display: "flex",
        alignItems: "baseline",
        gap: 8,
      }}
    >
      <span style={{ fontSize: 20, opacity: 0.7, letterSpacing: 2 }}>DAY</span>
      <span style={{ fontSize: 34 }}>{day}</span>
    </div>
  );
};

/** Rep count that pops on screen. Use inside a <Sequence>. */
export const RepPop: React.FC<{ text: string; x: number; y: number; size?: number; color?: string }> = ({
  text,
  x,
  y,
  size = 72,
  color = C.white,
}) => {
  const f = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const s = spring({ frame: f, fps, config: { damping: 7, stiffness: 260 } });
  const o = interpolate(f, [durationInFrames - 10, durationInFrames], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const rise = interpolate(f, [0, durationInFrames], [0, -40]);
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        transform: `translate(-50%, -50%) translateY(${rise}px) scale(${s}) rotate(${(1 - s) * -12}deg)`,
        fontFamily: comic,
        fontWeight: 700,
        fontSize: size,
        color,
        opacity: o,
        WebkitTextStroke: "3px #000",
        paintOrder: "stroke",
        textShadow: "0 4px 0 rgba(0,0,0,0.6)",
      }}
    >
      {text}
    </div>
  );
};
