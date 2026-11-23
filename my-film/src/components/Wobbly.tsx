import React from "react";
import { useCurrentFrame } from "remotion";
import { useLook } from "../looks";
import { blockPath, wobblePath } from "./util";

/**
 * A prop shape drawn in the current look: wobbly grey outline (original),
 * stair-stepped blocks (blocky), neon tube (neon), cut paper (paper),
 * ink line (ink) or puffy clay (clay).
 */
export const Wobbly: React.FC<{
  pts: [number, number][];
  fill?: string;
  stroke?: string;
  seed?: number;
  amp?: number;
  closed?: boolean;
  strokeWidth?: number;
}> = ({
  pts,
  fill,
  stroke,
  seed = 0,
  amp = 1.6,
  closed = true,
  strokeWidth,
}) => {
  const frame = useCurrentFrame();
  const look = useLook();
  const d = look.grid
    ? blockPath(pts, look.grid, closed)
    : wobblePath(pts, frame, seed, (amp * look.wobble) / 1.6, closed);

  const lineOnly = !closed;
  const fillColor = lineOnly || !look.propFill ? "none" : (fill ?? look.prop);
  let strokeColor = stroke ?? look.outline;
  let sw = strokeWidth ?? look.strokeW;
  if (lineOnly && (strokeColor === "none" || sw === 0)) {
    // looks without outlines still need visible lines (window bars etc.)
    strokeColor = look.propDark;
    sw = look.name === "clay" ? 10 : 8;
  }
  return (
    <path
      d={d}
      fill={fillColor}
      stroke={sw > 0 ? strokeColor : "none"}
      strokeWidth={sw}
      strokeLinejoin={look.grid ? "miter" : "round"}
      strokeLinecap={look.grid ? "square" : "round"}
      shapeRendering={look.grid ? "crispEdges" : undefined}
      filter={look.propFilter ? `url(#${look.propFilter})` : undefined}
    />
  );
};
