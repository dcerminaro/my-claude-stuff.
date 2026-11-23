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
import { boardPos, ChalkLine } from "../three/Chalk";
import {
  BOARD,
  CAESAR_SPOT,
  Classroom,
  DESK,
  STUDENT_SPOT,
} from "../three/Classroom";
import { calendarTex, chalkboardTex, noiseTex } from "../three/textures";
import { Voxel, VoxelPose } from "../three/Voxel";
import { CameraRig, Glow3D } from "../three/World";
import { voice } from "../voice/lesson-05";
import { findWord, placeLines, talkAt } from "../voice/sync";
import { CAESAR_LOOK, CL, Canvas3D, CRIMSON, LessonHud, life } from "./kit";

/**
 * Lesson V: you can't time the market (beware the Ides of March).
 * Claim used: some of the best market days come right after the worst,
 * and missing a handful of them can roughly halve long-term returns
 * (J.P. Morgan's annual "missing the best days" studies).
 * All timing comes from the voice track in src/voice/lesson-05.ts.
 */

const ease = Easing.inOut(Easing.cubic);
const GREEN = "#4CC26A";
const RED = "#FF4D4D";
const MYSTIC = "#B07CFF";

// ---- timeline from the voice ----
const LINES = placeLines(
  voice,
  [0.45, 0.35, 0.3, 0.3, 0.2, 0.4, 0.25, 0.4],
  FPS,
);
const [, L2, L3, L4, L5, L6, L7, L8] = LINES;
const SHOT = {
  wide: [0, L2.from],
  ides: [L2.from, L3.from],
  stabbed: [L3.from, L4.from],
  student: [L4.from, L5.from],
  idiot: [L5.from, L6.from],
  chart: [L6.from, L8.from],
  smash: [L8.from, L8.to + 16],
  title: [L8.to + 16, L8.to + 16 + 180],
} as const;
export const LESSON_05_DURATION = SHOT.title[1];
const len = (k: keyof typeof SHOT) => SHOT[k][1] - SHOT[k][0];

// ---- board ----
const boardTex = () =>
  chalkboardTex(
    "lesson-5",
    [
      { text: "LESSON V", x: 4, y: 3 },
      { text: "IDES", x: 98, y: 14 },
      { text: "MAR XV", x: 90, y: 50 },
    ],
    (ctx) => {
      ctx.fillStyle = "#ECECE4";
      ctx.fillRect(8, 12, 1, 47);
      ctx.fillRect(8, 58, 80, 1);
      // chalk calendar page with a dagger through it
      ctx.fillRect(96, 24, 22, 1);
      ctx.fillRect(96, 46, 22, 1);
      ctx.fillRect(96, 24, 1, 22);
      ctx.fillRect(117, 24, 1, 22);
      ctx.fillStyle = "#F4B6B6";
      ctx.fillRect(97, 25, 20, 4);
      ctx.fillStyle = "#C9CBD4";
      for (let i = 0; i < 12; i++) ctx.fillRect(100 + i, 42 - i * 1.4, 2, 1);
      ctx.fillStyle = "#B8863A";
      ctx.fillRect(111, 25, 5, 2);
    },
  );

const MAIN: [number, number][] = [
  [10, 48],
  [18, 44],
  [22, 53],
  [25, 38],
  [32, 40],
  [38, 34],
  [42, 47],
  [45, 30],
  [54, 28],
  [60, 22],
  [64, 35],
  [67, 16],
  [76, 14],
  [86, 8],
];
const MISSED: [number, number][] = [
  [10, 48],
  [18, 44],
  [22, 53],
  [26, 51],
  [32, 50],
  [38, 45],
  [42, 54],
  [46, 52],
  [54, 48],
  [60, 44],
  [64, 52],
  [68, 50],
  [76, 42],
  [86, 30],
];
const WORST = [MAIN[2], MAIN[6], MAIN[10]];
const BEST = [MAIN[3], MAIN[7], MAIN[11]];

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

// ---- props ----
const pop = (f: number, at: number, fps: number) =>
  f < at
    ? 0
    : spring({ frame: f - at, fps, config: { damping: 7, stiffness: 260 } });

// a voxel sphere: 3x3x3 cubes without the corners
const BALL_CELLS: [number, number, number][] = [];
for (let x = -1; x <= 1; x++)
  for (let y = -1; y <= 1; y++)
    for (let z = -1; z <= 1; z++)
      if (Math.abs(x) + Math.abs(y) + Math.abs(z) <= 2)
        BALL_CELLS.push([x, y, z]);

/** glowing crystal ball; shatters into flying blocks from `shatterAt` */
const CrystalBall: React.FC<{
  position: [number, number, number];
  f: number;
  appearAt: number;
  shatterAt?: number;
  size?: number;
}> = ({ position, f, appearAt, shatterAt, size = 0.1 }) => {
  const { fps } = useVideoConfig();
  const s = pop(f, appearAt, fps);
  if (s <= 0) return null;
  const broken = shatterAt !== undefined && f >= shatterAt;
  const t = broken ? (f - shatterAt!) / fps : 0;
  const pulse = 0.8 + 0.2 * Math.sin(f * 0.25);
  const centerY = size * 1.6;
  return (
    <group position={position} scale={s}>
      {/* gold stand */}
      <mesh position={[0, size * 0.25, 0]} castShadow>
        <boxGeometry args={[size * 2.6, size * 0.5, size * 2.6]} />
        <meshLambertMaterial map={noiseTex("#D8B448", 0.12, 8)} />
      </mesh>
      <group rotation={[0, broken ? 0 : f * 0.03, 0]}>
        {BALL_CELLS.map(([x, y, z], i) => {
          let px = x * size;
          let py = centerY + y * size;
          let pz = z * size;
          let rot = 0;
          if (broken) {
            const len = Math.hypot(x, y, z) || 1;
            const speed = 1.6 + ((i * 37) % 10) / 10;
            px += (x / len) * speed * t + ((i % 3) - 1) * 0.3 * t;
            pz += (z / len) * speed * t + 0.6 * t;
            py = Math.max(
              size * 0.5,
              py + (1.4 + (y + 1) * 0.5) * t - 4.9 * t * t,
            );
            rot = t * (6 + (i % 5));
          }
          return (
            <mesh
              key={i}
              position={[px, py, pz]}
              rotation={[rot, rot * 0.7, 0]}
            >
              <boxGeometry args={[size * 0.98, size * 0.98, size * 0.98]} />
              <meshLambertMaterial
                color="#8E5CE8"
                emissive={MYSTIC}
                emissiveIntensity={broken ? 0.3 : 0.55 * pulse}
                transparent
                opacity={0.92}
              />
            </mesh>
          );
        })}
      </group>
      {!broken && (
        <Glow3D
          position={[0, centerY, size * 2]}
          size={size * 14}
          color={MYSTIC}
          opacity={0.55 * pulse}
        />
      )}
      {!broken && (
        <pointLight
          color={MYSTIC}
          intensity={2.5 * pulse}
          position={[0, centerY, size * 3]}
          decay={1.6}
        />
      )}
    </group>
  );
};

const DeskCalendar: React.FC<{ f: number; at: number }> = ({ f, at }) => {
  const { fps } = useVideoConfig();
  const s = pop(f, at, fps);
  if (s <= 0) return null;
  return (
    <group
      position={[DESK.x - 0.4, DESK.h + 0.06, DESK.z - 0.05]}
      rotation={[-0.15, 0.25, 0]}
      scale={s}
    >
      <mesh position={[0, 0.2, -0.03]} castShadow>
        <boxGeometry args={[0.34, 0.42, 0.05]} />
        <meshLambertMaterial color="#5A3A22" />
      </mesh>
      <mesh position={[0, 0.2, 0.0]}>
        <planeGeometry args={[0.3, 0.375]} />
        <meshLambertMaterial map={calendarTex()} />
      </mesh>
    </group>
  );
};

const BALL_SPOT: [number, number, number] = [
  DESK.x + 0.42,
  DESK.h + 0.06,
  DESK.z - 0.15,
];
const BALL_AT = findWord(L2, "soothsayer", FPS);
const CAL_AT = findWord(L2, "Ides", FPS);
const SMASH_AT = findWord(L8, "guessing", FPS) + 2;

const DeskProps: React.FC<{ f: number }> = ({ f }) => (
  <>
    <CrystalBall
      position={BALL_SPOT}
      f={f}
      appearAt={BALL_AT}
      shatterAt={SMASH_AT}
    />
    <DeskCalendar f={f} at={CAL_AT} />
  </>
);

// --------------------------------------------------------------------------
const caesarTalk = (f: number, fps: number): VoxelPose => ({
  ...life(f),
  talk: talkAt(LINES, f, fps),
  brow: 0.7,
  browLift: -0.1,
  mouth: -0.3,
});

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
/** "A soothsayer told me... beware the Ides of March": ball, then calendar */
const IdesShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.ides[0];
  const spooky = interpolate(f, [BALL_AT, BALL_AT + 10], [0, 1], {
    ...CL,
    easing: ease,
  });
  const point = interpolate(f, [CAL_AT - 6, CAL_AT], [0, 1], {
    ...CL,
    easing: ease,
  });
  return (
    <AbsoluteFill>
      <Sfx
        name="shimmer"
        at={BALL_AT - SHOT.ides[0]}
        volume={0.45}
        rate={0.8}
      />
      <Sfx name="drone" at={BALL_AT - SHOT.ides[0] + 4} volume={0.25} />
      <Sfx name="pop" at={CAL_AT - SHOT.ides[0]} volume={0.55} rate={0.8} />
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
            brow: 0.3 - 0.6 * spooky,
            browLift: 0.6 * spooky,
            mouth: -0.2,
            headTilt: 0.08 * spooky,
            armL: [-1.0 * point, 0, 0.35 * point],
            armR: [-0.3, 0, 0],
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const StabbedShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.stabbed[0];
  const stabAt = findWord(L3, "stabbed", fps);
  const hurt = interpolate(f, [stabAt, stabAt + 6], [0, 1], {
    ...CL,
    easing: ease,
  });
  const jolt =
    f >= stabAt
      ? 1 -
        spring({
          frame: f - stabAt,
          fps,
          config: { damping: 6, stiffness: 300 },
        })
      : 0;
  const cam = CLOSE_CAM(
    interpolate(local, [0, 50], [0, 1], { ...CL, easing: ease }),
  );
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="stab" at={stabAt - SHOT.stabbed[0]} volume={0.9} />
      <Canvas3D>
        <CameraRig
          position={[
            cam.position[0] + jolt * 0.05,
            cam.position[1],
            cam.position[2],
          ]}
          target={cam.target}
          fov={48}
        />
        <Classroom board={boardTex()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={0}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            squash: 1 - 0.08 * jolt,
            brow: 0.6 - 1.6 * hurt,
            browLift: 1 * hurt,
            mouth: -0.8 * hurt,
            headTilt: 0.15 * hurt,
            armL: [-1.0 * hurt, 0, 0.75 * hurt],
            armR: [-0.3, 0, 0],
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
      {/* a red flash on the stab */}
      <Sequence
        from={stabAt - SHOT.stabbed[0]}
        durationInFrames={5}
        layout="none"
      >
        <AbsoluteFill style={{ background: "#D4343C", opacity: 0.35 }} />
      </Sequence>
      <Sequence from={stabAt - SHOT.stabbed[0] + 2} layout="none">
        <RepPop text="XXIII" x={760} y={640} size={120} color={CRIMSON} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** the student gazing into his own crystal ball */
const StudentShot: React.FC = () => {
  const local = useCurrentFrame();
  const f = local + SHOT.student[0];
  const crash = findWord(L4, "crash", FPS);
  const sure = interpolate(f, [SHOT.student[0], SHOT.student[0] + 20], [0, 1], {
    ...CL,
    easing: ease,
  });
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="shimmer" at={4} volume={0.35} rate={1.2} />
      <Sfx name="fall" at={crash - SHOT.student[0]} volume={0.4} rate={1.1} />
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
            brow: -0.5 * sure,
            browLift: 0.9 * sure,
            mouth: 0.5 * sure,
            arms: "forward",
            armBlend: 0.8,
            headTilt: 0.25 * sure,
          }}
        />
        <CrystalBall
          position={[STUDENT_SPOT[0] - 0.05, 0.87, STUDENT_SPOT[2] - 0.65]}
          f={f}
          appearAt={SHOT.student[0]}
          size={0.085}
        />
      </Canvas3D>
      <Sequence from={crash - SHOT.student[0]} layout="none">
        <RepPop
          text="CRASH ON TUESDAY?"
          x={540}
          y={560}
          size={72}
          color={MYSTIC}
        />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const IdiotShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.idiot[0];
  const point = interpolate(local, [0, 8], [0, 1], { ...CL, easing: ease });
  const cam = CLOSE_CAM(
    interpolate(local, [0, 60], [0, 1], { ...CL, easing: ease }),
  );
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
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
            brow: 1,
            browLift: -0.3,
            mouth: -0.6,
            lean: 8 * point,
            armR: [-0.3 - 1.25 * point, 0, 0.1 * point],
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const Marker: React.FC<{ at: [number, number]; s: number; color: string }> = ({
  at,
  s,
  color,
}) =>
  s > 0.01 ? (
    <mesh position={boardPos(at[0], at[1], 0.06)} scale={s}>
      <boxGeometry args={[0.15, 0.15, 0.02]} />
      <meshBasicMaterial color={color} toneMapped={false} />
    </mesh>
  ) : null;

const ChartShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s0 = SHOT.chart[0];
  const bestAt = findWord(L6, "best", fps) - s0;
  const worstAt = findWord(L6, "worst", fps) - s0;
  const missAt = findWord(L7, "Miss", fps) - s0;
  const halfAt = findWord(L7, "half", fps) - s0;
  const draw = interpolate(local, [2, worstAt], [0, 1], {
    ...CL,
    easing: ease,
  });
  const missed = interpolate(local, [missAt, halfAt], [0, 1], {
    ...CL,
    easing: ease,
  });
  const greensGone = interpolate(local, [missAt, missAt + 8], [1, 0], CL);
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="chalk" at={2} volume={0.4} />
      <Sfx name="pop" at={bestAt} volume={0.5} rate={1.3} />
      <Sfx name="pop" at={worstAt} volume={0.5} rate={0.7} />
      <Sfx name="fall" at={missAt} volume={0.5} />
      <Sfx name="hit" at={halfAt} volume={0.5} rate={1.2} />
      <Canvas3D>
        <CameraRig
          position={BOARD_CAM.position}
          target={BOARD_CAM.target}
          fov={62}
        />
        <Classroom board={boardTex()} coins={false} />
        <ChalkLine pts={MAIN} p={draw} />
        <ChalkLine pts={MISSED} p={missed} color="#FF8A8A" />
        {BEST.map((p, i) => (
          <Marker
            key={`b${i}`}
            at={p}
            s={pop(local, bestAt + i * 3, fps) * greensGone}
            color={GREEN}
          />
        ))}
        {WORST.map((p, i) => (
          <Marker
            key={`w${i}`}
            at={p}
            s={pop(local, worstAt + i * 3, fps)}
            color={RED}
          />
        ))}
      </Canvas3D>
      <Sequence from={bestAt} durationInFrames={missAt - bestAt} layout="none">
        <RepPop text="BEST DAYS" x={540} y={1250} size={84} color={GREEN} />
      </Sequence>
      <Sequence from={halfAt} layout="none">
        <RepPop text="HALF THE GAINS" x={540} y={1250} size={84} color={RED} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** "Stop guessing." Caesar smashes the crystal ball with the ruler */
const SmashShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.smash[0];
  const smash = SMASH_AT - SHOT.smash[0];
  const raise = interpolate(local, [0, smash - 3], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.quad),
  });
  const down = interpolate(local, [smash - 3, smash], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  const calm = interpolate(local, [smash + 14, smash + 26], [0, 1], {
    ...CL,
    easing: ease,
  });
  const armR: [number, number, number] = [
    (-2.8 * raise + 1.6 * down) * (1 - calm) + -1.35 * calm,
    0,
    0.15 * raise * (1 - down) * (1 - calm) + -0.85 * calm,
  ];
  const armL: [number, number, number] = [-1.35 * calm, 0, 0.85 * calm];
  const impact = spring({
    frame: local - smash,
    fps,
    config: { damping: 7, stiffness: 260 },
  });
  const shake =
    local >= smash && local < smash + 7 ? (1 - (local - smash) / 7) * 0.05 : 0;
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={smash - 4} volume={0.35} rate={1.4} />
      <Sfx name="hit" at={smash} volume={1} />
      <Sfx name="stab" at={smash + 1} volume={0.4} rate={1.4} />
      <Canvas3D>
        <CameraRig
          position={[
            MEDIUM_CAM.position[0] + Math.sin(local * 7.3) * shake,
            MEDIUM_CAM.position[1] + Math.cos(local * 9.1) * shake,
            MEDIUM_CAM.position[2],
          ]}
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
            squash: local >= smash ? interpolate(impact, [0, 1], [0.9, 1]) : 1,
            brow: 1 - 0.7 * calm,
            mouth: -0.3 + 0.7 * calm,
            armR,
            armL,
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
      <Sequence from={smash} durationInFrames={9} layout="none">
        <SpeedLines cx={700} cy={1000} />
      </Sequence>
      <Sequence from={smash} durationInFrames={3} layout="none">
        <Flash strength={0.6} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
export const Lesson05: React.FC = () => (
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
          from={SHOT.ides[0]}
          durationInFrames={len("ides")}
          name="Soothsayer and the Ides"
        >
          <IdesShot />
        </Sequence>
        <Sequence
          from={SHOT.stabbed[0]}
          durationInFrames={len("stabbed")}
          name="Caesar: still got stabbed"
        >
          <StabbedShot />
        </Sequence>
        <Sequence
          from={SHOT.student[0]}
          durationInFrames={len("student")}
          name="Student: crystal ball"
        >
          <StudentShot />
        </Sequence>
        <Sequence
          from={SHOT.idiot[0]}
          durationInFrames={len("idiot")}
          name="Caesar: no date"
        >
          <IdiotShot />
        </Sequence>
        <Sequence
          from={SHOT.chart[0]}
          durationInFrames={len("chart")}
          name="Board: best days"
        >
          <ChartShot />
        </Sequence>
        <Sequence
          from={SHOT.smash[0]}
          durationInFrames={len("smash")}
          name="Caesar smashes the ball"
        >
          <SmashShot />
        </Sequence>
        <Sequence
          from={SHOT.title[0]}
          durationInFrames={len("title")}
          name="Title card"
        >
          <TitleCard
            word="STAY"
            line1="Time in the market wins."
            line2="Lesson V."
            startAt={6}
            letterEvery={6}
            underlineFrames={20}
            line1At={60}
            line2At={100}
            fadeFrames={40}
          />
        </Sequence>

        <Subtitles lines={LINES} />
        <LessonHud numeral="V" hideFrom={SHOT.title[0]} />
      </AbsoluteFill>
    </LookContext.Provider>
  </SafeContext.Provider>
);
