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
import { RepPop, ShadowText } from "../components/Text";
import { TitleCard } from "../components/TitleCard";
import { SAFE_REELS, SafeContext } from "../layout";
import { LookContext } from "../looks";
import { FPS } from "../theme";
import { ChalkLine } from "../three/Chalk";
import {
  BOARD,
  CAESAR_SPOT,
  Classroom,
  STUDENT_SPOT,
} from "../three/Classroom";
import { chalkboardTex } from "../three/textures";
import { Voxel, VoxelPose } from "../three/Voxel";
import { CameraRig } from "../three/World";
import { voice } from "../voice/lesson-02";
import { findWord, placeLines, talkAt } from "../voice/sync";
import { CAESAR_LOOK, CL, Canvas3D, CRIMSON, LessonHud, life } from "./kit";

/**
 * Lesson II: don't panic-sell (the Rubicon).
 * All timing comes from the voice track in src/voice/lesson-02.ts.
 */

const ease = Easing.inOut(Easing.cubic);
const GREEN = "#4CC26A";
const VIOLET = "#9B5CFF";

// ---- timeline from the voice ----
const LINES = placeLines(
  voice,
  [0.45, 0.35, 0.3, 0.15, 0.4, 0.25, 0.4, 0.35],
  FPS,
);
const [, L2, L3, L4, L5, L6, L7, L8] = LINES;
const L7_SPLIT = findWord(L7, "The", FPS) - 6; // cut from the board to the student
const SHOT = {
  wide: [0, L2.from],
  boardDrop: [L2.from, L3.from],
  panic: [L3.from, L4.from],
  idiot: [L4.from, L5.from],
  rubicon: [L5.from, L7.from],
  boardUp: [L7.from, L7_SPLIT],
  calm: [L7_SPLIT, L8.from],
  hold: [L8.from, L8.to + 12],
  title: [L8.to + 12, L8.to + 12 + 180],
} as const;
export const LESSON_02_DURATION = SHOT.title[1];
const len = (k: keyof typeof SHOT) => SHOT[k][1] - SHOT[k][0];

// ---- board: market graph (left) and the Rubicon (right) ----
const boardTex = () =>
  chalkboardTex(
    "lesson-2",
    [
      { text: "LESSON II", x: 4, y: 3 },
      { text: "MARKET", x: 14, y: 14 },
      { text: "RUBICON", x: 86, y: 52 },
    ],
    (ctx) => {
      ctx.fillStyle = "#ECECE4";
      ctx.fillRect(8, 14, 1, 45); // y axis
      ctx.fillRect(8, 58, 78, 1); // x axis
      // the Rubicon: two wavy blue banks
      ctx.fillStyle = "#A9D1F5";
      for (let i = 0; i < 34; i++) {
        const x = 90 + i;
        ctx.fillRect(x, Math.round(22 + i * 0.6 + Math.sin(i * 0.7) * 2), 1, 1);
        ctx.fillRect(
          x,
          Math.round(30 + i * 0.6 + Math.sin(i * 0.7 + 1) * 2),
          1,
          1,
        );
      }
      // little Caesar crossing: a box with a laurel
      ctx.fillStyle = "#ECECE4";
      ctx.fillRect(103, 26, 6, 6);
      ctx.fillStyle = "#D8B448";
      ctx.fillRect(102, 25, 8, 1);
    },
  );

const RISE: [number, number][] = [
  [10, 52],
  [18, 47],
  [26, 44],
  [34, 38],
  [42, 33],
  [50, 26],
];
const DROP: [number, number][] = [
  [50, 26],
  [56, 45],
];
const RECOVER: [number, number][] = [
  [56, 45],
  [62, 40],
  [68, 31],
  [74, 23],
  [80, 16],
  [86, 9],
];
const BOARD_CAM = {
  position: [BOARD.x - 0.55, BOARD.y - 0.45, 1.45] as [number, number, number],
  target: [BOARD.x - 0.55, BOARD.y - 0.45, BOARD.z] as [number, number, number],
};

// ---- shared poses ----
const caesarIdle = (f: number, fps: number): VoxelPose => ({
  ...life(f),
  talk: talkAt(LINES, f, fps),
  brow: 0.7,
  browLift: -0.1,
  mouth: -0.3,
});

const STUDENT_FACING = Math.PI; // facing Caesar (away from the wide camera)
const STUDENT_CAM = {
  position: [STUDENT_SPOT[0] + 0.3, 2.2, -2.0] as [number, number, number],
  target: [STUDENT_SPOT[0] + 0.15, 1.95, STUDENT_SPOT[2]] as [
    number,
    number,
    number,
  ],
};
const SHADOW_SPOT: [number, number, number] = [
  STUDENT_SPOT[0] + 0.7,
  0,
  STUDENT_SPOT[2] + 0.6,
];

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
        <Classroom board={boardTex()} />
        <Voxel
          position={CAESAR_SPOT}
          facing={0.15}
          outfit="caesar"
          ruler
          pose={{
            ...caesarIdle(f, fps),
            squash: f >= SLAM ? interpolate(impact, [0, 1], [0.9, 1]) : 1,
            brow: 0.9,
            armR,
            armOverride: 1,
          }}
        />
        <Voxel
          position={STUDENT_SPOT}
          facing={STUDENT_FACING - 0.35}
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
const BoardDrop: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const drops = findWord(L2, "drops", fps) - SHOT.boardDrop[0];
  const rise = interpolate(local, [2, drops], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.quad),
  });
  const drop = interpolate(local, [drops, drops + 8], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  const shake =
    local >= drops + 8 && local < drops + 14
      ? (1 - (local - drops - 8) / 6) * 0.03
      : 0;
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.3} />
      <Sfx name="chalk" at={2} volume={0.45} />
      <Sfx name="fall" at={drops} volume={0.7} />
      <Sfx name="pop" at={drops + 8} volume={0.6} rate={0.7} />
      <Canvas3D>
        <CameraRig
          position={[
            BOARD_CAM.position[0] + Math.sin(local * 8) * shake,
            BOARD_CAM.position[1],
            BOARD_CAM.position[2],
          ]}
          target={BOARD_CAM.target}
          fov={62}
        />
        <Classroom board={boardTex()} />
        <ChalkLine pts={RISE} p={rise} />
        <ChalkLine pts={DROP} p={drop} color="#FF6B6B" />
      </Canvas3D>
      <Sequence from={drops + 8} layout="none">
        <RepPop text="-10%" x={660} y={1000} size={130} color="#FF4D4D" />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** close on the student, shadow looming; `calm` 0 = panicking, 1 = steady */
const StudentShot: React.FC<{ start: number; calmFrom?: number }> = ({
  start,
  calmFrom,
}) => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + start;
  const calm =
    calmFrom === undefined
      ? 0
      : interpolate(f, [calmFrom, calmFrom + 30], [0, 1], {
          ...CL,
          easing: ease,
        });
  const emerge =
    calmFrom === undefined
      ? interpolate(local, [0, 14], [0, 1], {
          ...CL,
          easing: Easing.out(Easing.back(1.3)),
        })
      : 1 - calm;
  const panic = 1 - calm;
  const tremble = Math.sin(f * 2.3) * 0.015 * panic;
  // shake head "no" on "who sell"
  const noShake =
    calmFrom === undefined
      ? 0
      : Math.sin((f - findWord(L7, "sell", fps)) * 0.6) *
        0.35 *
        interpolate(
          f,
          [findWord(L7, "who", fps) + 4, findWord(L7, "sell", fps) + 20],
          [0, 1],
          CL,
        ) *
        interpolate(
          f,
          [findWord(L7, "sell", fps) + 20, findWord(L7, "sell", fps) + 28],
          [1, 0],
          CL,
        );
  const sweatY = 2.05 - ((local % 24) / 24) * 0.5;

  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      {calmFrom === undefined && <Sfx name="drone" at={0} volume={0.3} />}
      <Canvas3D>
        <CameraRig
          position={STUDENT_CAM.position}
          target={STUDENT_CAM.target}
          fov={50}
        />
        <Classroom board={boardTex()} />
        <Voxel
          position={SHADOW_SPOT}
          facing={Math.PI}
          variant="shadow"
          scale={1.1 + 0.15 * panic}
          emerge={Math.max(0.001, emerge)}
          visible={emerge > 0.02}
          pose={{ ...life(f, 5), lean: 8 * panic, headTilt: 0.2 * panic }}
        />
        {emerge > 0.02 && (
          <pointLight
            color={VIOLET}
            intensity={4 * emerge}
            position={[SHADOW_SPOT[0], 2.4, SHADOW_SPOT[2] - 0.8]}
            decay={1.5}
          />
        )}
        <Voxel
          position={[STUDENT_SPOT[0] + tremble, 0, STUDENT_SPOT[2]]}
          facing={STUDENT_FACING}
          pose={{
            ...life(f, 2),
            sit: 1,
            brow: -1 * panic + 0.6 * calm,
            browLift: 1 * panic,
            mouth: -0.9 * panic + 0.5 * calm,
            arms: "forward",
            armBlend: 0.75,
            headYaw: noShake,
            lean: 6 * calm,
          }}
        />
        {panic > 0.5 && (
          <mesh
            position={[STUDENT_SPOT[0] - 0.4, sweatY, STUDENT_SPOT[2] - 0.35]}
          >
            <boxGeometry args={[0.07, 0.11, 0.07]} />
            <meshBasicMaterial color="#8FD3FF" />
          </mesh>
        )}
      </Canvas3D>
      {calmFrom === undefined && (
        <Sequence from={6} layout="none">
          <ShadowText
            text="SELL! SELL IT ALL!"
            x={70}
            y={440}
            width={520}
            color={VIOLET}
            align="left"
          />
        </Sequence>
      )}
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const CaesarClose: React.FC<{ start: number; mode: "idiot" | "hold" }> = ({
  start,
  mode,
}) => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + start;
  const push = interpolate(local, [0, 40], [0, 1], { ...CL, easing: ease });
  const point = interpolate(local, [0, 6], [0, 1], { ...CL, easing: ease });
  const armR: [number, number, number] =
    mode === "idiot"
      ? [-0.3 - 1.25 * point, 0, 0.1 * point]
      : [-1.35, 0, -0.85];
  const armL: [number, number, number] =
    mode === "idiot" ? [0, 0, 0] : [-1.35, 0, 0.85];
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.3} />
      <Canvas3D>
        <CameraRig
          position={[CAESAR_SPOT[0] + 0.15, 2.05, 2.3 - 0.5 * push]}
          target={[CAESAR_SPOT[0], 1.75, CAESAR_SPOT[2]]}
          fov={48}
        />
        <Classroom board={boardTex()} />
        <Voxel
          position={CAESAR_SPOT}
          facing={0}
          outfit="caesar"
          ruler
          pose={{
            ...caesarIdle(f, fps),
            brow: 1,
            browLift: -0.3,
            mouth: mode === "hold" ? 0.2 : -0.6,
            lean: mode === "idiot" ? 8 * point : 0,
            headTilt: mode === "hold" ? -0.08 : 0.05,
            armR,
            armL,
            armOverride: 1,
          }}
        />
      </Canvas3D>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const RubiconShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.rubicon[0];
  const no = findWord(L6, "No", fps) - SHOT.rubicon[0];
  const rome = findWord(L6, "Rome", fps) - SHOT.rubicon[0];
  const SLAM = no + 3;

  const up = interpolate(local, [4, 14], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.back(1.4)),
  });
  const down = interpolate(local, [no - 1, SLAM], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  const proud = interpolate(local, [rome - 4, rome + 6], [0, 1], {
    ...CL,
    easing: ease,
  });
  const armR: [number, number, number] = [
    -0.3 - 2.6 * up + 1.7 * down * up,
    0,
    0.15 * up * (1 - down),
  ];
  const armL: [number, number, number] = [-2.7 * proud, 0, -0.25 * proud];
  const impact = spring({
    frame: local - SLAM,
    fps,
    config: { damping: 7, stiffness: 260 },
  });
  const shake =
    local >= SLAM && local < SLAM + 7 ? (1 - (local - SLAM) / 7) * 0.05 : 0;

  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.3} />
      <Sfx name="hit" at={SLAM} volume={1} />
      <Sfx name="shimmer" at={rome} volume={0.5} />
      <Canvas3D>
        <CameraRig
          position={[
            0.45 + Math.sin(local * 7.3) * shake,
            2.35 + Math.cos(local * 9.1) * shake,
            3.3,
          ]}
          target={[0.15, 2.15, -1.05]}
          fov={54}
        />
        <Classroom board={boardTex()} />
        <Voxel
          position={CAESAR_SPOT}
          facing={-0.1}
          outfit="caesar"
          ruler
          pose={{
            ...caesarIdle(f, fps),
            squash: local >= SLAM ? interpolate(impact, [0, 1], [0.9, 1]) : 1,
            brow: 0.5 + 0.5 * down - 0.6 * proud,
            browLift: 0.3 * proud,
            mouth: 0.3 + 0.6 * proud,
            headTilt: -0.12 * up,
            armR,
            armL,
            armOverride: 1,
          }}
        />
      </Canvas3D>
      <Sequence from={SLAM} durationInFrames={9} layout="none">
        <SpeedLines cx={540} cy={1000} />
      </Sequence>
      <Sequence from={SLAM} durationInFrames={3} layout="none">
        <Flash strength={0.6} />
      </Sequence>
      <Sequence from={rome} layout="none">
        <RepPop text="ROME: TAKEN" x={540} y={560} size={92} color={CRIMSON} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const BoardUp: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const recover = findWord(L7, "recover", fps) - SHOT.boardUp[0];
  const up = interpolate(local, [recover, recover + 18], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.quad),
  });
  const high = recover + 18;
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.3} />
      <Sfx name="rise" at={recover} volume={0.7} />
      <Sfx name="pop" at={high} volume={0.6} rate={1.2} />
      <Canvas3D>
        <CameraRig
          position={BOARD_CAM.position}
          target={BOARD_CAM.target}
          fov={62}
        />
        <Classroom board={boardTex()} />
        <ChalkLine pts={RISE} p={1} />
        <ChalkLine pts={DROP} p={1} color="#FF6B6B" />
        <ChalkLine pts={RECOVER} p={up} color="#8CF0A2" />
      </Canvas3D>
      <Sequence from={high} layout="none">
        <RepPop text="NEW HIGH!" x={560} y={560} size={110} color={GREEN} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
export const Lesson02: React.FC = () => (
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
          from={SHOT.boardDrop[0]}
          durationInFrames={len("boardDrop")}
          name="Board: -10%"
        >
          <BoardDrop />
        </Sequence>
        <Sequence
          from={SHOT.panic[0]}
          durationInFrames={len("panic")}
          name="Student panics"
        >
          <StudentShot start={SHOT.panic[0]} />
        </Sequence>
        <Sequence
          from={SHOT.idiot[0]}
          durationInFrames={len("idiot")}
          name="Caesar: idiot"
        >
          <CaesarClose start={SHOT.idiot[0]} mode="idiot" />
        </Sequence>
        <Sequence
          from={SHOT.rubicon[0]}
          durationInFrames={len("rubicon")}
          name="Caesar: Rubicon"
        >
          <RubiconShot />
        </Sequence>
        <Sequence
          from={SHOT.boardUp[0]}
          durationInFrames={len("boardUp")}
          name="Board: recovery"
        >
          <BoardUp />
        </Sequence>
        <Sequence
          from={SHOT.calm[0]}
          durationInFrames={len("calm")}
          name="Student holds"
        >
          <StudentShot start={SHOT.calm[0]} calmFrom={SHOT.calm[0]} />
        </Sequence>
        <Sequence
          from={SHOT.hold[0]}
          durationInFrames={len("hold")}
          name="Caesar: hold"
        >
          <CaesarClose start={SHOT.hold[0]} mode="hold" />
        </Sequence>
        <Sequence
          from={SHOT.title[0]}
          durationInFrames={len("title")}
          name="Title card"
        >
          <TitleCard
            word="HOLD"
            line1="Never panic-sell."
            line2="Lesson II."
            startAt={6}
            letterEvery={6}
            underlineFrames={20}
            line1At={70}
            line2At={100}
            fadeFrames={40}
          />
        </Sequence>

        <Subtitles lines={LINES} />
        <LessonHud numeral="II" hideFrom={SHOT.title[0]} />
      </AbsoluteFill>
    </LookContext.Provider>
  </SafeContext.Provider>
);
