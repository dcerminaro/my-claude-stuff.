import type { VoiceLine, VoiceTrack } from "./types";

export type PlacedLine = VoiceLine & { from: number; to: number }; // frames

/**
 * Places each voice line on the film's timeline.
 * `gaps[i]` = seconds of silence before line i (gaps[0] = when the first line starts).
 */
export const placeLines = (
  track: VoiceTrack,
  gaps: number[],
  fps: number,
): PlacedLine[] => {
  let t = 0;
  return track.lines.map((line, i) => {
    t += gaps[i] ?? 0.25;
    const from = Math.round(t * fps);
    t += line.duration;
    return { ...line, from, to: Math.round(t * fps) };
  });
};

export const lineAt = (lines: PlacedLine[], frame: number) =>
  lines.find((l) => frame >= l.from && frame < l.to) ?? null;

const VOWELS = "aeiouyAEIOUY";

/** How open the mouth is (0..1) at this frame, from the letter being spoken. */
export const talkAt = (lines: PlacedLine[], frame: number, fps: number) => {
  const sample = (f: number) => {
    const l = lineAt(lines, f);
    if (!l) return 0;
    const t = (f - l.from) / fps;
    const c = l.chars.find(([, s, e]) => t >= s && t < e);
    if (!c) return 0;
    const ch = c[0];
    if (VOWELS.includes(ch))
      return ch === "o" || ch === "O" || ch === "a" || ch === "A" ? 1 : 0.8;
    if (/[a-zA-Z]/.test(ch)) return "mbpMBP".includes(ch) ? 0.05 : 0.4;
    return 0;
  };
  // smooth over neighbouring frames so the mouth doesn't chatter
  return (
    sample(frame - 1) * 0.25 + sample(frame) * 0.5 + sample(frame + 1) * 0.25
  );
};

/** frame at which a given word (by index within a line) starts */
export const wordFrame = (line: PlacedLine, wordIndex: number, fps: number) =>
  line.from + Math.round((line.words[wordIndex]?.start ?? 0) * fps);

/** frame at which the first word containing `text` starts (case-insensitive) */
export const findWord = (line: PlacedLine, text: string, fps: number) => {
  const i = line.words.findIndex((w) =>
    w.text.toLowerCase().includes(text.toLowerCase()),
  );
  return wordFrame(line, Math.max(0, i), fps);
};
