import React from "react";
import { random, useCurrentFrame } from "remotion";
import { comic } from "../fonts";
import { C, FLOOR_Y, H, W } from "../theme";
import { Glow } from "./Glow";
import { Wobbly } from "./Wobbly";
import { circlePts, rectPts, roundRectPts, useSvgId } from "./util";

export const Floor: React.FC<{ y?: number }> = ({ y = FLOOR_Y }) => (
  <g>
    <rect x={0} y={y} width={W} height={H - y} fill={C.bgDeep} />
    <line x1={0} y1={y} x2={W} y2={y} stroke={C.floor} strokeWidth={2} />
  </g>
);

/** Floor lamp. Its bulb is the light source. */
export const Lamp: React.FC<{ x: number; flicker?: number }> = ({ x, flicker = 0 }) => {
  const frame = useCurrentFrame();
  const coneId = useSvgId("cone");
  const k = 1 + flicker * 0.06 * Math.sin(frame * 0.9) * Math.sin(frame * 0.37);
  return (
    <g>
      <defs>
        <linearGradient id={coneId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={C.warmLight} stopOpacity={0.22 * k} />
          <stop offset="1" stopColor={C.warmLight} stopOpacity={0} />
        </linearGradient>
      </defs>
      <Glow x={x} y={540} r={620} color={C.warmLight} opacity={0.32 * k} />
      <path d={`M${x - 60} 560 L${x + 60} 560 L${x + 230} ${FLOOR_Y} L${x - 230} ${FLOOR_Y} Z`} fill={`url(#${coneId})`} style={{ mixBlendMode: "screen" }} />
      <Glow x={x} y={FLOOR_Y} r={360} ry={34} color={C.warmLight} opacity={0.5 * k} />
      <Wobbly pts={rectPts(x - 4, 560, 8, FLOOR_Y - 572)} seed={11} fill={C.propDark} />
      <Wobbly pts={[[x - 55, FLOOR_Y], [x + 55, FLOOR_Y], [x + 40, FLOOR_Y - 14], [x - 40, FLOOR_Y - 14]]} seed={12} />
      <Wobbly pts={[[x - 72, 560], [x + 72, 560], [x + 44, 462], [x - 44, 462]]} seed={13} fill="#2A2418" />
      <Glow x={x} y={566} r={120} color="#FFE2A8" opacity={0.9 * k} />
    </g>
  );
};

/** Window with the moon in it. */
export const MoonWindow: React.FC<{ x: number; y: number }> = ({ x, y }) => (
  <g>
    <Glow x={x + 160} y={y + 120} r={420} color={C.coolLight} opacity={0.16} />
    <Wobbly pts={rectPts(x, y, 320, 320)} seed={21} fill="#111522" />
    <circle cx={x + 205} cy={y + 105} r={40} fill="#E8E6D9" />
    <Glow x={x + 205} y={y + 105} r={150} color="#DDE6FF" opacity={0.5} />
    <Wobbly pts={[[x + 160, y], [x + 160, y + 320]]} closed={false} seed={22} />
    <Wobbly pts={[[x, y + 160], [x + 320, y + 160]]} closed={false} seed={23} />
    <Wobbly pts={rectPts(x - 18, y + 320, 356, 16)} seed={24} />
    <Glow x={x + 160} y={FLOOR_Y} r={260} ry={22} color={C.coolLight} opacity={0.14} />
  </g>
);

export const Dumbbell: React.FC<{ x: number }> = ({ x }) => (
  <g>
    <Wobbly pts={rectPts(x - 40, FLOOR_Y - 22, 80, 8)} seed={31} amp={1} />
    <Wobbly pts={circlePts(x - 46, FLOOR_Y - 18, 18, 16)} seed={32} amp={1} fill={C.propDark} />
    <Wobbly pts={circlePts(x + 46, FLOOR_Y - 18, 18, 16)} seed={33} amp={1} fill={C.propDark} />
  </g>
);

/** His small room at night: lamp, moon window, dumbbell. */
export const Room: React.FC = () => (
  <g>
    <rect x={0} y={0} width={W} height={H} fill={C.bg} />
    <MoonWindow x={1260} y={290} />
    <Floor />
    <Dumbbell x={1260} />
    <Lamp x={470} flicker={1} />
  </g>
);

/** Night city that scrolls past. `scroll` = pixels travelled. */
export const City: React.FC<{ scroll: number }> = ({ scroll }) => {
  const frame = useCurrentFrame();
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

  return (
    <g>
      <rect x={0} y={0} width={W} height={H} fill="#0B0D13" />
      <circle cx={1580} cy={230} r={46} fill="#E8E6D9" />
      <Glow x={1580} y={230} r={380} color="#DDE6FF" opacity={0.22} />

      {/* far buildings, slow parallax */}
      {[0].map((rep) =>
        blocks.map((b) => {
          // loop is wider than the screen, so one wrapped copy is enough
          const xx = (((b.x - far) % loop) + loop) % loop - 260;
          if (xx > W + 50 || xx + b.w < -50) return null;
          const top = FLOOR_Y - b.h;
          const cols = Math.floor(b.w / 46);
          const rows = Math.floor((b.h - 40) / 60);
          return (
            <g key={`${rep}-${b.seed}`}>
              <Wobbly pts={rectPts(xx, top, b.w, b.h)} seed={b.seed + 40} amp={1.1} fill="#141722" stroke="#4A4E58" />
              {Array.from({ length: cols * rows }, (_, k) => {
                const c = k % cols;
                const r = Math.floor(k / cols);
                if (random(`lit${b.seed}-${k}`) > 0.28) return null;
                return (
                  <rect key={k} x={xx + 16 + c * 46} y={top + 26 + r * 60} width={18} height={26} fill="#FFD37A" opacity={0.75} />
                );
              })}
            </g>
          );
        }),
      )}

      <Floor />

      {/* street lights, fast */}
      {Array.from({ length: 5 }, (_, i) => {
        const x = ((i * lampGap - near) % (lampGap * 4) + lampGap * 4) % (lampGap * 4) - 200;
        return (
          <g key={i}>
            <path d={`M${x + 70} 420 L${x + 120} 420 L${x + 260} ${FLOOR_Y} L${x - 70} ${FLOOR_Y} Z`} fill={C.warmLight} opacity={0.07} style={{ mixBlendMode: "screen" }} />
            <Glow x={x + 95} y={FLOOR_Y} r={260} ry={24} color={C.warmLight} opacity={0.45} />
            <Wobbly pts={rectPts(x - 5, 400, 10, FLOOR_Y - 400)} seed={60 + i} fill={C.propDark} />
            <Wobbly pts={rectPts(x - 5, 396, 110, 8)} seed={70 + i} fill={C.propDark} />
            <Wobbly pts={roundRectPts(x + 66, 400, 58, 18, 8, 3)} seed={80 + i} fill="#3A3220" />
            <Glow x={x + 95} y={424} r={280} color={C.warmLight} opacity={0.42 + 0.03 * Math.sin(frame * 0.7 + i)} />
          </g>
        );
      })}

      {/* floor dashes, fastest, to sell speed */}
      {Array.from({ length: 12 }, (_, i) => {
        const x = ((i * 180 - near * 1.1) % 2160 + 2160) % 2160 - 120;
        return <line key={i} x1={x} y1={FLOOR_Y + 40} x2={x + 70} y2={FLOOR_Y + 40} stroke={C.floor} strokeWidth={3} strokeLinecap="round" />;
      })}
    </g>
  );
};

/** Close-up phone with a glowing screen (light source). */
export const PhoneCloseUp: React.FC<{ buzz: number; time: string; label: string }> = ({ buzz, time, label }) => {
  const frame = useCurrentFrame();
  const scr = useSvgId("scr");
  const dx = Math.sin(frame * 2.7) * 7 * buzz;
  const rot = Math.sin(frame * 3.1) * 1.6 * buzz;
  const cx = W / 2;
  return (
    <g>
      <rect x={0} y={0} width={W} height={H} fill="#08090C" />
      <Floor y={930} />
      <Glow x={cx} y={520} r={780} color="#A9C4FF" opacity={0.35} />
      <Glow x={cx} y={930} r={520} ry={40} color="#A9C4FF" opacity={0.45} />
      <g transform={`translate(${dx} 0) rotate(${rot} ${cx} 520)`}>
        <defs>
          <linearGradient id={scr} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#E4EEFF" />
            <stop offset="1" stopColor="#9DB8F0" />
          </linearGradient>
        </defs>
        <Wobbly pts={roundRectPts(cx - 200, 150, 400, 760, 54, 6)} seed={91} fill="#15171E" />
        <rect x={cx - 172} y={190} width={344} height={680} rx={30} fill={`url(#${scr})`} />
        <text x={cx} y={470} textAnchor="middle" fontFamily={comic} fontWeight={700} fontSize={130} fill="#10131C">
          {time}
        </text>
        <text x={cx} y={545} textAnchor="middle" fontFamily={comic} fontWeight={700} fontSize={44} fill="#3B3F57" letterSpacing={4}>
          {label}
        </text>
        {/* bell */}
        <g transform={`translate(${cx} 660) rotate(${Math.sin(frame * 1.9) * 18 * buzz})`}>
          <path d="M-36 20 Q-36 -40 0 -44 Q36 -40 36 20 L46 30 L-46 30 Z" fill="#10131C" />
          <circle cx={0} cy={40} r={9} fill="#10131C" />
        </g>
      </g>
    </g>
  );
};
