import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { useLook } from "../looks";
import { useSafe } from "../layout";

const fade = (f: number, d: number, edge: number) =>
  interpolate(f, [0, edge, d - edge, d], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

/** Narrator: small, white, top centre. Max 8 words. Use inside a <Sequence>. */
export const NarratorText: React.FC<{ text: string; fadeFrames?: number }> = ({
  text,
  fadeFrames = 8,
}) => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  if (text.trim().split(/\s+/).length > 8)
    throw new Error(`Narrator line over 8 words: "${text}"`);
  const look = useLook();
  const safe = useSafe();
  const o = fade(f, durationInFrames, fadeFrames);
  return (
    <div
      style={{
        position: "absolute",
        top: safe.top + 34,
        left: 0,
        right: 0,
        textAlign: "center",
        fontFamily: look.font,
        fontWeight: look.fontWeight,
        fontSize: 40 * look.fontScale,
        color: look.text,
        opacity: o,
        transform: `translateY(${(1 - o) * 8}px)`,
        textShadow: look.name === "ink" ? "none" : "0 2px 10px rgba(0,0,0,0.8)",
      }}
    >
      {text}
    </div>
  );
};

/** The shadow's voice: accent colour, placed beside the shadow. Use inside a <Sequence>. */
export const ShadowText: React.FC<{
  text: string;
  x: number;
  y: number;
  width?: number;
  color?: string; // defaults to the look's accent
  align?: "left" | "right";
}> = ({ text, x, y, width = 420, color, align = "right" }) => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const look = useLook();
  const safe = useSafe();
  const o = fade(f, durationInFrames, 8);
  const c = color ?? look.accent;
  const glow =
    look.name === "ink" || look.name === "paper"
      ? "none"
      : `0 0 18px ${c}, 0 0 40px ${c}88, 0 3px 0 #000`;
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width,
        textAlign: align,
        fontFamily: look.font,
        fontWeight: look.fontWeight,
        fontSize: 46 * look.fontScale * (safe.letterbox ? 1 : 1.7),
        lineHeight: 1.15,
        color: c,
        opacity: o,
        transform: `translate(${Math.sin(f * 0.21) * 1.2}px, ${Math.cos(f * 0.17) * 1.2}px) scale(${0.92 + 0.08 * o})`,
        transformOrigin: `${align} center`,
        textShadow: glow,
      }}
    >
      {text}
    </div>
  );
};

/** Small game-style counter, top left (DAY 3, LESSON IV...). `since` = frames since it changed. */
export const DayCounter: React.FC<{
  day: number | string;
  since: number;
  label?: string;
}> = ({ day, since, label = "DAY" }) => {
  const { fps } = useVideoConfig();
  const look = useLook();
  const safe = useSafe();
  const s = spring({
    frame: since,
    fps,
    config: { damping: 9, stiffness: 220 },
  });
  const scale = interpolate(s, [0, 1], [1.35, 1]);
  return (
    <div
      style={{
        position: "absolute",
        left: safe.left || 48,
        top: safe.top + 26,
        fontFamily: look.font,
        fontWeight: look.fontWeight,
        color: look.text,
        border: `${look.grid ? 4 : 2}px solid ${look.name === "neon" ? look.outline : look.name === "ink" ? look.text : "#8A8F99"}`,
        borderRadius: look.radius,
        padding: "4px 14px",
        background:
          look.name === "ink"
            ? "rgba(255,255,255,0.4)"
            : safe.letterbox
              ? "rgba(0,0,0,0.4)"
              : "rgba(20,20,28,0.8)",
        boxShadow: look.name === "neon" ? `0 0 14px ${look.outline}` : "none",
        transform: `scale(${scale})`,
        transformOrigin: "left center",
        display: "flex",
        alignItems: "baseline",
        gap: 8,
      }}
    >
      <span
        style={{
          fontSize: 20 * look.fontScale * (safe.letterbox ? 1 : 2.1),
          opacity: 0.7,
          letterSpacing: 2,
        }}
      >
        {label}
      </span>
      <span
        style={{ fontSize: 34 * look.fontScale * (safe.letterbox ? 1 : 2.1) }}
      >
        {day}
      </span>
    </div>
  );
};

/** Rep count that pops on screen. Use inside a <Sequence>. */
export const RepPop: React.FC<{
  text: string;
  x: number;
  y: number;
  size?: number;
  color?: string;
}> = ({ text, x, y, size = 72, color }) => {
  const look = useLook();
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
        fontFamily: look.font,
        fontWeight: look.fontWeight,
        fontSize: size * look.fontScale,
        color: color ?? look.text,
        opacity: o,
        WebkitTextStroke: `3px ${look.textStroke}`,
        paintOrder: "stroke",
        textShadow: "0 4px 0 rgba(0,0,0,0.6)",
      }}
    >
      {text}
    </div>
  );
};
