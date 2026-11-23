import React from "react";
import { Audio } from "@remotion/media";
import { Sequence, staticFile } from "remotion";

export type SfxName =
  | "pop"
  | "whoosh"
  | "hit"
  | "step"
  | "type"
  | "alarm"
  | "drone"
  | "shimmer"
  | "hum";

/**
 * Plays a code-generated sound effect (see scripts/make-sfx.mjs) at a frame.
 * All sounds are synthesised from maths, so they are YouTube-safe.
 */
export const Sfx: React.FC<{
  name: SfxName;
  at: number;
  volume?: number;
  duration?: number;
  loop?: boolean;
  rate?: number;
}> = ({ name, at, volume = 1, duration, loop, rate }) => (
  <Sequence
    from={at}
    durationInFrames={duration}
    layout="none"
    name={`sfx:${name}`}
  >
    <Audio
      src={staticFile(`sfx/${name}.wav`)}
      volume={volume}
      loop={loop}
      playbackRate={rate}
    />
  </Sequence>
);
