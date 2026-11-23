import React from "react";
import { AbsoluteFill, random, useCurrentFrame } from "remotion";
import { useLook } from "../looks";
import { FLOOR_Y, H, W } from "../theme";
import { wobblePath } from "./util";

/**
 * SVG filters shared by every look. Rendered once per film; filters are
 * referenced by id (url(#fx-...)) from any SVG on the page.
 */
export const LookDefs: React.FC = () => {
  const frame = useCurrentFrame();
  const look = useLook();
  const inkSeed = Math.floor(frame / 3); // ink lines "boil" a little
  return (
    <svg width={0} height={0} style={{ position: "absolute" }}>
      <defs>
        <filter id="fx-glow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="4" result="b1" />
          <feGaussianBlur in="SourceGraphic" stdDeviation="12" result="b2" />
          <feMerge>
            <feMergeNode in="b2" />
            <feMergeNode in="b2" />
            <feMergeNode in="b1" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>

        <filter id="fx-paper" x="-20%" y="-20%" width="140%" height="140%">
          <feTurbulence
            type="fractalNoise"
            baseFrequency="0.05"
            numOctaves="2"
            seed="7"
            result="n"
          />
          <feDisplacementMap
            in="SourceGraphic"
            in2="n"
            scale="5"
            xChannelSelector="R"
            yChannelSelector="G"
            result="cut"
          />
          <feDropShadow
            in="cut"
            dx="5"
            dy="8"
            stdDeviation="3"
            floodColor="#000"
            floodOpacity="0.55"
          />
        </filter>

        <filter id="fx-ink" x="-10%" y="-10%" width="120%" height="120%">
          <feTurbulence
            type="fractalNoise"
            baseFrequency="0.035"
            numOctaves="2"
            seed={inkSeed}
            result="n"
          />
          <feDisplacementMap
            in="SourceGraphic"
            in2="n"
            scale="4"
            xChannelSelector="R"
            yChannelSelector="G"
          />
        </filter>

        <filter id="fx-clay" x="-25%" y="-25%" width="150%" height="150%">
          <feGaussianBlur in="SourceAlpha" stdDeviation="7" result="blur" />
          <feDiffuseLighting
            in="blur"
            surfaceScale="5"
            diffuseConstant="1.3"
            lightingColor="#fff"
            result="diff"
          >
            <feDistantLight azimuth="235" elevation="48" />
          </feDiffuseLighting>
          <feComposite
            in="SourceGraphic"
            in2="diff"
            operator="arithmetic"
            k1="1"
            result="lit"
          />
          <feSpecularLighting
            in="blur"
            surfaceScale="5"
            specularConstant="0.55"
            specularExponent="22"
            lightingColor="#fff"
            result="spec"
          >
            <feDistantLight azimuth="235" elevation="55" />
          </feSpecularLighting>
          <feComposite
            in="lit"
            in2="spec"
            operator="arithmetic"
            k2="1"
            k3="0.6"
            result="shiny"
          />
          <feComposite
            in="shiny"
            in2="SourceAlpha"
            operator="in"
            result="body"
          />
          <feDropShadow
            in="body"
            dx="4"
            dy="9"
            stdDeviation="6"
            floodColor="#000"
            floodOpacity="0.5"
          />
        </filter>

        <filter id="fx-clay-glow" x="-40%" y="-40%" width="180%" height="180%">
          <feMorphology
            in="SourceAlpha"
            operator="dilate"
            radius="3"
            result="fat"
          />
          <feFlood floodColor={look.accent} result="col" />
          <feComposite in="col" in2="fat" operator="in" result="rim" />
          <feGaussianBlur in="rim" stdDeviation="10" result="halo" />
          <feGaussianBlur in="SourceAlpha" stdDeviation="7" result="blur" />
          <feSpecularLighting
            in="blur"
            surfaceScale="5"
            specularConstant="0.7"
            specularExponent="20"
            lightingColor={look.accent}
            result="spec"
          >
            <feDistantLight azimuth="235" elevation="55" />
          </feSpecularLighting>
          <feComposite
            in="SourceGraphic"
            in2="spec"
            operator="arithmetic"
            k2="1"
            k3="0.8"
            result="shiny"
          />
          <feComposite
            in="shiny"
            in2="SourceAlpha"
            operator="in"
            result="body"
          />
          <feMerge>
            <feMergeNode in="halo" />
            <feMergeNode in="halo" />
            <feMergeNode in="rim" />
            <feMergeNode in="body" />
          </feMerge>
        </filter>

        <filter id="fx-grain" x="0" y="0" width="100%" height="100%">
          <feTurbulence
            type="fractalNoise"
            baseFrequency="0.9"
            numOctaves="3"
            seed="2"
          />
          <feColorMatrix type="saturate" values="0" />
        </filter>
      </defs>
    </svg>
  );
};

/** Full-screen texture on top of the picture (under the letterbox). */
export const LookOverlay: React.FC = () => {
  const look = useLook();
  const vignette = (strength: number, color = "0,0,0") => (
    <AbsoluteFill
      style={{
        background: `radial-gradient(ellipse at center, rgba(${color},0) 55%, rgba(${color},${strength}) 100%)`,
      }}
    />
  );
  const grain = (
    opacity: number,
    blend: React.CSSProperties["mixBlendMode"],
  ) => (
    <AbsoluteFill style={{ mixBlendMode: blend, opacity }}>
      <svg width={W} height={H}>
        <rect width={W} height={H} filter="url(#fx-grain)" />
      </svg>
    </AbsoluteFill>
  );

  switch (look.name) {
    case "neon":
      return (
        <AbsoluteFill style={{ pointerEvents: "none" }}>
          <AbsoluteFill
            style={{
              background:
                "repeating-linear-gradient(0deg, rgba(0,0,0,0.28) 0px, rgba(0,0,0,0.28) 2px, transparent 2px, transparent 5px)",
            }}
          />
          {vignette(0.7)}
        </AbsoluteFill>
      );
    case "paper":
      return (
        <AbsoluteFill style={{ pointerEvents: "none" }}>
          {grain(0.22, "overlay")}
          {vignette(0.5)}
        </AbsoluteFill>
      );
    case "ink":
      return (
        <AbsoluteFill style={{ pointerEvents: "none" }}>
          {grain(0.28, "multiply")}
          {vignette(0.35, "120,90,50")}
        </AbsoluteFill>
      );
    case "clay":
      return (
        <AbsoluteFill style={{ pointerEvents: "none" }}>
          {vignette(0.55)}
        </AbsoluteFill>
      );
    case "blocky":
      return (
        <AbsoluteFill style={{ pointerEvents: "none" }}>
          {vignette(0.4)}
        </AbsoluteFill>
      );
    default:
      return null;
  }
};

/** Back wall / sky colour, styled per look. */
export const Backdrop: React.FC<{ color?: string }> = ({ color }) => {
  const look = useLook();
  const bg = color ?? look.bg;
  if (look.name !== "blocky")
    return <rect x={0} y={0} width={W} height={H} fill={bg} />;
  // wall made of blocks with subtle shade variation
  const S = 48;
  const shades = [bg, "#1E2233", "#171A26", "#21263A"];
  const tiles: React.ReactNode[] = [];
  for (let y = 0; y < FLOOR_Y; y += S) {
    for (let x = 0; x < W; x += S) {
      const s = shades[Math.floor(random(`w${x}-${y}`) * shades.length)];
      tiles.push(
        <rect
          key={`${x}-${y}`}
          x={x}
          y={y}
          width={S}
          height={S}
          fill={s}
          stroke="#11131C"
          strokeWidth={2}
        />,
      );
    }
  }
  return <g shapeRendering="crispEdges">{tiles}</g>;
};

/** The floor, styled per look. `scroll` moves floor detail when running. */
export const Floor: React.FC<{ y?: number; scroll?: number }> = ({
  y = FLOOR_Y,
  scroll = 0,
}) => {
  const look = useLook();
  const frame = useCurrentFrame();

  switch (look.name) {
    case "blocky": {
      const S = 48;
      const off = ((scroll % S) + S) % S;
      const tiles: React.ReactNode[] = [];
      for (let r = 0; y + r * S < H; r++) {
        for (let c = -1; c * S < W + S; c++) {
          const col = Math.floor((c * S + scroll) / S);
          const shade = ["#3C3C46", "#45454F", "#34343D"][
            Math.floor(random(`f${col}-${r}`) * 3)
          ];
          tiles.push(
            <rect
              key={`${r}-${c}`}
              x={c * S - off}
              y={y + r * S}
              width={S}
              height={S}
              fill={r === 0 ? "#5A5A66" : shade}
              stroke="#1A1A20"
              strokeWidth={2}
            />,
          );
        }
      }
      return <g shapeRendering="crispEdges">{tiles}</g>;
    }
    case "neon": {
      const vx = W / 2;
      const lines: React.ReactNode[] = [];
      for (let i = -14; i <= 14; i++) {
        lines.push(
          <line
            key={`v${i}`}
            x1={vx + i * 40}
            y1={y}
            x2={vx + i * 260}
            y2={H}
            stroke="#FF3EA5"
            strokeWidth={1.5}
            opacity={0.5}
          />,
        );
      }
      const phase = (((scroll * 0.01) % 1) + 1) % 1;
      for (let k = 0; k < 7; k++) {
        const t = (k + 1 - phase) / 7;
        const yy = y + (H - y) * t * t;
        lines.push(
          <line
            key={`h${k}`}
            x1={0}
            y1={yy}
            x2={W}
            y2={yy}
            stroke="#FF3EA5"
            strokeWidth={1.5}
            opacity={0.5}
          />,
        );
      }
      return (
        <g>
          <rect x={0} y={y} width={W} height={H - y} fill="#0A0414" />
          <g filter="url(#fx-glow)">{lines}</g>
          <line
            x1={0}
            y1={y}
            x2={W}
            y2={y}
            stroke="#FF3EA5"
            strokeWidth={3}
            filter="url(#fx-glow)"
          />
        </g>
      );
    }
    case "paper": {
      const pts: [number, number][] = [[-20, H + 20]];
      for (let x = -20; x <= W + 20; x += 40)
        pts.push([x, y + (random(`tear${x}`) - 0.5) * 8]);
      pts.push([W + 20, H + 20]);
      return (
        <path
          d={`M${pts.map((p) => p.join(" ")).join(" L")} Z`}
          fill={look.floor}
          filter="url(#fx-paper)"
        />
      );
    }
    case "ink": {
      const hatch: React.ReactNode[] = [];
      const off = ((scroll % 36) + 36) % 36;
      for (let x = -40; x < W + 40; x += 36) {
        hatch.push(
          <line
            key={x}
            x1={x - off}
            y1={y + 10}
            x2={x - off - 22}
            y2={y + 34}
            stroke={look.outline}
            strokeWidth={2}
            opacity={0.55}
          />,
        );
      }
      return (
        <g filter="url(#fx-ink)">
          <rect x={0} y={y} width={W} height={H - y} fill={look.bgDeep} />
          <path
            d={wobblePath(
              [
                [0, y],
                [W, y],
              ],
              frame,
              3,
              1.5,
              false,
              60,
            )}
            stroke={look.outline}
            strokeWidth={3}
            fill="none"
          />
          <path
            d={wobblePath(
              [
                [0, y + 4],
                [W, y + 3],
              ],
              frame,
              9,
              1.5,
              false,
              80,
            )}
            stroke={look.outline}
            strokeWidth={1.5}
            fill="none"
            opacity={0.6}
          />
          {hatch}
        </g>
      );
    }
    case "clay":
      return (
        <rect
          x={-40}
          y={y}
          width={W + 80}
          height={H - y + 40}
          rx={30}
          fill={look.floor}
          filter="url(#fx-clay)"
        />
      );
    default:
      return (
        <g>
          <rect x={0} y={y} width={W} height={H - y} fill={look.bgDeep} />
          <line
            x1={0}
            y1={y}
            x2={W}
            y2={y}
            stroke={look.floor}
            strokeWidth={2}
          />
        </g>
      );
  }
};
