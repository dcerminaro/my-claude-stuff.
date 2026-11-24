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
import { chalkboardTex, noiseTex } from "../three/textures";
import { Voxel, VoxelPose } from "../three/Voxel";
import { CameraRig } from "../three/World";
import { voice } from "../voice/lesson-08";
import { findWord, placeLines, talkAt } from "../voice/sync";
import { CAESAR_LOOK, CL, Canvas3D, LessonHud, life } from "./kit";

/**
 * Lesson VIII: keep fees low (the publicani).
 * History: Rome's tax farmers (publicani) kept a cut of what they
 * collected; in 47 BC Caesar removed them from collecting the direct tax
 * in the province of Asia and cut that tax by a third.
 * Maths: at 7% a year for 30 years, a 1% annual fee leaves you with
 * about 25% less (x5.74 instead of x7.61).
 * Most actively managed funds trail their index over long periods
 * (S&P's SPIVA reports), hence "probably can't beat the market".
 * All timing comes from the voice track in src/voice/lesson-08.ts.
 */

const ease = Easing.inOut(Easing.cubic);
const GREEN = "#4CC26A";
const RED = "#FF4D4D";
const GOLD = "#E8C04A";

// ---- timeline from the voice ----
const LINES = placeLines(
  voice,
  [0.45, 0.35, 0.25, 0.35, 0.3, 0.3, 0.35, 0.4],
  FPS,
);
const [, L2, L3, L4, L5, L6, L7, L8] = LINES;
const SHOT = {
  wide: [0, L2.from],
  skim: [L2.from, L3.from],
  asia: [L3.from, L4.from],
  student: [L4.from, L5.from],
  tiny: [L5.from, L6.from],
  graph: [L6.from, L7.from],
  idiot: [L7.from, L8.from],
  gold: [L8.from, L8.to + 16],
  title: [L8.to + 16, L8.to + 16 + 180],
} as const;
export const LESSON_08_DURATION = SHOT.title[1];
const len = (k: keyof typeof SHOT) => SHOT[k][1] - SHOT[k][0];

// ---- boards ----
const taxBoard = () =>
  chalkboardTex(
    "lesson-8-tax",
    [
      { text: "LESSON VIII", x: 4, y: 3 },
      { text: "TAX", x: 16, y: 52 },
      { text: "ASIA", x: 56, y: 14 },
    ],
    (ctx) => {
      ctx.fillStyle = "#ECECE4";
      ctx.fillRect(8, 49, 40, 1);
      // a chalk tax collector's money bag in "Asia"
      for (let y = 0; y < 14; y++) {
        const w = Math.round(6 + Math.sin((y / 13) * Math.PI) * 5);
        ctx.fillRect(66 - w, 26 + y, 1, 1);
        ctx.fillRect(66 + w, 26 + y, 1, 1);
      }
      ctx.fillRect(60, 39, 13, 1);
      ctx.fillRect(63, 24, 7, 1);
    },
  );
const graphBoard = () =>
  chalkboardTex(
    "lesson-8-graph",
    [
      { text: "LESSON VIII", x: 4, y: 3 },
      { text: "30 YEARS", x: 50, y: 52 },
    ],
    (ctx) => {
      ctx.fillStyle = "#ECECE4";
      ctx.fillRect(8, 12, 1, 39);
      ctx.fillRect(8, 50, 80, 1);
    },
  );

const curve = (rate: number): [number, number][] =>
  Array.from({ length: 16 }, (_, i) => {
    const t = (i / 15) * 30;
    const v = Math.pow(1 + rate, t);
    return [
      10 + (i / 15) * 76,
      49 - 36 * ((v - 1) / (Math.pow(1.07, 30) - 1)),
    ] as [number, number];
  });
const NO_FEE = curve(0.07);
const WITH_FEE = curve(0.06);

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

// ---- the skim: coins hop from a stack into a fee bag ----
const COIN = [0.1, 0.035, 0.1] as const;

/**
 * `hops[i]` = frame when coin i leaves the stack (top coin first).
 * `giveBack` = frame from which skimmed coins fly back to the stack.
 */
const Skim: React.FC<{
  f: number;
  stack: [number, number, number];
  bag: [number, number, number];
  total: number;
  hops: number[];
  showAt: number;
  giveBack?: number;
}> = ({ f, stack, bag, total, hops, showAt, giveBack }) => {
  const { fps } = useVideoConfig();
  const s = pop(f, showAt, fps);
  if (s <= 0) return null;
  const back = giveBack !== undefined && f >= giveBack;
  const bagSquash = hops.reduce(
    (acc, at) => (f >= at + 10 && f < at + 16 ? 0.85 : acc),
    1,
  );
  const coinTex = noiseTex(GOLD, 0.14, 8);
  return (
    <group scale={s}>
      {/* the stack */}
      {Array.from({ length: total }, (_, k) => {
        const idx = total - 1 - k; // top coin leaves first
        const hop = hops[idx];
        const home: [number, number, number] = [
          stack[0],
          stack[1] + 0.02 + k * 0.038,
          stack[2],
        ];
        let pos = home;
        if (hop !== undefined && f >= hop) {
          const t = Math.min(1, (f - hop) / 10);
          const inBag = t >= 1;
          let u = t;
          if (back) u = Math.max(0, 1 - (f - giveBack!) / 10);
          if (inBag && !back) return null;
          const p: [number, number, number] = [
            home[0] + (bag[0] - home[0]) * u,
            home[1] +
              (bag[1] + 0.25 - home[1]) * u +
              Math.sin(u * Math.PI) * 0.3,
            home[2] + (bag[2] - home[2]) * u,
          ];
          pos = p;
        }
        return (
          <mesh
            key={k}
            position={pos}
            rotation={[
              0,
              0,
              hop !== undefined && f >= hop && !back ? (f - hop) * 0.5 : 0,
            ]}
            castShadow
          >
            <boxGeometry args={[...COIN]} />
            <meshLambertMaterial map={coinTex} />
          </mesh>
        );
      })}
      {/* the fee bag */}
      {!(giveBack !== undefined && f >= giveBack + 12) && (
        <group
          position={bag}
          scale={[
            1 / Math.sqrt(bagSquash),
            bagSquash,
            1 / Math.sqrt(bagSquash),
          ]}
        >
          <mesh position={[0, 0.13, 0]} castShadow>
            <boxGeometry args={[0.26, 0.26, 0.22]} />
            <meshLambertMaterial map={noiseTex("#6E6E78", 0.14, 8)} />
          </mesh>
          <mesh position={[0, 0.29, 0]}>
            <boxGeometry args={[0.12, 0.06, 0.1]} />
            <meshLambertMaterial map={noiseTex("#55555E", 0.14, 8)} />
          </mesh>
        </group>
      )}
    </group>
  );
};

const CAESAR_STACK: [number, number, number] = [
  DESK.x - 0.45,
  DESK.h + 0.06,
  DESK.z + 0.05,
];
const CAESAR_BAG: [number, number, number] = [
  DESK.x + 0.45,
  DESK.h + 0.06,
  DESK.z - 0.1,
];
const SKIM_START = findWord(L2, "skimmed", FPS);
const CAESAR_HOPS = Array.from({ length: 4 }, (_, i) => SKIM_START + i * 9);
const GIVE_BACK = findWord(L8, "Keep", FPS);

const DeskSkim: React.FC<{ f: number }> = ({ f }) => (
  <Skim
    f={f}
    stack={CAESAR_STACK}
    bag={CAESAR_BAG}
    total={8}
    hops={CAESAR_HOPS}
    showAt={L2.from + 4}
    giveBack={GIVE_BACK}
  />
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
        <Classroom board={taxBoard()} coins={false} />
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
const SkimShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.skim[0];
  const publicaniAt = findWord(L2, "publicani", fps);
  const annoyed = interpolate(f, [SKIM_START, SKIM_START + 12], [0, 1], {
    ...CL,
    easing: ease,
  });
  return (
    <AbsoluteFill>
      {CAESAR_HOPS.map((at, i) => (
        <Sfx
          key={i}
          name="pop"
          at={at - SHOT.skim[0]}
          volume={0.35}
          rate={1.3 + i * 0.05}
        />
      ))}
      <Canvas3D>
        <CameraRig
          position={MEDIUM_CAM.position}
          target={MEDIUM_CAM.target}
          fov={54}
        />
        <Classroom board={taxBoard()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={-0.05}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            brow: 0.3 + 0.7 * annoyed,
            mouth: -0.2 - 0.5 * annoyed,
            headYaw: -0.35 * annoyed,
            armOverride: 1,
            armR: [-0.3, 0, 0],
          }}
        />
        <DeskSkim f={f} />
      </Canvas3D>
      <Sequence
        from={publicaniAt - SHOT.skim[0]}
        durationInFrames={SKIM_START - publicaniAt}
        layout="none"
      >
        <RepPop text="PUBLICANI" x={540} y={1250} size={96} color={RED} />
      </Sequence>
      <Sequence from={SKIM_START - SHOT.skim[0]} layout="none">
        <RepPop text="SKIM!" x={540} y={1250} size={110} color={RED} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const Bar: React.FC<{ x: number; h: number; color: string }> = ({
  x,
  h,
  color,
}) => {
  if (h <= 0.1) return null;
  const k = BOARD.w / 128;
  const base = boardPos(x, 48.5, 0.06);
  return (
    <mesh position={[base[0], base[1] + (h * k) / 2, base[2]]}>
      <boxGeometry args={[12 * k, h * k, 0.02]} />
      <meshBasicMaterial color={color} toneMapped={false} />
    </mesh>
  );
};

/** kicked the publicani out of Asia; the tax bar drops by a third */
const AsiaShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s0 = SHOT.asia[0];
  const kickAt = findWord(L3, "kicked", fps) - s0;
  const thirdAt = findWord(L3, "third", fps) - s0;
  const x = interpolate(local, [kickAt, kickAt + 8], [0, 1], {
    ...CL,
    easing: ease,
  });
  const tax = interpolate(local, [thirdAt - 4, thirdAt + 6], [30, 20], {
    ...CL,
    easing: Easing.out(Easing.back(1.4)),
  });
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.2} />
      <Sfx name="hit" at={kickAt} volume={0.5} rate={1.2} />
      <Sfx name="chalk" at={kickAt + 2} volume={0.35} />
      <Sfx name="fall" at={thirdAt - 4} volume={0.4} rate={1.3} />
      <Canvas3D>
        <CameraRig
          position={BOARD_CAM.position}
          target={BOARD_CAM.target}
          fov={62}
        />
        <Classroom board={taxBoard()} coins={false} />
        <Bar x={22} h={tax} color="#F2F2EA" />
        {/* red X over the tax collector's bag */}
        <ChalkLine
          pts={[
            [56, 22],
            [76, 42],
          ]}
          p={Math.min(1, x * 2)}
          color="#FF6B6B"
          width={0.09}
        />
        <ChalkLine
          pts={[
            [76, 22],
            [56, 42],
          ]}
          p={Math.max(0, x * 2 - 1)}
          color="#FF6B6B"
          width={0.09}
        />
      </Canvas3D>
      <Sequence
        from={kickAt + 4}
        durationInFrames={thirdAt - kickAt - 4}
        layout="none"
      >
        <RepPop
          text="PUBLICANI: OUT"
          x={540}
          y={1250}
          size={84}
          color={GREEN}
        />
      </Sequence>
      <Sequence from={thirdAt + 4} layout="none">
        <RepPop text="TAX -1/3" x={540} y={1250} size={110} color={GREEN} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const STUDENT_STACK: [number, number, number] = [
  STUDENT_SPOT[0] + 0.0,
  0.87,
  STUDENT_SPOT[2] - 0.62,
];
const STUDENT_BAG: [number, number, number] = [
  STUDENT_SPOT[0] + 0.42,
  0.87,
  STUDENT_SPOT[2] - 0.62,
];

const StudentShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.student[0];
  const managersAt = findWord(L4, "managers", fps);
  const feesAt = findWord(L4, "fees", fps);
  const hops = Array.from({ length: 4 }, (_, i) => managersAt + 6 + i * 10);
  const dismay = interpolate(f, [hops[0], hops[0] + 20], [0, 1], {
    ...CL,
    easing: ease,
  });
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      {hops.map((at, i) => (
        <Sfx
          key={i}
          name="pop"
          at={at - SHOT.student[0]}
          volume={0.35}
          rate={1.2 + i * 0.05}
        />
      ))}
      <Canvas3D>
        <CameraRig
          position={STUDENT_CAM.position}
          target={STUDENT_CAM.target}
          fov={50}
        />
        <Classroom board={taxBoard()} coins={false} />
        <Voxel
          position={STUDENT_SPOT}
          facing={Math.PI}
          pose={{
            ...life(f, 2),
            sit: 1,
            brow: 0.2 - 1.1 * dismay,
            browLift: 0.8 * dismay,
            mouth: 0.3 - 1.1 * dismay,
            arms: "forward",
            armBlend: 0.8,
            headTilt: 0.2,
            headYaw: -0.3 * dismay,
          }}
        />
        <Skim
          f={f}
          stack={STUDENT_STACK}
          bag={STUDENT_BAG}
          total={7}
          hops={hops}
          showAt={SHOT.student[0]}
        />
      </Canvas3D>
      <Sequence from={feesAt - SHOT.student[0]} layout="none">
        <RepPop text="FEES" x={540} y={560} size={130} color={RED} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** "One percent sounds tiny, right?" */
const TinyShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.tiny[0];
  const rightAt = findWord(L5, "right", fps);
  const smirk = interpolate(f, [rightAt - 4, rightAt + 4], [0, 1], {
    ...CL,
    easing: ease,
  });
  const cam = CLOSE_CAM(
    interpolate(local, [0, 60], [0, 1], { ...CL, easing: ease }),
  );
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="pop" at={4} volume={0.4} rate={1.6} />
      <Canvas3D>
        <CameraRig position={cam.position} target={cam.target} fov={48} />
        <Classroom board={graphBoard()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={0}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            brow: 0.3 - 0.6 * smirk,
            browLift: 0.8 * smirk,
            mouth: 0.6 * smirk,
            headTilt: -0.08 * smirk,
            armOverride: 1,
            armR: [-0.3, 0, 0],
          }}
        />
        <DeskSkim f={f} />
      </Canvas3D>
      <Sequence from={4} layout="none">
        <RepPop text="1%" x={540} y={420} size={60} color={GOLD} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const GraphShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s0 = SHOT.graph[0];
  const yearsAt = findWord(L6, "years", fps) - s0;
  const quarterAt = findWord(L6, "quarter", fps) - s0;
  const grow = interpolate(local, [2, quarterAt], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.2} />
      <Sfx name="chalk" at={yearsAt} volume={0.4} />
      <Sfx name="fall" at={quarterAt} volume={0.5} />
      <Canvas3D>
        <CameraRig
          position={BOARD_CAM.position}
          target={BOARD_CAM.target}
          fov={62}
        />
        <Classroom board={graphBoard()} coins={false} />
        <ChalkLine pts={NO_FEE} p={grow} color="#8CF0A2" />
        <ChalkLine pts={WITH_FEE} p={grow} color="#FF8A8A" />
      </Canvas3D>
      <Sequence
        from={yearsAt}
        durationInFrames={quarterAt - yearsAt}
        layout="none"
      >
        <RepPop text="NO FEE vs 1% FEE" x={540} y={1250} size={74} />
      </Sequence>
      <Sequence from={quarterAt} layout="none">
        <RepPop
          text="-25% OF YOUR MONEY"
          x={540}
          y={1250}
          size={74}
          color={RED}
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
  const beatAt = findWord(L7, "beat", fps);
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
      <Sfx name="pop" at={beatAt - SHOT.idiot[0]} volume={0.45} rate={0.7} />
      <Canvas3D>
        <CameraRig position={cam.position} target={cam.target} fov={48} />
        <Classroom board={graphBoard()} coins={false} />
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
        <DeskSkim f={f} />
      </Canvas3D>
      <Sequence from={beatAt - SHOT.idiot[0]} layout="none">
        <RepPop
          text="MOST LOSE TO THE MARKET"
          x={540}
          y={420}
          size={56}
          color={RED}
        />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** "Choose low fees. Keep your gold." The coins fly home, the bag vanishes */
const GoldShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.gold[0];
  const swipe = interpolate(f, [GIVE_BACK - 8, GIVE_BACK], [0, 1], {
    ...CL,
    easing: ease,
  });
  const proud = interpolate(f, [GIVE_BACK + 4, GIVE_BACK + 14], [0, 1], {
    ...CL,
    easing: ease,
  });
  return (
    <AbsoluteFill>
      <Sfx
        name="whoosh"
        at={GIVE_BACK - SHOT.gold[0] - 6}
        volume={0.3}
        rate={1.3}
      />
      <Sfx name="shimmer" at={GIVE_BACK - SHOT.gold[0] + 6} volume={0.55} />
      <Canvas3D>
        <CameraRig
          position={MEDIUM_CAM.position}
          target={MEDIUM_CAM.target}
          fov={54}
        />
        <Classroom board={graphBoard()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={-0.05}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            brow: 0.5 - 0.4 * proud,
            mouth: 0.1 + 0.8 * proud,
            armR: [
              -0.3 - 1.0 * swipe * (1 - proud),
              0,
              -0.6 * swipe * (1 - proud),
            ],
            armL: [-1.35 * proud, 0, 0.85 * proud],
            armOverride: 1,
          }}
        />
        <DeskSkim f={f} />
      </Canvas3D>
      <Sequence from={GIVE_BACK - SHOT.gold[0] + 6} layout="none">
        <RepPop text="GOLD: KEPT" x={540} y={1250} size={100} color={GOLD} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
export const Lesson08: React.FC = () => (
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
          from={SHOT.skim[0]}
          durationInFrames={len("skim")}
          name="Publicani skim"
        >
          <SkimShot />
        </Sequence>
        <Sequence
          from={SHOT.asia[0]}
          durationInFrames={len("asia")}
          name="Board: Asia"
        >
          <AsiaShot />
        </Sequence>
        <Sequence
          from={SHOT.student[0]}
          durationInFrames={len("student")}
          name="Student: fees"
        >
          <StudentShot />
        </Sequence>
        <Sequence
          from={SHOT.tiny[0]}
          durationInFrames={len("tiny")}
          name="Caesar: tiny?"
        >
          <TinyShot />
        </Sequence>
        <Sequence
          from={SHOT.graph[0]}
          durationInFrames={len("graph")}
          name="Board: fee drag"
        >
          <GraphShot />
        </Sequence>
        <Sequence
          from={SHOT.idiot[0]}
          durationInFrames={len("idiot")}
          name="Caesar: idiot"
        >
          <IdiotShot />
        </Sequence>
        <Sequence
          from={SHOT.gold[0]}
          durationInFrames={len("gold")}
          name="Caesar: keep your gold"
        >
          <GoldShot />
        </Sequence>
        <Sequence
          from={SHOT.title[0]}
          durationInFrames={len("title")}
          name="Title card"
        >
          <TitleCard
            word="FEES"
            line1="Choose low fees."
            line2="Lesson VIII."
            startAt={6}
            letterEvery={6}
            underlineFrames={20}
            line1At={60}
            line2At={100}
            fadeFrames={40}
          />
        </Sequence>

        <Subtitles lines={LINES} />
        <LessonHud numeral="VIII" hideFrom={SHOT.title[0]} />
      </AbsoluteFill>
    </LookContext.Provider>
  </SafeContext.Provider>
);
