import React from "react";
import { Audio } from "@remotion/media";
import {
  AbsoluteFill,
  Easing,
  interpolate,
  Sequence,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Flash, SpeedLines } from "../components/Effects";
import { LookDefs } from "../components/LookFx";
import { Sfx } from "../components/Sfx";
import { Subtitles } from "../components/Subtitles";
import { RepPop } from "../components/Text";
import { TitleCard } from "../components/TitleCard";
import { SAFE_REELS, SafeContext } from "../layout";
import { LookContext } from "../looks";
import { FPS } from "../theme";
import { ChalkArrow } from "../three/Chalk";
import {
  BOARD,
  CAESAR_SPOT,
  Classroom,
  DESK,
  STUDENT_SPOT,
} from "../three/Classroom";
import { chalkboardTex, noiseTex } from "../three/textures";
import { Voxel, VoxelPose } from "../three/Voxel";
import { CameraRig } from "../three/World";
import { voice } from "../voice/lesson-06";
import { findWord, placeLines, talkAt } from "../voice/sync";
import { CAESAR_LOOK, CL, Canvas3D, CRIMSON, LessonHud, life } from "./kit";

/**
 * Lesson VI: build an emergency fund (Caesar's reserve at Pharsalus).
 * History: at Pharsalus (48 BC) Caesar held back a fourth line of
 * cohorts, which routed Pompey's cavalry charge.
 * Advice: keep 3 to 6 months of essential expenses in cash.
 * All timing comes from the voice track in src/voice/lesson-06.ts.
 */

const ease = Easing.inOut(Easing.cubic);
const GOLD = "#E8C04A";
const RED = "#FF4D4D";

// ---- timeline from the voice ----
const LINES = placeLines(
  voice,
  [0.45, 0.35, 0.25, 0.35, 0.25, 0.35, 0.35, 0.4],
  FPS,
);
const [, L2, L3, L4, L5, L6, L7, L8] = LINES;
const SHOT = {
  wide: [0, L2.from],
  battle: [L2.from, L4.from],
  reserve: [L4.from, L6.from],
  life: [L6.from, L7.from],
  idiot: [L7.from, L8.from],
  conquer: [L8.from, L8.to + 16],
  title: [L8.to + 16, L8.to + 16 + 180],
} as const;
export const LESSON_06_DURATION = SHOT.title[1];
const len = (k: keyof typeof SHOT) => SHOT[k][1] - SHOT[k][0];

// ---- board: the battle map of Pharsalus ----
const box = (ctx: CanvasRenderingContext2D, x: number, y: number, s = 5) => {
  ctx.fillRect(x, y, s, 1);
  ctx.fillRect(x, y + s - 1, s, 1);
  ctx.fillRect(x, y, 1, s);
  ctx.fillRect(x + s - 1, y, 1, s);
};
const boardTex = () =>
  chalkboardTex(
    "lesson-6",
    [
      { text: "LESSON VI", x: 4, y: 3 },
      { text: "PHARSALUS", x: 30, y: 55 },
      { text: "CAESAR", x: 6, y: 47 },
    ],
    (ctx) => {
      // Caesar's three lines
      ctx.fillStyle = "#ECECE4";
      for (const x of [10, 18, 26])
        for (let r = 0; r < 4; r++) box(ctx, x, 14 + r * 8);
      // the hidden fourth line: the reserve
      ctx.fillStyle = "#E8C04A";
      for (let r = 0; r < 3; r++) box(ctx, 36, 20 + r * 8);
      // Pompey's cavalry
      ctx.fillStyle = "#F4B6B6";
      for (let r = 0; r < 4; r++) box(ctx, 80, 14 + r * 8);
    },
  );

const BOARD_CAM = {
  position: [BOARD.x - 0.55, BOARD.y - 0.45, 1.45] as [number, number, number],
  target: [BOARD.x - 0.55, BOARD.y - 0.45, BOARD.z] as [number, number, number],
};
const STUDENT_CAM = {
  position: [STUDENT_SPOT[0] + 0.3, 2.2, -2.0] as [number, number, number],
  target: [STUDENT_SPOT[0] + 0.15, 1.95, STUDENT_SPOT[2]] as [
    number,
    number,
    number,
  ],
};
const MEDIUM_CAM = {
  position: [0.45, 2.3, 3.4] as [number, number, number],
  target: [0.1, 1.85, -1.05] as [number, number, number],
};
const CLOSE_CAM = (push: number) => ({
  position: [CAESAR_SPOT[0] + 0.15, 2.05, 2.3 - 0.5 * push] as [
    number,
    number,
    number,
  ],
  target: [CAESAR_SPOT[0], 1.75, CAESAR_SPOT[2]] as [number, number, number],
});

const pop = (f: number, at: number, fps: number) =>
  f < at
    ? 0
    : spring({ frame: f - at, fps, config: { damping: 7, stiffness: 260 } });

// ---- props ----
/** the reserve: an iron-banded strongbox on Caesar's desk */
const Chest: React.FC<{ f: number; at: number }> = ({ f, at }) => {
  const { fps } = useVideoConfig();
  const s = pop(f, at, fps);
  if (s <= 0) return null;
  const wood = noiseTex("#6B4426", 0.12, 8);
  return (
    <group
      position={[DESK.x + 0.5, DESK.h + 0.06, DESK.z - 0.2]}
      rotation={[0, -0.2, 0]}
      scale={s}
    >
      <mesh position={[0, 0.15, 0]} castShadow>
        <boxGeometry args={[0.5, 0.3, 0.32]} />
        <meshLambertMaterial map={wood} />
      </mesh>
      <mesh position={[0, 0.34, 0]} castShadow>
        <boxGeometry args={[0.53, 0.09, 0.35]} />
        <meshLambertMaterial map={wood} />
      </mesh>
      {[-0.17, 0.17].map((x) => (
        <mesh key={x} position={[x, 0.2, 0]}>
          <boxGeometry args={[0.05, 0.42, 0.37]} />
          <meshLambertMaterial color="#3A3A44" />
        </mesh>
      ))}
      <mesh position={[0, 0.27, 0.18]}>
        <boxGeometry args={[0.08, 0.1, 0.03]} />
        <meshLambertMaterial color={GOLD} />
      </mesh>
    </group>
  );
};

/** six stacks of coins: one per month of expenses */
const MonthStacks: React.FC<{ f: number; ats: number[] }> = ({ f, ats }) => {
  const { fps } = useVideoConfig();
  return (
    <group position={[DESK.x - 0.62, DESK.h + 0.06, DESK.z + 0.17]}>
      {ats.map((at, i) => {
        const s = pop(f, at, fps);
        if (s <= 0) return null;
        return (
          <group key={i} position={[i * 0.15, 0, 0]} scale={s}>
            {[0, 1, 2].map((k) => (
              <mesh key={k} position={[0, 0.02 + k * 0.04, 0]} castShadow>
                <boxGeometry args={[0.11, 0.035, 0.11]} />
                <meshLambertMaterial map={noiseTex(GOLD, 0.14, 8)} />
              </mesh>
            ))}
          </group>
        );
      })}
    </group>
  );
};

/** a toy car on the student's desk that breaks: a wheel flies off, it smokes */
const Car: React.FC<{ f: number; breakAt: number }> = ({ f, breakAt }) => {
  const broken = f >= breakAt;
  const t = broken ? (f - breakAt) / 30 : 0;
  const tilt = broken ? Math.min(0.28, t * 2) : 0;
  const base: [number, number, number] = [
    STUDENT_SPOT[0] + 0.35,
    0.87,
    STUDENT_SPOT[2] - 0.6,
  ];
  const wheels: [number, number][] = [
    [-0.12, -0.1],
    [0.12, -0.1],
    [-0.12, 0.1],
    [0.12, 0.1],
  ];
  return (
    <group position={base}>
      <group rotation={[0, 0, -tilt]}>
        <mesh position={[0, 0.1, 0]} castShadow>
          <boxGeometry args={[0.38, 0.1, 0.22]} />
          <meshLambertMaterial map={noiseTex("#C8302E", 0.1, 8)} />
        </mesh>
        <mesh position={[-0.02, 0.19, 0]} castShadow>
          <boxGeometry args={[0.2, 0.09, 0.2]} />
          <meshLambertMaterial map={noiseTex("#A8DFF5", 0.08, 8)} />
        </mesh>
        {wheels.map(([x, z], i) => {
          if (i === 1 && broken) return null;
          return (
            <mesh key={i} position={[x, 0.04, z]}>
              <boxGeometry args={[0.08, 0.08, 0.04]} />
              <meshLambertMaterial color="#1B1B1F" />
            </mesh>
          );
        })}
      </group>
      {/* the wheel that flies off */}
      {broken && (
        <mesh
          position={[
            0.12 + t * 0.6,
            Math.max(-0.83, 0.04 + 1.2 * t - 4.9 * t * t),
            -0.1 - t * 0.2,
          ]}
          rotation={[0, 0, -t * 12]}
        >
          <boxGeometry args={[0.08, 0.08, 0.04]} />
          <meshLambertMaterial color="#1B1B1F" />
        </mesh>
      )}
      {/* smoke puffs */}
      {broken &&
        [0, 1, 2, 3, 4].map((i) => {
          const life = ((f - breakAt) / 30 + i * 0.25) % 1.25;
          return (
            <mesh
              key={i}
              position={[0.05 + Math.sin(i * 2) * 0.05, 0.25 + life * 0.6, 0]}
              scale={0.6 + life * 0.8}
            >
              <boxGeometry args={[0.09, 0.09, 0.09]} />
              <meshLambertMaterial
                color="#8A8A92"
                transparent
                opacity={Math.max(0, 0.85 - life * 0.65)}
              />
            </mesh>
          );
        })}
    </group>
  );
};

// ---- key moments from the voice ----
const CHEST_AT = findWord(L4, "emergency", FPS);
const MONTHS_AT = (() => {
  const three = findWord(L5, "Three", FPS);
  const six = findWord(L5, "six", FPS);
  return [three, three + 3, three + 6, six, six + 3, six + 6];
})();

const DeskProps: React.FC<{ f: number }> = ({ f }) => (
  <>
    <Chest f={f} at={CHEST_AT} />
    <MonthStacks f={f} ats={MONTHS_AT} />
  </>
);

const caesarTalk = (f: number, fps: number): VoxelPose => ({
  ...life(f),
  talk: talkAt(LINES, f, fps),
  brow: 0.7,
  browLift: -0.1,
  mouth: -0.3,
});

// --------------------------------------------------------------------------
const WideShot: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const SLAM = 8;
  const raise = interpolate(f, [0, 5], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.quad),
  });
  const slam = interpolate(f, [5, SLAM], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  const recover = interpolate(f, [SLAM + 8, SLAM + 18], [0, 1], {
    ...CL,
    easing: ease,
  });
  let armR: [number, number, number] = [-2.8 * raise, 0, 0.15 * raise];
  if (f >= 5) armR = [-2.8 + 1.6 * slam, 0, 0.15 * (1 - slam)];
  if (f >= SLAM + 8) armR = [-1.2 + 0.85 * recover, 0, 0];
  const impact = spring({
    frame: f - SLAM,
    fps,
    config: { damping: 7, stiffness: 260 },
  });
  const flinch =
    f >= SLAM
      ? 1 -
        spring({ frame: f - SLAM, fps, config: { damping: 6, stiffness: 240 } })
      : 0;
  const shake = f >= SLAM && f < SLAM + 7 ? (1 - (f - SLAM) / 7) * 0.06 : 0;
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={2} volume={0.35} rate={1.3} />
      <Sfx name="hit" at={SLAM} volume={0.9} />
      <Canvas3D>
        <CameraRig
          position={[
            -0.3 + Math.sin(f * 7.3) * shake,
            3.3 + Math.cos(f * 9.1) * shake,
            6.4,
          ]}
          target={[0.15, 1.75, -1]}
          fov={56}
        />
        <Classroom board={boardTex()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={0.15}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            squash: f >= SLAM ? interpolate(impact, [0, 1], [0.9, 1]) : 1,
            brow: 0.9,
            armR,
            armOverride: 1,
          }}
        />
        <Voxel
          position={STUDENT_SPOT}
          facing={Math.PI - 0.35}
          pose={{
            ...life(f, 2),
            sit: 1,
            lift: 0.14 * flinch,
            squash: 1 + 0.12 * flinch,
            brow: -0.8,
            browLift: 0.6 + 0.6 * flinch,
            mouth: -0.5,
            arms: "forward",
            armBlend: 0.75,
            headYaw: 0.9 * Math.min(1, f / 40),
          }}
        />
      </Canvas3D>
      <Sequence from={SLAM} durationInFrames={9} layout="none">
        <SpeedLines cx={540} cy={1050} />
      </Sequence>
      <Sequence from={SLAM} durationInFrames={3} layout="none">
        <Flash strength={0.6} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** the battle map: cavalry charges, the reserve crushes it */
const BattleShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s0 = SHOT.battle[0];
  const reserveAt = findWord(L2, "reserve", fps) - s0;
  const chargeAt = findWord(L3, "charged", fps) - s0 - 4;
  const crushAt = findWord(L3, "crushed", fps) - s0 - 2;
  const glow =
    local >= reserveAt ? 0.6 + 0.4 * Math.sin((local - reserveAt) * 0.4) : 0;
  const charge = interpolate(local, [chargeAt, chargeAt + 12], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  const crush = interpolate(local, [crushAt, crushAt + 10], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.quad),
  });
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="shimmer" at={reserveAt} volume={0.4} />
      <Sfx name="step" at={chargeAt} volume={0.6} rate={1.3} />
      <Sfx name="step" at={chargeAt + 4} volume={0.6} rate={1.3} />
      <Sfx name="step" at={chargeAt + 8} volume={0.6} rate={1.3} />
      <Sfx name="hit" at={crushAt + 6} volume={0.8} />
      <Canvas3D>
        <CameraRig
          position={BOARD_CAM.position}
          target={BOARD_CAM.target}
          fov={62}
        />
        <Classroom board={boardTex()} coins={false} />
        {/* the reserve glows when mentioned */}
        {glow > 0 && (
          <pointLight
            color={GOLD}
            intensity={1.5 * glow}
            position={[BOARD.x - 0.8, BOARD.y, BOARD.z + 0.5]}
            decay={1.5}
          />
        )}
        <ChalkArrow a={[78, 18]} b={[48, 22]} p={charge} color="#FF8A8A" />
        <ChalkArrow a={[78, 38]} b={[48, 36]} p={charge} color="#FF8A8A" />
        <ChalkArrow a={[43, 26]} b={[70, 22]} p={crush} color="#F5D76E" />
        <ChalkArrow a={[43, 34]} b={[70, 40]} p={crush} color="#F5D76E" />
      </Canvas3D>
      <Sequence
        from={reserveAt}
        durationInFrames={chargeAt - reserveAt}
        layout="none"
      >
        <RepPop text="THE RESERVE" x={540} y={1250} size={84} color={GOLD} />
      </Sequence>
      <Sequence from={crushAt + 6} layout="none">
        <RepPop
          text="CAVALRY: CRUSHED"
          x={540}
          y={1250}
          size={74}
          color={GOLD}
        />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** "Your emergency fund is your reserve. Three to six months..." */
const ReserveShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.reserve[0];
  const point = interpolate(f, [CHEST_AT - 6, CHEST_AT], [0, 1], {
    ...CL,
    easing: ease,
  });
  const count = interpolate(f, [MONTHS_AT[0] - 6, MONTHS_AT[0]], [0, 1], {
    ...CL,
    easing: ease,
  });
  const monthsAt = findWord(L5, "months", fps);
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="hit" at={CHEST_AT - SHOT.reserve[0]} volume={0.5} rate={1.3} />
      {MONTHS_AT.map((at, i) => (
        <Sfx
          key={i}
          name="pop"
          at={at - SHOT.reserve[0]}
          volume={0.45}
          rate={0.9 + i * 0.08}
        />
      ))}
      <Canvas3D>
        <CameraRig
          position={MEDIUM_CAM.position}
          target={MEDIUM_CAM.target}
          fov={54}
        />
        <Classroom board={boardTex()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={-0.05}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            brow: 0.4,
            mouth: 0.1,
            armR: [-0.3 - 0.9 * point * (1 - count), 0, -0.15 * point],
            armL: [-1.0 * count, 0, 0.3 * count],
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
      <Sequence
        from={CHEST_AT - SHOT.reserve[0]}
        durationInFrames={MONTHS_AT[0] - CHEST_AT}
        layout="none"
      >
        <RepPop text="EMERGENCY FUND" x={540} y={620} size={80} color={GOLD} />
      </Sequence>
      <Sequence from={monthsAt - SHOT.reserve[0]} layout="none">
        <RepPop text="3-6 MONTHS" x={540} y={620} size={110} color={GOLD} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** life charges at the student: his car breaks, he loses his job */
const LifeShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.life[0];
  const breakAt = findWord(L6, "breaks", fps);
  const jobAt = findWord(L6, "job", fps);
  const chargeAt = findWord(L6, "charges", fps);
  const worry = interpolate(f, [breakAt, breakAt + 8], [0, 1], {
    ...CL,
    easing: ease,
  });
  const jolt =
    f >= chargeAt
      ? 1 -
        spring({
          frame: f - chargeAt,
          fps,
          config: { damping: 6, stiffness: 260 },
        })
      : 0;
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="hit" at={breakAt - SHOT.life[0]} volume={0.5} rate={1.4} />
      <Sfx name="pop" at={jobAt - SHOT.life[0]} volume={0.5} rate={0.6} />
      <Sfx name="hit" at={chargeAt - SHOT.life[0] + 8} volume={0.45} />
      <Canvas3D>
        <CameraRig
          position={STUDENT_CAM.position}
          target={STUDENT_CAM.target}
          fov={50}
        />
        <Classroom board={boardTex()} coins={false} />
        <Voxel
          position={STUDENT_SPOT}
          facing={Math.PI}
          pose={{
            ...life(f, 2),
            sit: 1,
            lift: 0.15 * jolt,
            squash: 1 + 0.1 * jolt,
            brow: -1 * worry,
            browLift: 0.9 * worry + 0.5 * jolt,
            mouth: -0.9 * worry,
            arms: "forward",
            armBlend: 0.8,
            headTilt: 0.15 * worry,
          }}
        />
        <Car f={f} breakAt={breakAt} />
      </Canvas3D>
      <Sequence
        from={jobAt - SHOT.life[0]}
        durationInFrames={chargeAt - jobAt}
        layout="none"
      >
        <RepPop text="YOU'RE FIRED" x={540} y={560} size={96} color={RED} />
      </Sequence>
      <Sequence
        from={chargeAt - SHOT.life[0]}
        durationInFrames={9}
        layout="none"
      >
        <SpeedLines cx={540} cy={900} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const IdiotShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.idiot[0];
  const worstAt = findWord(L7, "worst", fps);
  const cardAt = findWord(L7, "credit", fps);
  const idiotAt = findWord(L7, "fucking", fps);
  const point = interpolate(f, [idiotAt - 6, idiotAt], [0, 1], {
    ...CL,
    easing: ease,
  });
  const cam = CLOSE_CAM(
    interpolate(local, [0, 120], [0, 1], { ...CL, easing: ease }),
  );
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="fall" at={worstAt - SHOT.idiot[0]} volume={0.45} />
      <Sfx name="pop" at={cardAt - SHOT.idiot[0]} volume={0.5} rate={0.7} />
      <Canvas3D>
        <CameraRig position={cam.position} target={cam.target} fov={48} />
        <Classroom board={boardTex()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={0}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            brow: 0.8 + 0.2 * point,
            browLift: -0.2,
            mouth: -0.6,
            lean: 8 * point,
            armR: [-0.3 - 1.25 * point, 0, 0.1 * point],
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
      <Sequence
        from={worstAt - SHOT.idiot[0]}
        durationInFrames={cardAt - worstAt}
        layout="none"
      >
        <RepPop text="SOLD AT A LOSS" x={540} y={420} size={84} color={RED} />
      </Sequence>
      <Sequence from={cardAt - SHOT.idiot[0]} layout="none">
        <RepPop text="24% INTEREST" x={540} y={420} size={90} color={RED} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const ConquerShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.conquer[0];
  const firstAt = findWord(L8, "first", fps);
  const conquerAt = findWord(L8, "conquer", fps);
  const pat =
    interpolate(f, [firstAt - 8, firstAt], [0, 1], { ...CL, easing: ease }) *
    (1 - interpolate(f, [conquerAt - 6, conquerAt], [0, 1], CL));
  const triumph = interpolate(f, [conquerAt - 4, conquerAt + 4], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.back(1.5)),
  });
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="shimmer" at={conquerAt - SHOT.conquer[0]} volume={0.55} />
      <Canvas3D>
        <CameraRig
          position={MEDIUM_CAM.position}
          target={MEDIUM_CAM.target}
          fov={54}
        />
        <Classroom board={boardTex()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={-0.1}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            brow: 0.5 - 0.3 * triumph,
            mouth: 0.2 + 0.7 * triumph,
            headTilt: -0.1 * triumph,
            armL: [-1.0 * pat, 0, 0.6 * pat],
            armR: [-0.3 - 2.6 * triumph, 0, 0.15 * triumph],
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
      <Sequence from={conquerAt - SHOT.conquer[0]} layout="none">
        <RepPop
          text="VENI VIDI VICI"
          x={540}
          y={560}
          size={84}
          color={CRIMSON}
        />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
export const Lesson06: React.FC = () => (
  <SafeContext.Provider value={SAFE_REELS}>
    <LookContext.Provider value={CAESAR_LOOK}>
      <AbsoluteFill style={{ background: "#000" }}>
        <LookDefs />
        <Sfx name="hum" at={0} duration={SHOT.title[0]} loop volume={0.12} />
        {LINES.map((l) =>
          l.src ? (
            <Sequence
              key={l.id}
              from={l.from}
              layout="none"
              name={`voice:${l.id}`}
            >
              <Audio src={staticFile(l.src)} />
            </Sequence>
          ) : null,
        )}

        <Sequence
          from={SHOT.wide[0]}
          durationInFrames={len("wide")}
          name="Wide: slam"
        >
          <WideShot />
        </Sequence>
        <Sequence
          from={SHOT.battle[0]}
          durationInFrames={len("battle")}
          name="Board: Pharsalus"
        >
          <BattleShot />
        </Sequence>
        <Sequence
          from={SHOT.reserve[0]}
          durationInFrames={len("reserve")}
          name="Desk: the reserve"
        >
          <ReserveShot />
        </Sequence>
        <Sequence
          from={SHOT.life[0]}
          durationInFrames={len("life")}
          name="Student: life charges"
        >
          <LifeShot />
        </Sequence>
        <Sequence
          from={SHOT.idiot[0]}
          durationInFrames={len("idiot")}
          name="Caesar: no reserve"
        >
          <IdiotShot />
        </Sequence>
        <Sequence
          from={SHOT.conquer[0]}
          durationInFrames={len("conquer")}
          name="Caesar: then conquer"
        >
          <ConquerShot />
        </Sequence>
        <Sequence
          from={SHOT.title[0]}
          durationInFrames={len("title")}
          name="Title card"
        >
          <TitleCard
            word="RESERVE"
            line1="3-6 months of cash, first."
            line2="Lesson VI."
            startAt={6}
            letterEvery={5}
            underlineFrames={20}
            line1At={60}
            line2At={100}
            fadeFrames={40}
          />
        </Sequence>

        <Subtitles lines={LINES} />
        <LessonHud numeral="VI" hideFrom={SHOT.title[0]} />
      </AbsoluteFill>
    </LookContext.Provider>
  </SafeContext.Provider>
);
