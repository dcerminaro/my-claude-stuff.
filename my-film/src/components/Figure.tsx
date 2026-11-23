import React from "react";
import { C } from "../theme";
import { clamp, lerp, useSvgId } from "./util";

/**
 * The channel's character, side-on, facing right.
 * Big round head, no neck, dot eyes, one-line brows and mouth,
 * long noodle limbs with no fingers.
 *
 * variant "hero"   = the main character (mustard)
 * variant "shadow" = his inner voice (black, violet glowing outline, slit eyes)
 *
 * Coordinates: (x, y) is the point between his feet on the floor.
 * Standing height is about 300px at scale 1.
 */
export type Pose = {
  squat?: number; // 0 standing .. 1 deep squat
  lift?: number; // px off the ground (jumps, run bob)
  squash?: number; // 1 normal, <1 squashed, >1 stretched
  lean?: number; // degrees, + leans forward
  brow?: number; // -1 worried/sad .. 0 neutral .. 1 determined/angry
  browLift?: number; // -1 low .. 1 raised
  mouth?: number; // -1 frown .. 1 smile
  blink?: number; // 0 open .. 1 closed
  arms?: "idle" | "forward" | "run" | "up";
  armBlend?: number; // 0 = idle arms, 1 = full "arms" pose
  runPhase?: number; // radians; set to run
  headband?: boolean;
  t?: number; // frame, for little idle motions
};

const UPPER = 62;
const LOWER = 62;
const ARM_A = 48;
const ARM_B = 48;

type V = { x: number; y: number };

const ik = (h: V, f: V, a: number, b: number, bend: 1 | -1) => {
  let dx = f.x - h.x;
  let dy = f.y - h.y;
  let d = Math.hypot(dx, dy);
  const max = a + b - 0.5;
  if (d > max) {
    dx *= max / d;
    dy *= max / d;
    d = max;
  }
  d = Math.max(d, 1);
  const cosA = clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1);
  const ang = Math.atan2(dy, dx) + bend * Math.acos(cosA);
  return {
    knee: { x: h.x + a * Math.cos(ang), y: h.y + a * Math.sin(ang) },
    end: { x: h.x + dx, y: h.y + dy },
  };
};

/** quadratic curve through the joint, so limbs read as noodles */
const noodle = (a: V, k: V, b: V) => {
  const cx = 2 * k.x - (a.x + b.x) / 2;
  const cy = 2 * k.y - (a.y + b.y) / 2;
  return `M${a.x.toFixed(1)} ${a.y.toFixed(1)} Q${cx.toFixed(1)} ${cy.toFixed(1)} ${b.x.toFixed(1)} ${b.y.toFixed(1)}`;
};

export const Figure: React.FC<{
  x: number;
  y: number;
  scale?: number;
  pose?: Pose;
  variant?: "hero" | "shadow";
  opacity?: number;
  emerge?: number; // 0..1, grows up out of the floor
  eyeGlow?: number; // shadow only, 0..1
}> = ({ x, y, scale = 1, pose = {}, variant = "hero", opacity = 1, emerge = 1, eyeGlow = 1 }) => {
  const glowId = useSvgId("fig-glow");
  const clipId = useSvgId("fig-clip");
  const shadow = variant === "shadow";

  const {
    squat = 0,
    lift = 0,
    squash = 1,
    lean = 0,
    brow = 0,
    browLift = 0,
    mouth = 0,
    blink = 0,
    arms = "idle",
    armBlend = 0,
    runPhase,
    headband = false,
    t = 0,
  } = pose;

  const running = runPhase !== undefined;

  // ---------- hips & feet ----------
  const hip: V = running
    ? { x: 0, y: -112 - lift }
    : { x: -22 * squat, y: -(118 - 58 * squat) - lift };

  const feet: V[] = running
    ? [0, Math.PI].map((off) => {
        const p = runPhase! + off;
        return { x: 45 * Math.sin(p), y: -Math.max(0, Math.cos(p)) * 38 - lift * 0.3 };
      })
    : [
        { x: -8, y: -lift + Math.min(lift, 30) * 0.6 },
        { x: 12, y: -lift + Math.min(lift, 30) * 0.4 },
      ];

  const legs = feet.map((f) => ik(hip, f, UPPER, LOWER, -1));

  // ---------- torso frame (arms, head live here) ----------
  const torsoAngle = lean + 18 * squat;
  const shoulder = (side: number): V => ({ x: side * 5, y: -78 });

  const handTarget = (side: number, idx: number): V => {
    const s = shoulder(side);
    const idle: V = { x: s.x + 8 + Math.sin(t * 0.08 + idx) * 2, y: s.y + 86 };
    let goal: V = idle;
    if (arms === "forward") goal = { x: s.x + 86, y: s.y + 12 };
    // raised in a V so the arms read clearly against the head
    if (arms === "up") goal = idx ? { x: s.x + 75, y: s.y - 82 } : { x: s.x - 55, y: s.y - 92 };
    if (arms === "run") {
      const sw = 0.95 * Math.sin((runPhase ?? 0) + (idx ? 0 : Math.PI));
      goal = { x: s.x + 82 * Math.sin(sw), y: s.y + 82 * Math.cos(sw) };
    }
    return { x: lerp(idle.x, goal.x, armBlend), y: lerp(idle.y, goal.y, armBlend) };
  };
  const armPaths = [0, 1].map((idx) => {
    const side = idx ? 1 : -1;
    const s = shoulder(side);
    const r = ik(s, handTarget(side, idx), ARM_A, ARM_B, 1);
    return noodle(s, r.knee, r.end);
  });

  // ---------- colours ----------
  const body = shadow ? "#000" : C.hero;
  const far = shadow ? "#000" : C.heroDark;
  const outline = shadow ? C.accent : "none";

  const limb = (d: string, color: string, key: string) =>
    shadow ? (
      <g key={key}>
        <path d={d} stroke={C.accent} strokeWidth={20} fill="none" strokeLinecap="round" />
        <path d={d} stroke="#000" strokeWidth={14} fill="none" strokeLinecap="round" />
      </g>
    ) : (
      <path key={key} d={d} stroke={color} strokeWidth={14} fill="none" strokeLinecap="round" />
    );

  const legPaths = legs.map((l) => noodle(hip, l.knee, l.end));

  // squash & stretch around the feet, keeping volume
  const sy = squash * emerge;
  const sx = 1 / Math.sqrt(squash);

  const headY = -138;
  const eyeY = headY - 4;
  const eyeR = 5.5;
  const browY = headY - 24 - browLift * 8;
  const browA = brow * 20;

  return (
    <g transform={`translate(${x} ${y}) scale(${scale * sx} ${scale * sy})`} opacity={opacity}>
      <defs>
        <filter id={glowId} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="7" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        <clipPath id={clipId}>
          <circle cx={0} cy={headY} r={58} />
        </clipPath>
      </defs>

      {/* contact shadow on the floor */}
      {!shadow && (
        <ellipse cx={0} cy={0} rx={62 * clamp(1 - lift / 250, 0.3, 1)} ry={8} fill="#000" opacity={0.5} />
      )}

      <g filter={shadow ? `url(#${glowId})` : undefined}>
        {/* far leg */}
        {limb(legPaths[0], far, "leg0")}

        <g transform={`translate(${hip.x} ${hip.y}) rotate(${torsoAngle})`}>
          {/* far arm */}
          {limb(armPaths[0], far, "arm0")}
          {/* torso */}
          <rect x={-32} y={-100} width={64} height={112} rx={32} fill={body} stroke={outline} strokeWidth={3} />
          {/* head (sits right on the body, no neck) */}
          <circle cx={0} cy={headY} r={58} fill={body} stroke={outline} strokeWidth={3} />

          {headband && !shadow && (
            <g>
              <rect x={-62} y={headY - 40} width={124} height={15} fill={C.headband} clipPath={`url(#${clipId})`} />
              {[0, 1].map((i) => {
                const w = Math.sin(t * 0.5 + i * 1.3) * 8;
                return (
                  <path
                    key={i}
                    d={`M-50 ${headY - 32} q-22 ${w + 4 + i * 6} -44 ${w * 0.6 + 10 + i * 12}`}
                    stroke={C.headband}
                    strokeWidth={8}
                    fill="none"
                    strokeLinecap="round"
                  />
                );
              })}
            </g>
          )}

          {/* face, profile facing right */}
          {shadow ? (
            <g style={{ mixBlendMode: "screen" }} opacity={eyeGlow}>
              {[18, 41].map((ex, i) => (
                <ellipse
                  key={ex}
                  cx={ex}
                  cy={eyeY}
                  rx={11}
                  ry={2.6}
                  fill={C.accent}
                  transform={`rotate(${i ? -14 : 14} ${ex} ${eyeY})`}
                />
              ))}
            </g>
          ) : (
            <g>
              {[18, 40].map((ex) => (
                <ellipse key={ex} cx={ex} cy={eyeY} rx={eyeR} ry={eyeR * (1 - 0.9 * blink)} fill={C.ink} />
              ))}
              {[18, 40].map((ex, i) => (
                <line
                  key={`b${ex}`}
                  x1={ex - 9}
                  y1={browY}
                  x2={ex + 9}
                  y2={browY}
                  stroke={C.ink}
                  strokeWidth={4.5}
                  strokeLinecap="round"
                  transform={`rotate(${i ? -browA : browA} ${ex} ${browY})`}
                />
              ))}
              <path
                d={`M17 ${headY + 22} Q29 ${headY + 22 + mouth * 10} 41 ${headY + 22}`}
                stroke={C.ink}
                strokeWidth={4}
                fill="none"
                strokeLinecap="round"
              />
            </g>
          )}

          {/* near arm */}
          {limb(armPaths[1], body, "arm1")}
        </g>

        {/* near leg */}
        {limb(legPaths[1], body, "leg1")}
      </g>
    </g>
  );
};
