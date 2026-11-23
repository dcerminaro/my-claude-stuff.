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
import { chalkboardTex, noiseTex, stripesTex } from "../three/textures";
import { Voxel, VoxelPose } from "../three/Voxel";
import { CameraRig, Glow3D } from "../three/World";
import { voice } from "../voice/lesson-04";
import { findWord, placeLines, talkAt } from "../voice/sync";
import { CAESAR_LOOK, CL, Canvas3D, LessonHud, life } from "./kit";

/**
 * Lesson IV: ignore the hype (bread and circuses).
 * All timing comes from the voice track in src/voice/lesson-04.ts.
 */

const ease = Easing.inOut(Easing.cubic);
const HYPE = "#39FF88";
const RED = "#FF4D4D";

// ---- timeline from the voice ----
const LINES = placeLines(
  voice,
  [0.45, 0.35, 0.3, 0.3, 0.2, 0.3, 0.4, 0.35],
  FPS,
);
const [, L2, L3, L4, L5, L6, L7, L8] = LINES;
const SHOT = {
  wide: [0, L2.from],
  circus: [L2.from, L3.from],
  moon: [L3.from, L4.from],
  chart: [L4.from, L6.from],
  bag: [L6.from, L7.from],
  late: [L7.from, L8.from],
  boring: [L8.from, L8.to + 14],
  title: [L8.to + 14, L8.to + 14 + 180],
} as const;
export const LESSON_04_DURATION = SHOT.title[1];
const len = (k: keyof typeof SHOT) => SHOT[k][1] - SHOT[k][0];

// ---- board: a hype chart (left) and a chalk circus tent (right) ----
const boardTex = () =>
  chalkboardTex(
    "lesson-4",
    [
      { text: "LESSON IV", x: 4, y: 3 },
      { text: "HYPE", x: 14, y: 14 },
      { text: "CIRCUS", x: 89, y: 52 },
    ],
    (ctx) => {
      ctx.fillStyle = "#ECECE4";
      ctx.fillRect(8, 12, 1, 47);
      ctx.fillRect(8, 58, 80, 1);
      // chalk circus tent
      ctx.fillStyle = "#F4B6B6";
      for (let i = 0; i < 14; i++) {
        ctx.fillRect(106 - i, 30 + i, 1, 1);
        ctx.fillRect(106 + i, 30 + i, 1, 1);
      }
      ctx.fillRect(92, 44, 29, 1);
      for (const x of [97, 102, 106, 110, 115]) ctx.fillRect(x, 36, 1, 8);
      ctx.fillStyle = "#ECECE4";
      ctx.fillRect(106, 24, 1, 6);
      ctx.fillRect(107, 24, 3, 2);
    },
  );

const PUMP: [number, number][] = [
  [10, 52],
  [24, 51],
  [38, 50],
  [48, 47],
  [56, 40],
  [62, 28],
  [66, 17],
  [69, 10],
];
const DUMP: [number, number][] = [
  [69, 10],
  [73, 32],
  [78, 50],
  [86, 54],
];
const TOP = PUMP[PUMP.length - 1];
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

// ---- props ----
/** pops a prop in with a springy scale from frame `at` */
const usePop = (f: number, at: number) => {
  const { fps } = useVideoConfig();
  return f < at
    ? 0
    : spring({ frame: f - at, fps, config: { damping: 7, stiffness: 260 } });
};

const Bread: React.FC<{ f: number; at: number }> = ({ f, at }) => {
  const s = usePop(f, at);
  if (s <= 0) return null;
  return (
    <group position={[DESK.x - 0.38, DESK.h + 0.06, DESK.z + 0.05]} scale={s}>
      <mesh position={[0, 0.09, 0]} castShadow>
        <boxGeometry args={[0.44, 0.18, 0.22]} />
        <meshLambertMaterial map={noiseTex("#C98A42", 0.12, 8)} />
      </mesh>
      <mesh position={[0, 0.2, 0]} castShadow>
        <boxGeometry args={[0.38, 0.06, 0.18]} />
        <meshLambertMaterial map={noiseTex("#A86A2E", 0.12, 8)} />
      </mesh>
    </group>
  );
};

const Tent: React.FC<{ f: number; at: number }> = ({ f, at }) => {
  const s = usePop(f, at);
  if (s <= 0) return null;
  const stripes = stripesTex("#D4343C", "#F4EEDC");
  return (
    <group position={[DESK.x + 0.62, DESK.h + 0.06, DESK.z - 0.05]} scale={s}>
      {[
        [0.42, 0.16, 0.08],
        [0.32, 0.1, 0.24],
        [0.2, 0.1, 0.34],
        [0.08, 0.08, 0.42],
      ].map(([w, h, y], i) => (
        <mesh key={i} position={[0, y, 0]} castShadow>
          <boxGeometry args={[w, h, w]} />
          <meshLambertMaterial map={stripes} />
        </mesh>
      ))}
      <mesh position={[0, 0.55, 0]}>
        <boxGeometry args={[0.02, 0.16, 0.02]} />
        <meshLambertMaterial color="#5A3A1A" />
      </mesh>
      <mesh
        position={[0.05, 0.6, 0]}
        rotation={[0, 0, Math.sin(f * 0.3) * 0.15]}
      >
        <boxGeometry args={[0.1, 0.06, 0.01]} />
        <meshLambertMaterial color="#D8B448" />
      </mesh>
    </group>
  );
};

/** cartoon rocket launching from the student's desk */
const Rocket: React.FC<{ f: number; at: number }> = ({ f, at }) => {
  if (f < at) return null;
  const t = (f - at) / 30;
  const y = 0.95 + 2.2 * t * t + 0.25 * t;
  const wobble = Math.sin(f * 1.7) * 0.03;
  return (
    <group
      position={[STUDENT_SPOT[0] - 0.45 + wobble, y, STUDENT_SPOT[2] - 0.75]}
    >
      <mesh>
        <boxGeometry args={[0.14, 0.34, 0.14]} />
        <meshLambertMaterial map={noiseTex("#EEEEF2", 0.05, 8)} />
      </mesh>
      <mesh position={[0, 0.22, 0]}>
        <boxGeometry args={[0.09, 0.1, 0.09]} />
        <meshLambertMaterial color="#D4343C" />
      </mesh>
      {[-1, 1].map((sx) => (
        <mesh key={sx} position={[sx * 0.1, -0.13, 0]}>
          <boxGeometry args={[0.06, 0.1, 0.06]} />
          <meshLambertMaterial color="#D4343C" />
        </mesh>
      ))}
      <mesh
        position={[0, -0.24, 0]}
        scale={[1, 0.8 + 0.4 * Math.abs(Math.sin(f * 2.3)), 1]}
      >
        <boxGeometry args={[0.1, 0.14, 0.1]} />
        <meshBasicMaterial color="#FFB43A" toneMapped={false} />
      </mesh>
      <Glow3D
        position={[0, -0.28, 0.1]}
        size={0.9}
        color="#FFB43A"
        opacity={0.7}
      />
    </group>
  );
};

/** the bag he's left holding */
const Bag: React.FC<{ f: number; at: number }> = ({ f, at }) => {
  const s = usePop(f, at);
  if (s <= 0) return null;
  return (
    <group
      position={[STUDENT_SPOT[0] + 0.38, 0.87, STUDENT_SPOT[2] - 0.6]}
      scale={s}
    >
      <mesh position={[0, 0.2, 0]} castShadow>
        <boxGeometry args={[0.42, 0.4, 0.3]} />
        <meshLambertMaterial map={noiseTex("#9C7A4E", 0.16, 8)} />
      </mesh>
      <mesh position={[0, 0.44, 0]}>
        <boxGeometry args={[0.16, 0.08, 0.12]} />
        <meshLambertMaterial map={noiseTex("#7A5A34", 0.16, 8)} />
      </mesh>
      <mesh position={[0, 0.2, 0.152]}>
        <boxGeometry args={[0.16, 0.16, 0.01]} />
        <meshLambertMaterial color="#5A3E22" />
      </mesh>
    </group>
  );
};

// --------------------------------------------------------------------------
const caesarTalk = (f: number, fps: number): VoxelPose => ({
  ...life(f),
  talk: talkAt(LINES, f, fps),
  brow: 0.7,
  browLift: -0.1,
  mouth: -0.3,
});

const BREAD_AT = findWord(L2, "bread", FPS);
const TENT_AT = findWord(L2, "circuses", FPS);
const DeskProps: React.FC<{ f: number }> = ({ f }) => (
  <>
    <Bread f={f} at={BREAD_AT} />
    <Tent f={f} at={TENT_AT} />
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
/** Caesar presents bread and circuses on his desk */
const CircusShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.circus[0];
  const present = interpolate(f, [BREAD_AT - 6, BREAD_AT], [0, 1], {
    ...CL,
    easing: ease,
  });
  const show = interpolate(f, [TENT_AT - 6, TENT_AT], [0, 1], {
    ...CL,
    easing: ease,
  });
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="pop" at={BREAD_AT - SHOT.circus[0]} volume={0.55} rate={0.9} />
      <Sfx name="pop" at={TENT_AT - SHOT.circus[0]} volume={0.55} rate={1.2} />
      <Sfx name="shimmer" at={TENT_AT - SHOT.circus[0] + 6} volume={0.35} />
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
            brow: 0.2,
            browLift: 0.3,
            mouth: 0.4,
            headTilt: -0.08,
            armL: [-1.1 * present, 0, 0.3 * present],
            armR: [-0.3 - 0.9 * show, 0, -0.1 * show],
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** the student, hyped up (moon) or left holding the bag */
const StudentShot: React.FC<{ start: number; mode: "moon" | "bag" }> = ({
  start,
  mode,
}) => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + start;
  const moon = mode === "moon";
  const rocketAt = findWord(L3, "screaming", fps);
  const bagAt = findWord(L6, "bag", fps);
  const hyped = moon
    ? interpolate(f, [rocketAt - 10, rocketAt], [0, 1], { ...CL, easing: ease })
    : 0;
  const lookUp = moon
    ? interpolate(f, [rocketAt, rocketAt + 20], [0, 1], { ...CL, easing: ease })
    : 0;
  const sad = moon
    ? 0
    : interpolate(f, [bagAt, bagAt + 10], [0.4, 1], { ...CL, easing: ease });
  const bounce = moon ? Math.abs(Math.sin(f * 0.5)) * 0.05 * hyped : 0;
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      {moon ? (
        <Sfx name="rise" at={rocketAt - start} volume={0.6} />
      ) : (
        <>
          <Sfx name="pop" at={bagAt - start} volume={0.55} rate={0.7} />
          <Sfx name="fall" at={bagAt - start + 8} volume={0.35} rate={0.8} />
        </>
      )}
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
            lift: bounce,
            brow: moon ? -0.2 + 0.5 * hyped : -1,
            browLift: moon ? 0.8 * hyped : 0.9 * sad,
            mouth: moon ? 1 * hyped : -1 * sad,
            arms: moon ? "up" : "forward",
            armBlend: moon ? hyped : 0.85,
            headTilt: moon ? -0.35 * lookUp : 0.18 * sad,
          }}
        />
        {moon ? <Rocket f={f} at={rocketAt} /> : <Bag f={f} at={bagAt} />}
      </Canvas3D>
      {moon && (
        <Sequence from={rocketAt - start} layout="none">
          <RepPop text="TO THE MOON!" x={540} y={560} size={110} color={HYPE} />
        </Sequence>
      )}
      {!moon && (
        <Sequence from={bagAt - start + 4} layout="none">
          <RepPop text="-90%" x={790} y={760} size={130} color={RED} />
        </Sequence>
      )}
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const ChartShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = SHOT.chart[0];
  const pumpStart = findWord(L4, "buying", fps) - s - 6;
  const topAt = findWord(L4, "top", fps) - s;
  const dumpAt = findWord(L5, "leaves", fps) - s;
  const pump = interpolate(local, [pumpStart, topAt], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  const dump = interpolate(local, [dumpAt, dumpAt + 10], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  const dot =
    local >= topAt
      ? spring({
          frame: local - topAt,
          fps,
          config: { damping: 7, stiffness: 260 },
        })
      : 0;
  const shake =
    local >= dumpAt + 10 && local < dumpAt + 16
      ? (1 - (local - dumpAt - 10) / 6) * 0.03
      : 0;
  const dotPos = boardPos(TOP[0], TOP[1], 0.06);
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="chalk" at={pumpStart} volume={0.4} />
      <Sfx name="rise" at={pumpStart + 4} volume={0.45} rate={1.2} />
      <Sfx name="pop" at={topAt} volume={0.6} />
      <Sfx name="fall" at={dumpAt} volume={0.7} />
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
        <Classroom board={boardTex()} coins={false} />
        <ChalkLine pts={PUMP} p={pump} color="#8CF0A2" />
        <ChalkLine pts={DUMP} p={dump} color="#FF6B6B" />
        {dot > 0 && (
          <mesh position={dotPos} scale={dot}>
            <boxGeometry args={[0.16, 0.16, 0.02]} />
            <meshBasicMaterial color="#FF3B3B" toneMapped={false} />
          </mesh>
        )}
      </Canvas3D>
      <Sequence from={topAt} layout="none">
        <RepPop text="YOU BOUGHT HERE" x={540} y={470} size={70} color={RED} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const CaesarClose: React.FC<{ start: number; mode: "late" | "boring" }> = ({
  start,
  mode,
}) => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + start;
  const push = interpolate(local, [0, 60], [0, 1], { ...CL, easing: ease });
  const late = mode === "late";
  const point = interpolate(local, [0, 8], [0, 1], { ...CL, easing: ease });
  const cam: [number, number, number] = late
    ? [CAESAR_SPOT[0] + 0.15, 2.05, 2.3 - 0.5 * push]
    : MEDIUM_CAM.position;
  const target: [number, number, number] = late
    ? [CAESAR_SPOT[0], 1.75, CAESAR_SPOT[2]]
    : MEDIUM_CAM.target;
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Canvas3D>
        <CameraRig position={cam} target={target} fov={late ? 48 : 54} />
        <Classroom board={boardTex()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={late ? 0 : -0.1}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            brow: late ? 0.9 : 0.25,
            browLift: late ? -0.2 : 0.1,
            mouth: late ? -0.5 : 0.45,
            lean: late ? 6 * point : 0,
            headTilt: late ? 0.05 : 0.06 * Math.sin(local * 0.25),
            armR: late
              ? [-0.3 - 1.25 * point, 0, 0.1 * point]
              : [-1.35, 0, -0.85],
            armL: late ? [0, 0, 0] : [-1.35, 0, 0.85],
            armOverride: 1,
          }}
        />
        <DeskProps f={f} />
      </Canvas3D>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
export const Lesson04: React.FC = () => (
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
          from={SHOT.circus[0]}
          durationInFrames={len("circus")}
          name="Bread and circuses"
        >
          <CircusShot />
        </Sequence>
        <Sequence
          from={SHOT.moon[0]}
          durationInFrames={len("moon")}
          name="Student: to the moon"
        >
          <StudentShot start={SHOT.moon[0]} mode="moon" />
        </Sequence>
        <Sequence
          from={SHOT.chart[0]}
          durationInFrames={len("chart")}
          name="Board: pump and dump"
        >
          <ChartShot />
        </Sequence>
        <Sequence
          from={SHOT.bag[0]}
          durationInFrames={len("bag")}
          name="Student: holding the bag"
        >
          <StudentShot start={SHOT.bag[0]} mode="bag" />
        </Sequence>
        <Sequence
          from={SHOT.late[0]}
          durationInFrames={len("late")}
          name="Caesar: too late"
        >
          <CaesarClose start={SHOT.late[0]} mode="late" />
        </Sequence>
        <Sequence
          from={SHOT.boring[0]}
          durationInFrames={len("boring")}
          name="Caesar: boring wins"
        >
          <CaesarClose start={SHOT.boring[0]} mode="boring" />
        </Sequence>
        <Sequence
          from={SHOT.title[0]}
          durationInFrames={len("title")}
          name="Title card"
        >
          <TitleCard
            word="BORING"
            line1="Ignore the hype."
            line2="Lesson IV."
            startAt={6}
            letterEvery={6}
            underlineFrames={20}
            line1At={70}
            line2At={100}
            fadeFrames={40}
          />
        </Sequence>

        <Subtitles lines={LINES} />
        <LessonHud numeral="IV" hideFrom={SHOT.title[0]} />
      </AbsoluteFill>
    </LookContext.Provider>
  </SafeContext.Provider>
);
