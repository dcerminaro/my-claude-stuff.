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
import { ChalkLine } from "../three/Chalk";
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
import { voice } from "../voice/lesson-03";
import { findWord, placeLines, talkAt, wordFrame } from "../voice/sync";
import { CAESAR_LOOK, CL, Canvas3D, LessonHud, life } from "./kit";

/**
 * Lesson III: compound interest ("Rome wasn't built in a day").
 * Maths: $100/month for 40 years = $48,000 paid in; at 8% a year that
 * grows to about $311k (annual) to $349k (monthly compounding).
 * All timing comes from the voice track in src/voice/lesson-03.ts.
 */

const ease = Easing.inOut(Easing.cubic);
const GREEN = "#4CC26A";
const GOLD = "#E8C04A";

// ---- timeline from the voice ----
const LINES = placeLines(
  voice,
  [0.45, 0.35, 0.3, 0.25, 0.4, 0.25, 0.4, 0.15, 0.35],
  FPS,
);
const [, L2, L3, L4, L5, L6, L7, L8, L9] = LINES;
const SHOT = {
  wide: [0, L2.from],
  temple: [L2.from, L3.from],
  coins: [L3.from, L5.from],
  graph: [L5.from, L7.from],
  friday: [L7.from, L8.from],
  idiots: [L8.from, L9.from],
  patient: [L9.from, L9.to + 14],
  title: [L9.to + 14, L9.to + 14 + 180],
} as const;
export const LESSON_03_DURATION = SHOT.title[1];
const len = (k: keyof typeof SHOT) => SHOT[k][1] - SHOT[k][0];

// ---- board: growth graph (left) and a chalk temple (right) ----
const boardTex = () =>
  chalkboardTex(
    "lesson-3",
    [
      { text: "LESSON III", x: 4, y: 3 },
      { text: "ROME", x: 98, y: 52 },
    ],
    (ctx) => {
      ctx.fillStyle = "#ECECE4";
      ctx.fillRect(8, 12, 1, 47);
      ctx.fillRect(8, 58, 80, 1);
      // chalk temple
      ctx.fillRect(94, 46, 30, 1);
      ctx.fillRect(96, 44, 26, 1);
      for (const x of [98, 104, 110, 116, 120]) ctx.fillRect(x, 30, 1, 14);
      ctx.fillRect(96, 29, 26, 1);
      for (let i = 0; i < 9; i++) {
        ctx.fillRect(96 + i * 1.5, 28 - i, 1, 1);
        ctx.fillRect(121 - i * 1.5, 28 - i, 1, 1);
      }
    },
  );

const PUT_IN: [number, number][] = [
  [10, 56],
  [86, 49],
];
const GROWTH: [number, number][] = Array.from({ length: 20 }, (_, i) => {
  const u = i / 19;
  return [
    10 + u * 76,
    56 - 47 * ((Math.exp(3 * u) - 1) / (Math.exp(3) - 1)),
  ] as [number, number];
});
const BOARD_CAM = {
  position: [BOARD.x - 0.55, BOARD.y - 0.45, 1.45] as [number, number, number],
  target: [BOARD.x - 0.55, BOARD.y - 0.45, BOARD.z] as [number, number, number],
};
const DESK_CAM = {
  position: [0.25, 2.45, 2.75] as [number, number, number],
  target: [0.15, 1.3, -0.15] as [number, number, number],
};

// ---- desk props: a temple that builds itself, and doubling coins ----
const TEMPLE = { x: DESK.x - 0.3, y: DESK.h + 0.06, z: DESK.z - 0.12 };
const MARBLE = "#ECE8E0";
const TEMPLE_PIECES: {
  size: [number, number, number];
  pos: [number, number, number];
}[] = [
  { size: [0.56, 0.05, 0.36], pos: [0, 0.025, 0] },
  { size: [0.5, 0.04, 0.3], pos: [0, 0.07, 0] },
  { size: [0.06, 0.3, 0.06], pos: [-0.19, 0.24, 0.08] },
  { size: [0.06, 0.3, 0.06], pos: [-0.065, 0.24, 0.08] },
  { size: [0.06, 0.3, 0.06], pos: [0.065, 0.24, 0.08] },
  { size: [0.06, 0.3, 0.06], pos: [0.19, 0.24, 0.08] },
  { size: [0.52, 0.05, 0.3], pos: [0, 0.415, 0] },
  { size: [0.44, 0.05, 0.28], pos: [0, 0.465, 0] },
  { size: [0.3, 0.05, 0.26], pos: [0, 0.515, 0] },
  { size: [0.14, 0.05, 0.24], pos: [0, 0.565, 0] },
];

/** `built[i]` = local frame at which piece i lands (Infinity = not yet) */
const Temple: React.FC<{ f: number; landAt: number[] }> = ({ f, landAt }) => {
  const { fps } = useVideoConfig();
  return (
    <group position={[TEMPLE.x, TEMPLE.y, TEMPLE.z]}>
      {TEMPLE_PIECES.map((p, i) => {
        const at = landAt[i];
        if (f < at - 6) return null;
        const drop = interpolate(f, [at - 6, at], [0.35, 0], {
          ...CL,
          easing: Easing.in(Easing.quad),
        });
        const s =
          f >= at
            ? spring({
                frame: f - at,
                fps,
                config: { damping: 8, stiffness: 300 },
              })
            : 1;
        const squash = f >= at ? interpolate(s, [0, 1], [0.7, 1]) : 1;
        return (
          <mesh
            key={i}
            position={[p.pos[0], p.pos[1] + drop, p.pos[2]]}
            scale={[1 / Math.sqrt(squash), squash, 1 / Math.sqrt(squash)]}
            castShadow
            receiveShadow
          >
            <boxGeometry args={p.size} />
            <meshLambertMaterial map={noiseTex(MARBLE, 0.06, 8)} />
          </mesh>
        );
      })}
    </group>
  );
};

const COIN_STACK = 6;
/** coins on the desk; `count(f)` coins are shown, each popping in */
const Coins: React.FC<{ f: number; appearAt: number[] }> = ({
  f,
  appearAt,
}) => {
  const { fps } = useVideoConfig();
  return (
    <group position={[DESK.x + 0.18, DESK.h + 0.06, DESK.z + 0.05]}>
      {appearAt.map((at, i) => {
        if (f < at) return null;
        const s = spring({
          frame: f - at,
          fps,
          config: { damping: 7, stiffness: 320 },
        });
        const col = Math.floor(i / COIN_STACK);
        const row = i % COIN_STACK;
        return (
          <mesh
            key={i}
            position={[col * 0.12, 0.0175 + row * 0.037, (col % 2) * 0.03]}
            scale={[s, s, s]}
            castShadow
          >
            <boxGeometry args={[0.1, 0.035, 0.1]} />
            <meshLambertMaterial map={noiseTex(GOLD, 0.14, 8)} />
          </mesh>
        );
      })}
    </group>
  );
};

// absolute frames when temple pieces land: spread across line 2
const TEMPLE_LAND = (() => {
  const a = findWord(L2, "built", FPS);
  const b = findWord(L2, "centuries", FPS) + 8;
  return TEMPLE_PIECES.map((_, i) =>
    Math.round(a + ((b - a) * i) / (TEMPLE_PIECES.length - 1)),
  );
})();

// coin doublings: 1 on "compound", then x2 on words of line 4
const DOUBLINGS = [
  findWord(L3, "compound", FPS),
  wordFrame(L4, 2, FPS), // makes
  wordFrame(L4, 3, FPS), // money.
  wordFrame(L4, 5, FPS), // that
  wordFrame(L4, 7, FPS), // makes
  wordFrame(L4, 8, FPS), // money.
];
const COIN_APPEAR: number[] = (() => {
  const out: number[] = [];
  DOUBLINGS.forEach((at, k) => {
    const before = k === 0 ? 0 : 2 ** (k - 1);
    const after = 2 ** k;
    for (let i = before; i < after; i++)
      out.push(
        at + Math.round(((i - before) / Math.max(1, after - before)) * 6),
      );
  });
  return out;
})();

// --------------------------------------------------------------------------
const caesarTalk = (f: number, fps: number): VoxelPose => ({
  ...life(f),
  talk: talkAt(LINES, f, fps),
  brow: 0.7,
  browLift: -0.1,
  mouth: -0.3,
});

const DeskProps: React.FC<{ f: number }> = ({ f }) => (
  <>
    <Temple f={f} landAt={TEMPLE_LAND} />
    <Coins f={f} appearAt={COIN_APPEAR} />
  </>
);

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
/** close on the desk: the temple builds, then the coins double */
const DeskShot: React.FC<{ start: number; phase: "temple" | "coins" }> = ({
  start,
  phase,
}) => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + start;
  const push = interpolate(local, [0, 90], [0, 1], { ...CL, easing: ease });
  const landings = phase === "temple" ? TEMPLE_LAND : DOUBLINGS;
  // Caesar gestures at the desk: palm-down arm over it
  const gesture = interpolate(local, [0, 10], [0, 1], { ...CL, easing: ease });
  return (
    <AbsoluteFill>
      {phase === "coins" && <Sfx name="whoosh" at={0} volume={0.3} />}
      {phase === "temple"
        ? TEMPLE_LAND.map((at, i) => (
            <Sfx
              key={i}
              name="step"
              at={at - start}
              volume={0.45}
              rate={0.8 + i * 0.05}
            />
          ))
        : DOUBLINGS.map((at, i) => (
            <Sfx
              key={i}
              name="pop"
              at={at - start}
              volume={0.55}
              rate={0.9 + i * 0.12}
            />
          ))}
      {phase === "coins" && (
        <Sfx
          name="shimmer"
          at={DOUBLINGS[DOUBLINGS.length - 1] - start + 4}
          volume={0.5}
        />
      )}
      <Canvas3D>
        <CameraRig
          position={[
            DESK_CAM.position[0],
            DESK_CAM.position[1],
            DESK_CAM.position[2] - 0.2 * push,
          ]}
          target={DESK_CAM.target}
          fov={52}
        />
        <Classroom board={boardTex()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={0}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            brow: phase === "temple" ? 0.3 : 0.6,
            mouth: 0.1,
            headTilt: 0.15,
            armL: [-1.1 * gesture, 0, 0.25 * gesture],
            armR: [-0.25, 0, 0],
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
      {phase === "coins" &&
        DOUBLINGS.slice(1).map((at, i) => (
          <Sequence
            key={i}
            from={at - start}
            durationInFrames={20}
            layout="none"
          >
            <RepPop
              text="x2"
              x={800}
              y={880 - i * 36}
              size={110}
              color={GOLD}
            />
          </Sequence>
        ))}
      {phase === "temple" && (
        <Sequence from={landings[landings.length - 1] - start} layout="none">
          <RepPop text="ROME: BUILT" x={330} y={1250} size={90} color={GOLD} />
        </Sequence>
      )}
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const GraphShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = SHOT.graph[0];
  const putStart = findWord(L5, "hundred", fps) - s;
  const putEnd = findWord(L5, "thousand", fps) - s;
  const growStart = findWord(L6, "grows", fps) - s;
  const growEnd = findWord(L6, "thousand", fps) - s + 6;
  const put = interpolate(local, [putStart, putEnd], [0, 1], {
    ...CL,
    easing: ease,
  });
  const grow = interpolate(local, [growStart, growEnd], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.3} />
      <Sfx name="chalk" at={putStart} volume={0.45} />
      <Sfx name="rise" at={growStart} volume={0.6} />
      <Sfx name="pop" at={putEnd + 4} volume={0.5} />
      <Sfx name="shimmer" at={growEnd} volume={0.6} />
      <Canvas3D>
        <CameraRig
          position={BOARD_CAM.position}
          target={BOARD_CAM.target}
          fov={62}
        />
        <Classroom board={boardTex()} coins={false} />
        <ChalkLine pts={PUT_IN} p={put} />
        <ChalkLine pts={GROWTH} p={grow} color="#8CF0A2" />
      </Canvas3D>
      <Sequence from={putEnd + 4} layout="none">
        <RepPop text="$48,000 in" x={560} y={1250} size={84} />
      </Sequence>
      <Sequence from={growEnd} layout="none">
        <RepPop text="$300,000+" x={540} y={560} size={120} color={GREEN} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const STUDENT_CAM = {
  position: [STUDENT_SPOT[0] + 0.3, 2.2, -2.0] as [number, number, number],
  target: [STUDENT_SPOT[0] + 0.15, 1.95, STUDENT_SPOT[2]] as [
    number,
    number,
    number,
  ],
};

/** the student caught dreaming of getting rich quick */
const FridayShot: React.FC = () => {
  const local = useCurrentFrame();
  const f = local + SHOT.friday[0];
  const caught = interpolate(
    f,
    [findWord(L7, "Friday", FPS) - 4, findWord(L7, "Friday", FPS) + 4],
    [0, 1],
    { ...CL, easing: ease },
  );
  const dream = 1 - caught;
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.3} />
      <Sfx
        name="pop"
        at={findWord(L7, "Friday", FPS) - SHOT.friday[0]}
        volume={0.5}
        rate={0.7}
      />
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
            brow: -0.3 * dream - 0.9 * caught,
            browLift: 0.3 * dream + 1 * caught,
            mouth: 0.9 * dream - 0.6 * caught,
            arms: "forward",
            armBlend: 0.75,
            headYaw: -0.5 * caught,
            headTilt: -0.15 * dream,
          }}
        />
        {/* daydream coins floating above his head */}
        {dream > 0.05 &&
          [0, 1, 2].map((i) => (
            <mesh
              key={i}
              position={[
                STUDENT_SPOT[0] - 0.3 + i * 0.3,
                2.55 + Math.sin(f * 0.15 + i) * 0.06,
                STUDENT_SPOT[2] - 0.2,
              ]}
              rotation={[0.3, f * 0.08 + i, 0]}
              scale={dream}
            >
              <boxGeometry args={[0.16, 0.16, 0.05]} />
              <meshLambertMaterial map={noiseTex(GOLD, 0.14, 8)} />
            </mesh>
          ))}
      </Canvas3D>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const CaesarClose: React.FC<{ start: number; mode: "idiots" | "patient" }> = ({
  start,
  mode,
}) => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + start;
  const push = interpolate(local, [0, 40], [0, 1], { ...CL, easing: ease });
  const point = interpolate(local, [0, 6], [0, 1], { ...CL, easing: ease });
  const idiots = mode === "idiots";
  const cam: [number, number, number] = idiots
    ? [CAESAR_SPOT[0] + 0.15, 2.05, 2.3 - 0.5 * push]
    : [0.45, 2.3, 3.4];
  const target: [number, number, number] = idiots
    ? [CAESAR_SPOT[0], 1.75, CAESAR_SPOT[2]]
    : [0.1, 1.85, -1.05];
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.3} />
      <Canvas3D>
        <CameraRig position={cam} target={target} fov={idiots ? 48 : 54} />
        <Classroom board={boardTex()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={idiots ? 0 : -0.1}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            brow: idiots ? 1 : 0.3,
            browLift: idiots ? -0.3 : 0.1,
            mouth: idiots ? -0.6 : 0.4,
            lean: idiots ? 8 * point : 0,
            headTilt: idiots ? 0.05 : 0.06 * Math.sin(local * 0.25),
            armR: idiots ? [-0.3 - 1.25 * point, 0, 0.1 * point] : [-0.6, 0, 0],
            armL: idiots ? [0, 0, 0] : [-0.9, 0, 0.3],
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
export const Lesson03: React.FC = () => (
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
          from={SHOT.temple[0]}
          durationInFrames={len("temple")}
          name="Desk: Rome builds"
        >
          <DeskShot start={SHOT.temple[0]} phase="temple" />
        </Sequence>
        <Sequence
          from={SHOT.coins[0]}
          durationInFrames={len("coins")}
          name="Desk: coins double"
        >
          <DeskShot start={SHOT.coins[0]} phase="coins" />
        </Sequence>
        <Sequence
          from={SHOT.graph[0]}
          durationInFrames={len("graph")}
          name="Board: growth"
        >
          <GraphShot />
        </Sequence>
        <Sequence
          from={SHOT.friday[0]}
          durationInFrames={len("friday")}
          name="Student: rich by Friday"
        >
          <FridayShot />
        </Sequence>
        <Sequence
          from={SHOT.idiots[0]}
          durationInFrames={len("idiots")}
          name="Caesar: idiots"
        >
          <CaesarClose start={SHOT.idiots[0]} mode="idiots" />
        </Sequence>
        <Sequence
          from={SHOT.patient[0]}
          durationInFrames={len("patient")}
          name="Caesar: be patient"
        >
          <CaesarClose start={SHOT.patient[0]} mode="patient" />
        </Sequence>
        <Sequence
          from={SHOT.title[0]}
          durationInFrames={len("title")}
          name="Title card"
        >
          <TitleCard
            word="COMPOUND"
            line1="Start early. Be patient."
            line2="Lesson III."
            startAt={6}
            letterEvery={5}
            underlineFrames={20}
            line1At={70}
            line2At={100}
            fadeFrames={40}
          />
        </Sequence>

        <Subtitles lines={LINES} />
        <LessonHud numeral="III" hideFrom={SHOT.title[0]} />
      </AbsoluteFill>
    </LookContext.Provider>
  </SafeContext.Provider>
);
