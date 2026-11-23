import React from "react";
import { ThreeCanvas } from "@remotion/three";
import { useCurrentFrame, useVideoConfig } from "remotion";
import { DayCounter } from "../components/Text";
import { Look, LOOKS } from "../looks";

/** Shared pieces for Caesar lesson films. */

export const CRIMSON = "#D4343C";
export const CAESAR_LOOK: Look = { ...LOOKS.blocky, accent: CRIMSON };
export const CL = {
  extrapolateLeft: "clamp",
  extrapolateRight: "clamp",
} as const;

export const Canvas3D: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  const { width, height } = useVideoConfig();
  return (
    <ThreeCanvas width={width} height={height} shadows gl={{ antialias: true }}>
      {children}
    </ThreeCanvas>
  );
};

/** idle life: breathing + occasional blinks, keyed off the absolute frame */
export const life = (f: number, seed = 0) => ({
  squash: 1 + 0.012 * Math.sin((f + seed * 13) * 0.15),
  blink:
    Math.max(0, 1 - Math.abs(((f + seed * 37) % 70) - 35) / 3) *
    ((f + seed * 37) % 140 < 70 ? 1 : 0),
  t: f,
});

/** LESSON N counter, hidden from `hideFrom` (the title card) on */
export const LessonHud: React.FC<{ numeral: string; hideFrom: number }> = ({
  numeral,
  hideFrom,
}) => {
  const f = useCurrentFrame();
  if (f >= hideFrom) return null;
  return <DayCounter day={numeral} label="LESSON" since={30 + f} />;
};
