import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { useLook } from "../looks";
import { useSafe } from "../layout";
import type { PlacedLine } from "../voice/sync";

const MAX_WORDS = 4;

/** split a line's words into short chunks, breaking after punctuation */
const chunk = (line: PlacedLine) => {
  const chunks: number[][] = [];
  let cur: number[] = [];
  line.words.forEach((w, i) => {
    cur.push(i);
    if (cur.length >= MAX_WORDS || /[.,!?;]$/.test(w.text)) {
      chunks.push(cur);
      cur = [];
    }
  });
  if (cur.length) chunks.push(cur);
  return chunks;
};

/**
 * Caesar's subtitles: bottom centre, a few words at a time, timed to the
 * voice. The word being spoken is highlighted in the accent colour.
 */
export const Subtitles: React.FC<{ lines: PlacedLine[]; hold?: number }> = ({
  lines,
  hold = 0.25,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const look = useLook();
  const safe = useSafe();

  const line = lines.find((l) => frame >= l.from && frame < l.to + hold * fps);
  if (!line) return null;
  const t = (frame - line.from) / fps;
  let current = line.words.findIndex((w) => t >= w.start && t < w.end);
  if (current < 0) {
    // between words: keep the last word that started
    current = line.words.reduce((acc, w, i) => (w.start <= t ? i : acc), 0);
  }
  const chunks = chunk(line);
  const group = chunks.find((c) => c.includes(current)) ?? chunks[0];
  const groupStart = line.from + Math.round(line.words[group[0]].start * fps);
  const pop = interpolate(frame - groupStart, [0, 4], [0.85, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const fadeOut = interpolate(
    frame,
    [line.to + hold * fps - 5, line.to + hold * fps],
    [1, 0],
    {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    },
  );

  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        bottom: safe.bottom + 46,
        paddingLeft: safe.left,
        paddingRight: safe.right,
        textAlign: "center",
        fontFamily: look.font,
        fontWeight: look.fontWeight,
        fontSize: 64,
        lineHeight: 1.1,
        opacity: fadeOut,
        transform: `scale(${pop})`,
      }}
    >
      {group.map((i) => {
        const w = line.words[i];
        const spoken = t >= w.start;
        const active = i === current;
        return (
          <span
            key={i}
            style={{
              color: active ? look.accent : "#FFFFFF",
              opacity: spoken ? 1 : 0.45,
              WebkitTextStroke: "5px #000",
              paintOrder: "stroke",
              margin: "0 12px",
              display: "inline-block",
              transform: active ? "translateY(-4px)" : "none",
            }}
          >
            {w.text}
          </span>
        );
      })}
    </div>
  );
};
