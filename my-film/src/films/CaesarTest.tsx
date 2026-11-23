import React from "react";
import { Audio } from "@remotion/media";
import { ThreeCanvas } from "@remotion/three";
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
import { Letterbox } from "../components/Letterbox";
import { LookDefs } from "../components/LookFx";
import { Sfx } from "../components/Sfx";
import { Subtitles } from "../components/Subtitles";
import { DayCounter } from "../components/Text";
import { TitleCard } from "../components/TitleCard";
import { comic } from "../fonts";
import { Look, LookContext, LOOKS } from "../looks";
import { SAFE_REELS, SafeContext } from "../layout";
import { FPS } from "../theme";
import {
  BOARD,
  CAESAR_SPOT,
  Classroom,
  STUDENT_SPOT,
} from "../three/Classroom";
import { chalkboardTex } from "../three/textures";
import { Voxel, VoxelPose } from "../three/Voxel";
import { CameraRig } from "../three/World";
import { voice } from "../voice/caesar-test";
import { findWord, placeLines, talkAt } from "../voice/sync";

/**
 * Caesar test (about 10 seconds).
 * Lesson I: never put everything in one stock (Brutus joke).
 * All timing comes from the voice track in src/voice/caesar-test.ts.
 */

const CAESAR_LOOK: Look = { ...LOOKS.blocky, accent: "#D4343C" };
const CRIMSON = "#D4343C";
const CL = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const ease = Easing.inOut(Easing.cubic);

// ---- timeline from the voice ----
const SLAM = 9; // ruler hits the desk
const LINES = placeLines(voice, [0.4, 0.3, 0.25, 0.3], FPS);
const [L1, L2, L3, L4] = LINES;
const SHOT = {
  wide: [0, L2.from],
  caesar: [L2.from, L3.from],
  board: [L3.from, L4.from - 3],
  title: [L4.from - 3, L4.from - 3 + 84],
} as const;
export const CAESAR_TEST_DURATION = SHOT.title[1];
const len = (k: keyof typeof SHOT) => SHOT[k][1] - SHOT[k][0];

// ---- board ----
const PX = BOARD.w / 128; // world units per board pixel
const boardPos = (px: number, py: number): [number, number, number] => [
  BOARD.x - BOARD.w / 2 + px * PX,
  BOARD.y + BOARD.h / 2 - py * PX,
  BOARD.z + 0.04,
];
const boardTex = () =>
  chalkboardTex(
    "lesson-1",
    [
      { text: "LESSON I", x: 4, y: 3 },
      { text: "1 STOCK", x: 6, y: 50 },
      { text: "MANY", x: 82, y: 50 },
    ],
    (ctx) => {
      ctx.fillStyle = "#ECECE4";
      // one big box with a "1" in it
      ctx.fillRect(10, 18, 26, 1);
      ctx.fillRect(10, 43, 26, 1);
      ctx.fillRect(10, 18, 1, 26);
      ctx.fillRect(35, 18, 1, 26);
      // dagger stuck in the box
      ctx.fillStyle = "#C9CBD4";
      for (let i = 0; i < 10; i++) ctx.fillRect(28 + i, 26 - i, 2, 1);
      ctx.fillStyle = "#B8863A";
      ctx.fillRect(37, 14, 5, 2);
      ctx.fillRect(38, 13, 2, 5);
      // many small boxes
      ctx.fillStyle = "#ECECE4";
      for (let r = 0; r < 3; r++)
        for (let c = 0; c < 4; c++) {
          const x = 72 + c * 11;
          const y = 18 + r * 10;
          ctx.fillRect(x, y, 8, 1);
          ctx.fillRect(x, y + 7, 8, 1);
          ctx.fillRect(x, y, 1, 8);
          ctx.fillRect(x + 7, y, 1, 8);
        }
      // arrow from 1 to many
      ctx.fillRect(44, 31, 20, 1);
      ctx.fillRect(61, 29, 1, 5);
      ctx.fillRect(62, 30, 1, 3);
    },
  );

const Canvas3D: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { width, height } = useVideoConfig();
  return (
    <ThreeCanvas width={width} height={height} shadows gl={{ antialias: true }}>
      {children}
    </ThreeCanvas>
  );
};

/** idle life: breathing + occasional blinks, keyed off absolute frame */
const life = (f: number, seed = 0) => ({
  squash: 1 + 0.012 * Math.sin((f + seed * 13) * 0.15),
  blink:
    Math.max(0, 1 - Math.abs(((f + seed * 37) % 70) - 35) / 3) *
    ((f + seed * 37) % 140 < 70 ? 1 : 0),
  t: f,
});

// --------------------------------------------------------------------------
const WideShot: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const idiots = findWord(L1, "fucking", fps);

  // ruler: raise, slam, then point at the audience on the insult
  const raise = interpolate(f, [0, 6], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.quad),
  });
  const slam = interpolate(f, [6, SLAM], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  const recover = interpolate(f, [SLAM + 8, SLAM + 18], [0, 1], {
    ...CL,
    easing: ease,
  });
  const point = interpolate(f, [idiots - 6, idiots], [0, 1], {
    ...CL,
    easing: ease,
  });
  let armR: [number, number, number] = [-2.8 * raise, 0, 0.15 * raise];
  if (f >= 6) armR = [-2.8 + 1.6 * slam, 0, 0.15 * (1 - slam)];
  if (f >= SLAM + 8)
    armR = [-1.2 + 0.85 * recover * (1 - point) - 0.3 * point, 0, 0.1 * point];

  const impact = spring({
    frame: f - SLAM,
    fps,
    config: { damping: 7, stiffness: 260 },
  });
  const caesarSquash = f >= SLAM ? interpolate(impact, [0, 1], [0.9, 1]) : 1;

  const flinch = spring({
    frame: f - SLAM,
    fps,
    config: { damping: 6, stiffness: 240 },
  });
  const flinchAmt = f >= SLAM ? 1 - flinch : 0;
  const guilt = interpolate(f, [idiots, idiots + 6], [0, 1], {
    ...CL,
    easing: ease,
  });

  // camera shake on the slam
  const shake = f >= SLAM && f < SLAM + 7 ? (1 - (f - SLAM) / 7) * 0.06 : 0;
  const cam: [number, number, number] = [
    -0.3 + Math.sin(f * 7.3) * shake,
    3.3 + Math.cos(f * 9.1) * shake,
    6.4,
  ];

  const L = life(f);
  const caesarPose: VoxelPose = {
    ...L,
    squash: L.squash * caesarSquash,
    brow: 0.75 + 0.25 * point,
    browLift: -0.2,
    talk: talkAt(LINES, f, fps),
    mouth: -0.4,
    lean: 6 * point,
    armR,
    armOverride: 1,
  };
  const studentPose: VoxelPose = {
    ...life(f, 2),
    sit: 1,
    lift: 0.14 * Math.max(0, flinchAmt),
    squash: 1 + 0.12 * flinchAmt,
    brow: -0.7 - 0.2 * guilt,
    browLift: 0.6 + 0.6 * flinchAmt,
    mouth: -0.5,
    arms: "forward",
    armBlend: 0.75,
    headYaw: 1.0 * guilt,
  };

  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={4} volume={0.35} rate={1.3} />
      <Sfx name="hit" at={SLAM} volume={0.9} />
      <Canvas3D>
        <CameraRig position={cam} target={[0.15, 1.75, -1]} fov={56} />
        <Classroom board={boardTex()} />
        <Voxel
          position={CAESAR_SPOT}
          facing={0.15}
          outfit="caesar"
          ruler
          pose={caesarPose}
        />
        <Voxel
          position={STUDENT_SPOT}
          facing={-Math.PI / 2 + 0.55}
          pose={studentPose}
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
const CaesarCloseUp: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.caesar[0]; // absolute frame for voice lookups
  const one = findWord(L2, "ONE", fps);
  const brutus = findWord(L2, "Brutus", fps);

  const lift = interpolate(f, [one - 6, one], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.back(1.6)),
  });
  const drop = interpolate(f, [brutus - 4, brutus + 4], [0, 1], {
    ...CL,
    easing: ease,
  });
  const hurt = interpolate(f, [brutus, brutus + 10], [0, 1], {
    ...CL,
    easing: ease,
  });
  const push = interpolate(f, [brutus - 4, SHOT.caesar[1]], [0, 1], {
    ...CL,
    easing: ease,
  });

  const armR: [number, number, number] = [
    -0.3 - 2.6 * lift * (1 - drop),
    0,
    0.12 * lift * (1 - drop),
  ];
  const armL: [number, number, number] = [-1.0 * hurt, 0, 0.75 * hurt];
  const cam: [number, number, number] = [
    CAESAR_SPOT[0] + 0.15,
    2.05,
    2.3 - 0.5 * push,
  ];

  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.3} />
      <Sfx name="pop" at={one - SHOT.caesar[0]} volume={0.5} rate={0.8} />
      <Sfx name="drone" at={brutus - SHOT.caesar[0]} volume={0.5} />
      <Canvas3D>
        <CameraRig
          position={cam}
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
            ...life(f),
            brow: 0.6 - 1.5 * hurt,
            browLift: 0.9 * hurt,
            talk: talkAt(LINES, f, fps),
            mouth: -0.6,
            headTilt: 0.12 * hurt,
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
/** chalk X drawn across the "1 STOCK" box, growing over time */
const ChalkX: React.FC<{ p: number }> = ({ p }) => {
  const a = boardPos(10, 18);
  const b = boardPos(36, 44);
  const cx = (a[0] + b[0]) / 2;
  const cy = (a[1] + b[1]) / 2;
  const diag = Math.hypot(b[0] - a[0], b[1] - a[1]);
  const ang = Math.atan2(a[1] - b[1], b[0] - a[0]);
  const s1 = Math.min(1, p * 2);
  const s2 = Math.max(0, p * 2 - 1);
  return (
    <group position={[cx, cy, BOARD.z + 0.05]}>
      <mesh
        rotation={[0, 0, -ang]}
        position={[
          (-diag / 2) * (1 - s1) * Math.cos(ang),
          (diag / 2) * (1 - s1) * Math.sin(ang),
          0,
        ]}
        scale={[s1 || 0.001, 1, 1]}
      >
        <boxGeometry args={[diag, 0.07, 0.01]} />
        <meshBasicMaterial color="#F2F2EA" toneMapped={false} />
      </mesh>
      <mesh
        rotation={[0, 0, ang]}
        position={[
          (-diag / 2) * (1 - s2) * Math.cos(ang),
          (-diag / 2) * (1 - s2) * Math.sin(ang),
          0,
        ]}
        scale={[s2 || 0.001, 1, 1]}
      >
        <boxGeometry args={[diag, 0.07, 0.01]} />
        <meshBasicMaterial color="#F2F2EA" toneMapped={false} />
      </mesh>
    </group>
  );
};

/** 1..23 stab counter that rolls up while he says it */
const StabCounter: React.FC<{ until: number }> = ({ until }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const n = Math.max(
    1,
    Math.min(23, Math.round(interpolate(f, [2, until], [1, 23], CL))),
  );
  const done = f >= until;
  const s = spring({
    frame: f - until,
    fps,
    config: { damping: 7, stiffness: 260 },
  });
  const scale = done
    ? interpolate(s, [0, 1], [1.6, 1.15])
    : 1 + 0.08 * Math.sin(f * 2.2);
  return (
    <div
      style={{
        position: "absolute",
        left: 470,
        right: 40,
        top: 520,
        textAlign: "center",
        fontFamily: CAESAR_LOOK.font,
        fontWeight: 700,
        color: CRIMSON,
        transform: `scale(${scale}) rotate(${done ? -6 : 0}deg)`,
        WebkitTextStroke: "10px #000",
        paintOrder: "stroke",
      }}
    >
      <div style={{ fontSize: 190, lineHeight: 1 }}>{n}</div>
      <div style={{ fontSize: 54, color: "#FFF" }}>stab wounds</div>
    </div>
  );
};

const BoardShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const until = Math.round((L3.duration - 0.15) * fps);
  const chalk = interpolate(local, [3, len("board") - 4], [0, 1], CL);
  const ticks = Array.from({ length: 11 }, (_, i) =>
    Math.round(2 + (i / 11) * (until - 2)),
  );

  return (
    <AbsoluteFill>
      <Sfx name="chalk" at={2} volume={0.5} />
      {ticks.map((at, i) => (
        <Sfx key={at} name="pop" at={at} volume={0.35} rate={1 + i * 0.06} />
      ))}
      <Sfx name="stab" at={until} volume={0.9} />
      <Canvas3D>
        <CameraRig
          position={[BOARD.x - 0.95, BOARD.y - 0.55, 1.5]}
          target={[BOARD.x - 0.95, BOARD.y - 0.55, BOARD.z]}
          fov={62}
        />
        <Classroom board={boardTex()} />
        <ChalkX p={chalk} />
      </Canvas3D>
      <StabCounter until={until} />
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const LessonHud: React.FC = () => {
  const f = useCurrentFrame();
  if (f >= SHOT.title[0]) return null;
  return <DayCounter day="I" label="LESSON" since={30 + f} />;
};

const PlaceholderBadge: React.FC = () =>
  voice.placeholder ? (
    <div
      style={{
        position: "absolute",
        right: 40,
        top: SAFE_REELS.top + 24,
        fontFamily: comic,
        fontSize: 22,
        color: "#FFD27A",
        background: "rgba(0,0,0,0.6)",
        padding: "4px 10px",
        borderRadius: 6,
      }}
    >
      PREVIEW: voice not generated yet
    </div>
  ) : null;

export const CaesarTest: React.FC = () => (
  <SafeContext.Provider value={SAFE_REELS}>
    <LookContext.Provider value={CAESAR_LOOK}>
      <AbsoluteFill style={{ background: "#000" }}>
        <LookDefs />
        <Sfx name="hum" at={0} duration={SHOT.title[0]} loop volume={0.2} />
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
          name="Wide: slam + insult"
        >
          <WideShot />
        </Sequence>
        <Sequence
          from={SHOT.caesar[0]}
          durationInFrames={len("caesar")}
          name="Close-up: Brutus"
        >
          <CaesarCloseUp />
        </Sequence>
        <Sequence
          from={SHOT.board[0]}
          durationInFrames={len("board")}
          name="Board: 23 stabs"
        >
          <BoardShot />
        </Sequence>
        <Sequence
          from={SHOT.title[0]}
          durationInFrames={len("title")}
          name="Title card"
        >
          <TitleCard
            word="DIVERSIFY"
            line1="Never trust one stock."
            line2="Lesson I."
            startAt={3}
            letterEvery={3}
            underlineFrames={12}
            line1At={32}
            line2At={40}
            fadeFrames={14}
          />
        </Sequence>

        <Subtitles lines={LINES.slice(0, 3)} />
        <LessonHud />
        <PlaceholderBadge />
        <Letterbox />
      </AbsoluteFill>
    </LookContext.Provider>
  </SafeContext.Provider>
);
