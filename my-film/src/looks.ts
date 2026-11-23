import { createContext, useContext } from "react";
import { loadFont as loadCaveat } from "@remotion/google-fonts/Caveat";
import { loadFont as loadFredoka } from "@remotion/google-fonts/Fredoka";
import { loadFont as loadOrbitron } from "@remotion/google-fonts/Orbitron";
import { loadFont as loadPatrick } from "@remotion/google-fonts/PatrickHand";
import { loadFont as loadPixelify } from "@remotion/google-fonts/PixelifySans";
import { comic } from "./fonts";
import { C } from "./theme";

/**
 * A "look" is a complete art style. Every shared component reads the
 * current look, so the same film can be redrawn in different styles.
 * "original" is the channel's house style from CLAUDE.md.
 */
export type LookName =
  | "original"
  | "blocky"
  | "neon"
  | "paper"
  | "ink"
  | "clay";

export type Look = {
  name: LookName;
  label: string;
  font: string;
  fontScale: number;
  fontWeight: number;
  // colours
  bg: string;
  bgDeep: string;
  floor: string;
  outline: string; // prop outline
  prop: string;
  propDark: string;
  shade: string; // lamp shade
  glass: string; // window glass
  building: string;
  windowLit: string;
  moon: string;
  hero: string;
  heroDark: string;
  heroLine: string; // hero outline ("none" for no outline)
  face: string;
  shadowBody: string;
  accent: string;
  text: string;
  textStroke: string;
  warm: string;
  cool: string;
  speed: string;
  titleBg: string;
  headband: string;
  // rendering
  propFill: boolean; // false = outline-only props (neon)
  strokeW: number;
  wobble: number; // outline wobble amount
  grid: number; // >0 = snap shapes to a block grid (blocky)
  limbW: number;
  glowBlend: "screen" | "multiply";
  glowScale: number;
  propFilter?: string; // svg filter id applied to props
  figureFilter?: string; // svg filter id applied to the hero
  shadowFilter?: string; // svg filter id applied to the shadow
  lineFilter?: string; // svg filter id for glowing lines
  radius: number; // UI corner radius
};

const pixel = loadPixelify("normal", {
  weights: ["700"],
  subsets: ["latin"],
}).fontFamily;
const orbitron = loadOrbitron("normal", {
  weights: ["700"],
  subsets: ["latin"],
}).fontFamily;
const patrick = loadPatrick("normal", {
  weights: ["400"],
  subsets: ["latin"],
}).fontFamily;
const caveat = loadCaveat("normal", {
  weights: ["700"],
  subsets: ["latin"],
}).fontFamily;
const fredoka = loadFredoka("normal", {
  weights: ["600"],
  subsets: ["latin"],
}).fontFamily;

const original: Look = {
  name: "original",
  label: "Original",
  font: comic,
  fontScale: 1,
  fontWeight: 700,
  bg: C.bg,
  bgDeep: C.bgDeep,
  floor: C.floor,
  outline: C.outline,
  prop: C.prop,
  propDark: C.propDark,
  shade: "#2A2418",
  glass: "#111522",
  building: "#141722",
  windowLit: "#FFD37A",
  moon: "#E8E6D9",
  hero: C.hero,
  heroDark: C.heroDark,
  heroLine: "none",
  face: C.ink,
  shadowBody: "#000",
  accent: C.accent,
  text: C.white,
  textStroke: "#000",
  warm: C.warmLight,
  cool: C.coolLight,
  speed: "#FFFFFF",
  titleBg: "#07080B",
  headband: C.headband,
  propFill: true,
  strokeW: 2,
  wobble: 1.6,
  grid: 0,
  limbW: 14,
  glowBlend: "screen",
  glowScale: 1,
  shadowFilter: "fx-glow",
  radius: 10,
};

export const LOOKS: Record<LookName, Look> = {
  original,

  // Chunky block / voxel pixel-art world
  blocky: {
    ...original,
    name: "blocky",
    label: "Blocky",
    font: pixel,
    fontScale: 0.9,
    bg: "#1A1D2B",
    bgDeep: "#2A2A33",
    floor: "#5A5A66",
    outline: "#0E0F16",
    prop: "#4A4F63",
    propDark: "#33374A",
    shade: "#7A5A2E",
    glass: "#18203A",
    building: "#262A3B",
    windowLit: "#FFD23F",
    hero: "#F2B84B",
    heroDark: "#B98329",
    heroLine: "#7A5418",
    face: "#2B1D0E",
    strokeW: 4,
    wobble: 0,
    grid: 12,
    limbW: 22,
    radius: 0,
    shadowFilter: "fx-glow",
  },

  // Glowing neon tubes on black, retro grid floor
  neon: {
    ...original,
    name: "neon",
    label: "Neon",
    font: orbitron,
    fontScale: 0.8,
    bg: "#05040A",
    bgDeep: "#05040A",
    floor: "#FF3EA5",
    outline: "#36E2FF",
    prop: "#05040A",
    propDark: "#05040A",
    shade: "#05040A",
    glass: "#05040A",
    building: "#05040A",
    windowLit: "#36E2FF",
    moon: "#FFE9F6",
    hero: "#05040A",
    heroDark: "#05040A",
    heroLine: "#FFC23D",
    face: "#FFC23D",
    shadowBody: "#05040A",
    accent: "#C04BFF",
    text: "#FFFFFF",
    warm: "#FF9A3D",
    cool: "#36E2FF",
    speed: "#36E2FF",
    titleBg: "#05040A",
    headband: "#FF3EA5",
    propFill: false,
    strokeW: 3.5,
    wobble: 0,
    limbW: 6,
    glowScale: 0.8,
    propFilter: "fx-glow",
    figureFilter: "fx-glow",
    lineFilter: "fx-glow",
  },

  // Cut-out craft paper puppets with drop shadows
  paper: {
    ...original,
    name: "paper",
    label: "Paper cut-out",
    font: patrick,
    fontScale: 1.15,
    fontWeight: 400,
    bg: "#1F2747",
    bgDeep: "#161C35",
    floor: "#2E3760",
    outline: "none",
    prop: "#3B4672",
    propDark: "#2C3559",
    shade: "#C9774A",
    glass: "#27305A",
    building: "#2B3463",
    windowLit: "#F7D57A",
    moon: "#F4EBD0",
    hero: "#EFB24A",
    heroDark: "#C98D2E",
    heroLine: "none",
    face: "#3A2A1A",
    shadowBody: "#0D0D12",
    accent: "#A46BFF",
    titleBg: "#1F2747",
    strokeW: 0,
    wobble: 0,
    limbW: 18,
    glowScale: 0.8,
    propFilter: "fx-paper",
    figureFilter: "fx-paper",
    shadowFilter: "fx-paper",
    radius: 4,
  },

  // Pen-and-ink sketch on cream paper, boiling lines
  ink: {
    ...original,
    name: "ink",
    label: "Ink sketch",
    font: caveat,
    fontScale: 1.35,
    bg: "#F3EBDD",
    bgDeep: "#E8DDCA",
    floor: "#2A241E",
    outline: "#2A241E",
    prop: "#EFE5D3",
    propDark: "#E3D6BF",
    shade: "#E9D9B8",
    glass: "#E4DCCD",
    building: "#EEE4D2",
    windowLit: "#F2C75C",
    moon: "#FFFFFF",
    hero: "#F4C969",
    heroDark: "#E0AF4C",
    heroLine: "#2A241E",
    face: "#2A241E",
    shadowBody: "#1C1814",
    accent: "#7A3FD6",
    text: "#2A241E",
    textStroke: "#F3EBDD",
    warm: "#F6B84B",
    cool: "#8FA8D8",
    speed: "#2A241E",
    titleBg: "#F3EBDD",
    strokeW: 3,
    wobble: 2.4,
    limbW: 12,
    glowBlend: "multiply",
    glowScale: 0.55,
    propFilter: "fx-ink",
    figureFilter: "fx-ink",
    shadowFilter: "fx-ink",
    radius: 6,
  },

  // Soft, puffy clay with real lighting
  clay: {
    ...original,
    name: "clay",
    label: "Clay",
    font: fredoka,
    fontScale: 0.95,
    fontWeight: 600,
    bg: "#2A2236",
    bgDeep: "#1F1929",
    floor: "#4A3F5C",
    outline: "none",
    prop: "#5B4F75",
    propDark: "#463C5C",
    shade: "#D98A4E",
    glass: "#332B47",
    building: "#3D3454",
    windowLit: "#FFD27A",
    moon: "#F6EEDD",
    hero: "#F2B84B",
    heroDark: "#D79A34",
    heroLine: "none",
    face: "#2B1E12",
    shadowBody: "#141118",
    accent: "#A66BFF",
    titleBg: "#2A2236",
    strokeW: 0,
    wobble: 0,
    limbW: 20,
    glowScale: 0.85,
    propFilter: "fx-clay",
    figureFilter: "fx-clay",
    shadowFilter: "fx-clay-glow",
    radius: 18,
  },
};

export const LookContext = createContext<Look>(original);
export const useLook = () => useContext(LookContext);
