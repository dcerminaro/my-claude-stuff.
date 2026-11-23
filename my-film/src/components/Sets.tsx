import React from "react";
import { random, useCurrentFrame } from "remotion";
import { useLook } from "../looks";
import { FLOOR_Y, H, W } from "../theme";
import { Glow } from "./Glow";
import { Backdrop, Floor } from "./LookFx";
import { Wobbly } from "./Wobbly";
import { circlePts, rectPts, roundRectPts, useSvgId } from "./util";

export { Floor };

/** Floor lamp. Its bulb is the light source. */
export const Lamp: React.FC<{ x: number; flicker?: number }> = ({
  x,
  flicker = 0,
}) => {
  const frame = useCurrentFrame();
  const look = useLook();
  const coneId = useSvgId("cone");
  const k = 1 + flicker * 0.06 * Math.sin(frame * 0.9) * Math.sin(frame * 0.37);
  const shadeStroke = look.name === "neon" ? look.warm : undefined;
  return (
    <g>
      <defs>
        <linearGradient id={coneId} x1="0" y1="0" x2="0" y2="1">
          <stop
            offset="0"
            stopColor={look.warm}
            stopOpacity={0.22 * k * look.glowScale}
          />
          <stop offset="1" stopColor={look.warm} stopOpacity={0} />
        </linearGradient>
      </defs>
      <Glow x={x} y={540} r={620} color={look.warm} opacity={0.32 * k} />
      {!look.grid && (
        <path
          d={`M${x - 60} 560 L${x + 60} 560 L${x + 230} ${FLOOR_Y} L${x - 230} ${FLOOR_Y} Z`}
          fill={`url(#${coneId})`}
          style={{ mixBlendMode: look.glowBlend }}
        />
      )}
      <Glow
        x={x}
        y={FLOOR_Y}
        r={360}
        ry={34}
        color={look.warm}
        opacity={0.5 * k}
      />
      <Wobbly
        pts={rectPts(x - 6, 560, 12, FLOOR_Y - 572)}
        seed={11}
        fill={look.propDark}
      />
      <Wobbly
        pts={[
          [x - 55, FLOOR_Y],
          [x + 55, FLOOR_Y],
          [x + 40, FLOOR_Y - 14],
          [x - 40, FLOOR_Y - 14],
        ]}
        seed={12}
      />
      <Wobbly
        pts={[
          [x - 72, 560],
          [x + 72, 560],
          [x + 44, 462],
          [x - 44, 462],
        ]}
        seed={13}
        fill={look.shade}
        stroke={shadeStroke}
      />
      <Glow
        x={x}
        y={566}
        r={120}
        color={look.name === "ink" ? look.warm : "#FFE2A8"}
        opacity={0.9 * k}
      />
    </g>
  );
};

/** Window with the moon in it. */
export const MoonWindow: React.FC<{ x: number; y: number }> = ({ x, y }) => {
  const look = useLook();
  const moon = look.grid ? (
    <rect x={x + 168} y={y + 72} width={72} height={72} fill={look.moon} />
  ) : look.name === "neon" ? (
    <circle
      cx={x + 205}
      cy={y + 105}
      r={40}
      fill="none"
      stroke={look.moon}
      strokeWidth={4}
      filter="url(#fx-glow)"
    />
  ) : (
    <circle
      cx={x + 205}
      cy={y + 105}
      r={40}
      fill={look.moon}
      stroke={look.name === "ink" ? look.outline : "none"}
      strokeWidth={3}
      filter={look.propFilter ? `url(#${look.propFilter})` : undefined}
    />
  );
  return (
    <g>
      <Glow x={x + 160} y={y + 120} r={420} color={look.cool} opacity={0.16} />
      <Wobbly pts={rectPts(x, y, 320, 320)} seed={21} fill={look.glass} />
      {moon}
      <Glow
        x={x + 205}
        y={y + 105}
        r={150}
        color={look.name === "ink" ? look.cool : "#DDE6FF"}
        opacity={0.5}
      />
      <Wobbly
        pts={[
          [x + 160, y],
          [x + 160, y + 320],
        ]}
        closed={false}
        seed={22}
      />
      <Wobbly
        pts={[
          [x, y + 160],
          [x + 320, y + 160],
        ]}
        closed={false}
        seed={23}
      />
      <Wobbly
        pts={rectPts(x - 18, y + 320, 356, 16)}
        seed={24}
        fill={look.propDark}
      />
      <Glow
        x={x + 160}
        y={FLOOR_Y}
        r={260}
        ry={22}
        color={look.cool}
        opacity={0.14}
      />
    </g>
  );
};

export const Dumbbell: React.FC<{ x: number }> = ({ x }) => {
  const look = useLook();
  return (
    <g>
      <Wobbly pts={rectPts(x - 40, FLOOR_Y - 22, 80, 8)} seed={31} amp={1} />
      <Wobbly
        pts={circlePts(x - 46, FLOOR_Y - 18, 18, 16)}
        seed={32}
        amp={1}
        fill={look.propDark}
      />
      <Wobbly
        pts={circlePts(x + 46, FLOOR_Y - 18, 18, 16)}
        seed={33}
        amp={1}
        fill={look.propDark}
      />
    </g>
  );
};

/** His small room at night: lamp, moon window, dumbbell. */
export const Room: React.FC = () => (
  <g>
    <Backdrop />
    <MoonWindow x={1260} y={290} />
    <Floor />
    <Dumbbell x={1260} />
    <Lamp x={470} flicker={1} />
  </g>
);

/** Night city that scrolls past. `scroll` = pixels travelled. */
export const City: React.FC<{ scroll: number }> = ({ scroll }) => {
  const frame = useCurrentFrame();
  const look = useLook();
  const blocks: { x: number; w: number; h: number; seed: number }[] = [];
  let bx = 0;
  for (let i = 0; i < 14; i++) {
    const w = 140 + random(`bw${i}`) * 160;
    const h = 200 + random(`bh${i}`) * 300;
    blocks.push({ x: bx, w, h, seed: i });
    bx += w + 20 + random(`bg${i}`) * 50;
  }
  const loop = bx;
  const far = scroll * 0.25;
  const near = scroll;
  const lampGap = 720;
  const sky = look.name === "original" ? "#0B0D13" : look.bg;

  return (
    <g>
      <rect x={0} y={0} width={W} height={H} fill={sky} />
      {look.grid ? (
        <rect x={1532} y={182} width={96} height={96} fill={look.moon} />
      ) : (
        <circle
          cx={1580}
          cy={230}
          r={46}
          fill={look.name === "neon" ? "none" : look.moon}
          stroke={
            look.name === "neon"
              ? look.moon
              : look.name === "ink"
                ? look.outline
                : "none"
          }
          strokeWidth={look.name === "neon" ? 4 : 3}
          filter={
            look.name === "neon"
              ? "url(#fx-glow)"
              : look.propFilter
                ? `url(#${look.propFilter})`
                : undefined
          }
        />
      )}
      <Glow
        x={1580}
        y={230}
        r={380}
        color={look.name === "ink" ? look.cool : "#DDE6FF"}
        opacity={0.22}
      />

      {/* far buildings, slow parallax (loop is wider than the screen) */}
      {blocks.map((b) => {
        const xx = ((((b.x - far) % loop) + loop) % loop) - 260;
        if (xx > W + 50 || xx + b.w < -50) return null;
        const top = FLOOR_Y - b.h;
        const cols = Math.floor(b.w / 46);
        const rows = Math.floor((b.h - 40) / 60);
        return (
          <g key={b.seed}>
            <Wobbly
              pts={rectPts(xx, top, b.w, b.h)}
              seed={b.seed + 40}
              amp={1.1}
              fill={look.building}
              stroke={
                look.name === "original"
                  ? "#4A4E58"
                  : look.name === "neon"
                    ? "#7A5CFF"
                    : undefined
              }
            />
            {Array.from({ length: cols * rows }, (_, k) => {
              const c = k % cols;
              const r = Math.floor(k / cols);
              if (random(`lit${b.seed}-${k}`) > 0.28) return null;
              return (
                <rect
                  key={k}
                  x={xx + 16 + c * 46}
                  y={top + 26 + r * 60}
                  width={18}
                  height={26}
                  fill={look.windowLit}
                  opacity={0.8}
                  stroke={look.name === "ink" ? look.outline : "none"}
                  strokeWidth={2}
                  filter={look.name === "neon" ? "url(#fx-glow)" : undefined}
                />
              );
            })}
          </g>
        );
      })}

      <Floor scroll={near * 1.1} />

      {/* street lights, fast */}
      {Array.from({ length: 5 }, (_, i) => {
        const x =
          ((((i * lampGap - near) % (lampGap * 4)) + lampGap * 4) %
            (lampGap * 4)) -
          200;
        return (
          <g key={i}>
            {!look.grid && (
              <path
                d={`M${x + 70} 420 L${x + 120} 420 L${x + 260} ${FLOOR_Y} L${x - 70} ${FLOOR_Y} Z`}
                fill={look.warm}
                opacity={0.07 * look.glowScale}
                style={{ mixBlendMode: look.glowBlend }}
              />
            )}
            <Glow
              x={x + 95}
              y={FLOOR_Y}
              r={260}
              ry={24}
              color={look.warm}
              opacity={0.45}
            />
            <Wobbly
              pts={rectPts(x - 6, 400, 12, FLOOR_Y - 400)}
              seed={60 + i}
              fill={look.propDark}
            />
            <Wobbly
              pts={rectPts(x - 6, 394, 112, 10)}
              seed={70 + i}
              fill={look.propDark}
            />
            <Wobbly
              pts={roundRectPts(x + 66, 400, 58, 18, 8, 3)}
              seed={80 + i}
              fill={look.shade}
              stroke={look.name === "neon" ? look.warm : undefined}
            />
            <Glow
              x={x + 95}
              y={424}
              r={280}
              color={look.warm}
              opacity={0.42 + 0.03 * Math.sin(frame * 0.7 + i)}
            />
          </g>
        );
      })}

      {/* floor dashes, fastest, to sell speed */}
      {look.name === "original" &&
        Array.from({ length: 12 }, (_, i) => {
          const x = ((((i * 180 - near * 1.1) % 2160) + 2160) % 2160) - 120;
          return (
            <line
              key={i}
              x1={x}
              y1={FLOOR_Y + 40}
              x2={x + 70}
              y2={FLOOR_Y + 40}
              stroke={look.floor}
              strokeWidth={3}
              strokeLinecap="round"
            />
          );
        })}
    </g>
  );
};

/** Close-up phone with a glowing screen (light source). */
export const PhoneCloseUp: React.FC<{
  buzz: number;
  time: string;
  label: string;
}> = ({ buzz, time, label }) => {
  const frame = useCurrentFrame();
  const look = useLook();
  const scr = useSvgId("scr");
  const dx = Math.sin(frame * 2.7) * 7 * buzz;
  const rot = Math.sin(frame * 3.1) * 1.6 * buzz;
  const cx = W / 2;
  const neon = look.name === "neon";
  const ink = neon ? look.outline : "#10131C";
  const lightCol = look.name === "ink" ? look.cool : "#A9C4FF";
  return (
    <g>
      <Backdrop color={look.name === "original" ? "#08090C" : undefined} />
      <Floor y={930} />
      <Glow x={cx} y={520} r={780} color={lightCol} opacity={0.35} />
      <Glow x={cx} y={930} r={520} ry={40} color={lightCol} opacity={0.45} />
      <g transform={`translate(${dx} 0) rotate(${rot} ${cx} 520)`}>
        <defs>
          <linearGradient id={scr} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#E4EEFF" />
            <stop offset="1" stopColor="#9DB8F0" />
          </linearGradient>
        </defs>
        <Wobbly
          pts={roundRectPts(cx - 200, 150, 400, 760, look.grid ? 12 : 54, 6)}
          seed={91}
          fill={look.name === "ink" ? "#3A3530" : "#15171E"}
        />
        <rect
          x={cx - 172}
          y={190}
          width={344}
          height={680}
          rx={look.grid ? 0 : 30}
          fill={neon ? "none" : `url(#${scr})`}
          stroke={neon || look.name === "ink" ? look.outline : "none"}
          strokeWidth={neon ? 3 : 2}
          filter={neon ? "url(#fx-glow)" : undefined}
        />
        <g filter={neon ? "url(#fx-glow)" : undefined}>
          <text
            x={cx}
            y={470}
            textAnchor="middle"
            fontFamily={look.font}
            fontWeight={look.fontWeight}
            fontSize={130 * look.fontScale}
            fill={ink}
          >
            {time}
          </text>
          <text
            x={cx}
            y={545}
            textAnchor="middle"
            fontFamily={look.font}
            fontWeight={look.fontWeight}
            fontSize={44 * look.fontScale}
            fill={neon ? look.outline : "#3B3F57"}
            letterSpacing={4}
          >
            {label}
          </text>
          {/* bell */}
          <g
            transform={`translate(${cx} 660) rotate(${Math.sin(frame * 1.9) * 18 * buzz})`}
          >
            {look.grid ? (
              <g shapeRendering="crispEdges" fill={ink}>
                <rect x={-12} y={-48} width={24} height={12} />
                <rect x={-24} y={-36} width={48} height={24} />
                <rect x={-36} y={-12} width={72} height={36} />
                <rect x={-12} y={30} width={24} height={14} />
              </g>
            ) : (
              <>
                <path
                  d="M-36 20 Q-36 -40 0 -44 Q36 -40 36 20 L46 30 L-46 30 Z"
                  fill={neon ? "none" : ink}
                  stroke={neon ? ink : "none"}
                  strokeWidth={3}
                />
                <circle cx={0} cy={40} r={9} fill={ink} />
              </>
            )}
          </g>
        </g>
      </g>
    </g>
  );
};
