import React from "react";
import { useLook } from "../looks";
import { clamp, lerp, useSvgId } from "./util";

/**
 * The channel's character, side-on, facing right.
 * Big round head, no neck, dot eyes, one-line brows and mouth,
 * long noodle limbs with no fingers.
 *
 * variant "hero"   = the main character
 * variant "shadow" = his inner voice (black, accent outline, slit eyes)
 *
 * The drawing adapts to the current look (see src/looks.ts). In the
 * blocky look he is built from square blocks instead.
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

/** straight block segment (blocky look) */
const segment = (a: V, b: V, w: number) => {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const len = Math.hypot(dx, dy) || 1;
  const nx = (-dy / len) * (w / 2);
  const ny = (dx / len) * (w / 2);
  // extend a little so joints overlap
  const ex = (dx / len) * (w / 3);
  const ey = (dy / len) * (w / 3);
  const p = [
    [a.x + nx - ex, a.y + ny - ey],
    [b.x + nx + ex, b.y + ny + ey],
    [b.x - nx + ex, b.y - ny + ey],
    [a.x - nx - ex, a.y - ny - ey],
  ];
  return `M${p.map((q) => q.map((v) => v.toFixed(1)).join(" ")).join(" L")} Z`;
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
}> = ({
  x,
  y,
  scale = 1,
  pose = {},
  variant = "hero",
  opacity = 1,
  emerge = 1,
  eyeGlow = 1,
}) => {
  const look = useLook();
  const clipId = useSvgId("fig-clip");
  const shadow = variant === "shadow";
  const blocky = look.grid > 0;

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
        return {
          x: 45 * Math.sin(p),
          y: -Math.max(0, Math.cos(p)) * 38 - lift * 0.3,
        };
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
    if (arms === "up")
      goal = idx ? { x: s.x + 75, y: s.y - 82 } : { x: s.x - 55, y: s.y - 92 };
    if (arms === "run") {
      const sw = 0.95 * Math.sin((runPhase ?? 0) + (idx ? 0 : Math.PI));
      goal = { x: s.x + 82 * Math.sin(sw), y: s.y + 82 * Math.cos(sw) };
    }
    return {
      x: lerp(idle.x, goal.x, armBlend),
      y: lerp(idle.y, goal.y, armBlend),
    };
  };
  const armJoints = [0, 1].map((idx) => {
    const side = idx ? 1 : -1;
    const s = shoulder(side);
    const r = ik(s, handTarget(side, idx), ARM_A, ARM_B, 1);
    return { s, k: r.knee, e: r.end };
  });

  // ---------- colours ----------
  const body = shadow ? look.shadowBody : look.hero;
  const far = shadow ? look.shadowBody : look.heroDark;
  const line = shadow ? look.accent : look.heroLine;
  const lineW = shadow
    ? look.name === "neon"
      ? 4
      : 3
    : look.name === "neon"
      ? 4
      : look.name === "ink"
        ? 3
        : blocky
          ? 3
          : 0;
  const hasLine = line !== "none" && lineW > 0;
  const limbW = look.limbW;
  const filterId = shadow ? look.shadowFilter : look.figureFilter;

  const limbFromJoints = (a: V, k: V, b: V, color: string, key: string) => {
    if (blocky) {
      return (
        <g key={key}>
          {[segment(a, k, limbW), segment(k, b, limbW)].map((d, i) => (
            <path
              key={i}
              d={d}
              fill={color}
              stroke={hasLine ? line : "none"}
              strokeWidth={lineW}
            />
          ))}
        </g>
      );
    }
    const d = noodle(a, k, b);
    return (
      <g key={key}>
        {hasLine && (
          <path
            d={d}
            stroke={line}
            strokeWidth={limbW + lineW * 2}
            fill="none"
            strokeLinecap="round"
          />
        )}
        <path
          d={d}
          stroke={color}
          strokeWidth={limbW}
          fill="none"
          strokeLinecap="round"
        />
      </g>
    );
  };

  // squash & stretch around the feet, keeping volume
  const sy = squash * emerge;
  const sx = 1 / Math.sqrt(squash);

  const headY = -138;
  const eyeY = headY - 4;
  const eyeR = 5.5;
  const browY = headY - 24 - browLift * 8;
  const browA = brow * 20;
  const HEAD = 58;

  const headShape = blocky ? (
    <rect
      x={-HEAD}
      y={headY - HEAD}
      width={HEAD * 2}
      height={HEAD * 2}
      fill={body}
      stroke={hasLine ? line : "none"}
      strokeWidth={lineW}
    />
  ) : (
    <circle
      cx={0}
      cy={headY}
      r={HEAD}
      fill={body}
      stroke={hasLine ? line : "none"}
      strokeWidth={lineW}
    />
  );
  const torsoShape = blocky ? (
    <rect
      x={-34}
      y={-100}
      width={68}
      height={112}
      fill={body}
      stroke={hasLine ? line : "none"}
      strokeWidth={lineW}
    />
  ) : (
    <rect
      x={-32}
      y={-100}
      width={64}
      height={112}
      rx={32}
      fill={body}
      stroke={hasLine ? line : "none"}
      strokeWidth={lineW}
    />
  );

  const face = shadow ? (
    <g
      opacity={eyeGlow}
      filter={look.name === "ink" ? undefined : "url(#fx-glow)"}
    >
      {[18, 41].map((ex, i) =>
        blocky ? (
          <rect
            key={ex}
            x={ex - 12}
            y={eyeY - 3 + (i ? -3 : 3)}
            width={24}
            height={6}
            fill={look.accent}
          />
        ) : (
          <ellipse
            key={ex}
            cx={ex}
            cy={eyeY}
            rx={11}
            ry={2.6}
            fill={look.accent}
            transform={`rotate(${i ? -14 : 14} ${ex} ${eyeY})`}
          />
        ),
      )}
    </g>
  ) : blocky ? (
    <g shapeRendering="crispEdges">
      {[18, 40].map((ex) => (
        <rect
          key={ex}
          x={ex - 6}
          y={eyeY - 6 + 12 * blink * 0.45}
          width={12}
          height={12 * (1 - 0.9 * blink)}
          fill={look.face}
        />
      ))}
      {[18, 40].map((ex, i) => (
        <rect
          key={`b${ex}`}
          x={ex - 11}
          y={browY - 3}
          width={22}
          height={6}
          fill={look.face}
          transform={`rotate(${i ? -browA : browA} ${ex} ${browY})`}
        />
      ))}
      {/* stepped mouth: three blocks */}
      {[-1, 0, 1].map((k) => (
        <rect
          key={`m${k}`}
          x={29 + k * 8 - 4}
          y={headY + 20 - (k ? mouth * 6 : 0)}
          width={8}
          height={5}
          fill={look.face}
        />
      ))}
    </g>
  ) : (
    <g>
      {[18, 40].map((ex) => (
        <ellipse
          key={ex}
          cx={ex}
          cy={eyeY}
          rx={eyeR}
          ry={eyeR * (1 - 0.9 * blink)}
          fill={look.face}
        />
      ))}
      {[18, 40].map((ex, i) => (
        <line
          key={`b${ex}`}
          x1={ex - 9}
          y1={browY}
          x2={ex + 9}
          y2={browY}
          stroke={look.face}
          strokeWidth={4.5}
          strokeLinecap="round"
          transform={`rotate(${i ? -browA : browA} ${ex} ${browY})`}
        />
      ))}
      <path
        d={`M17 ${headY + 22} Q29 ${headY + 22 + mouth * 10} 41 ${headY + 22}`}
        stroke={look.face}
        strokeWidth={4}
        fill="none"
        strokeLinecap="round"
      />
    </g>
  );

  const band =
    headband && !shadow ? (
      <g>
        {blocky ? (
          <rect
            x={-HEAD}
            y={headY - 40}
            width={HEAD * 2}
            height={14}
            fill={look.headband}
          />
        ) : (
          <rect
            x={-62}
            y={headY - 40}
            width={124}
            height={15}
            fill={look.headband}
            clipPath={`url(#${clipId})`}
          />
        )}
        {[0, 1].map((i) => {
          const w = Math.sin(t * 0.5 + i * 1.3) * 8;
          return (
            <path
              key={i}
              d={`M-50 ${headY - 32} q-22 ${w + 4 + i * 6} -44 ${w * 0.6 + 10 + i * 12}`}
              stroke={look.headband}
              strokeWidth={8}
              fill="none"
              strokeLinecap={blocky ? "square" : "round"}
            />
          );
        })}
      </g>
    ) : null;

  const legPaths = legs.map((l, i) =>
    limbFromJoints(hip, l.knee, l.end, i ? body : far, `leg${i}`),
  );
  const armPaths = armJoints.map((a, i) =>
    limbFromJoints(a.s, a.k, a.e, i ? body : far, `arm${i}`),
  );

  return (
    <g
      transform={`translate(${x} ${y}) scale(${scale * sx} ${scale * sy})`}
      opacity={opacity}
    >
      <defs>
        <clipPath id={clipId}>
          <circle cx={0} cy={headY} r={HEAD} />
        </clipPath>
      </defs>

      {/* contact shadow on the floor */}
      {!shadow && look.name !== "neon" && (
        <ellipse
          cx={0}
          cy={0}
          rx={62 * clamp(1 - lift / 250, 0.3, 1)}
          ry={8}
          fill="#000"
          opacity={look.name === "ink" ? 0.18 : 0.5}
        />
      )}

      <g filter={filterId ? `url(#${filterId})` : undefined}>
        {legPaths[0]}
        <g transform={`translate(${hip.x} ${hip.y}) rotate(${torsoAngle})`}>
          {armPaths[0]}
          {torsoShape}
          {headShape}
          {band}
          {face}
          {armPaths[1]}
        </g>
        {legPaths[1]}
      </g>
    </g>
  );
};
