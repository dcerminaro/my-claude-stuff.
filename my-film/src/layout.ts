import { createContext, useContext } from "react";
import { BAR } from "./theme";

/**
 * Where on-screen text may go. Films provide this so overlays avoid
 * letterbox bars (16:9) or the Instagram Reels interface (9:16).
 */
export type Safe = {
  top: number; // px kept clear at the top
  bottom: number; // px kept clear at the bottom
  left: number;
  right: number;
  letterbox: boolean; // draw black bars
};

/** 16:9 films with thin black bars */
export const SAFE_WIDE: Safe = {
  top: BAR,
  bottom: BAR,
  left: 0,
  right: 0,
  letterbox: true,
};

/**
 * Instagram Reels, 1080x1920. Instagram covers roughly the top 220px
 * (status bar, "Reels" header) and the bottom ~420px (caption, username,
 * audio), with action buttons down the right side.
 */
export const SAFE_REELS: Safe = {
  top: 220,
  bottom: 440,
  left: 64,
  right: 150,
  letterbox: false,
};

export const SafeContext = createContext<Safe>(SAFE_WIDE);
export const useSafe = () => useContext(SafeContext);
