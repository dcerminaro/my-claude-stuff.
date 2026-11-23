import React from "react";
import { useCurrentFrame } from "remotion";
import { C } from "../theme";
import { wobblePath } from "./util";

/** Flat prop shape with a thin, wobbly grey outline. */
export const Wobbly: React.FC<{
  pts: [number, number][];
  fill?: string;
  stroke?: string;
  seed?: number;
  amp?: number;
  closed?: boolean;
  strokeWidth?: number;
}> = ({ pts, fill = C.prop, stroke = C.outline, seed = 0, amp = 1.6, closed = true, strokeWidth = 2 }) => {
  const frame = useCurrentFrame();
  return (
    <path
      d={wobblePath(pts, frame, seed, amp, closed)}
      fill={closed ? fill : "none"}
      stroke={stroke}
      strokeWidth={strokeWidth}
      strokeLinejoin="round"
      strokeLinecap="round"
    />
  );
};
