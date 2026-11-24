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
import { voice } from "../voice/lesson-07";
import { findWord, placeLines, talkAt } from "../voice/sync";
import { CAESAR_LOOK, CL, Canvas3D, CRIMSON, LessonHud, life } from "./kit";

/**
 * Lesson VII: pay off high-interest debt first.
 * History: before his governorship in Spain (61 BC) Caesar's creditors
 * tried to stop him leaving Rome until Crassus guaranteed his debts
 * (Plutarch: 830 talents). His later conquest of Gaul made him rich.
 * Advice: credit cards often charge 20%+ a year; paying one off is like
 * a guaranteed return of that rate, so clear it before investing.
 * All timing comes from the voice track in src/voice/lesson-07.ts.
 */

const ease = Easing.inOut(Easing.cubic);
const GREEN = "#4CC26A";
const RED = "#FF4D4D";
const GOLD = "#E8C04A";

// ---- timeline from the voice ----
const LINES = placeLines(
  voice,
  [0.45, 0.35, 0.25, 0.35, 0.35, 0.3, 0.35, 0.4],
  FPS,
);
const [, L2, L3, L4, L5, L6, L7, L8] = LINES;
const SHOT = {
  wide: [0, L2.from],
  debt: [L2.from, L4.from],
  gaul: [L4.from, L5.from],
  card: [L5.from, L6.from],
  bars: [L6.from, L7.from],
  idiot: [L7.from, L8.from - 10],
  kill: [L8.from - 10, L8.to + 16],
  title: [L8.to + 16, L8.to + 16 + 180],
} as const;
export const LESSON_07_DURATION = SHOT.title[1];
const len = (k: keyof typeof SHOT) => SHOT[k][1] - SHOT[k][0];

// ---- boards ----
const GAUL: [number, number][] = [
  [20, 20],
  [34, 14],
  [52, 16],
  [66, 13],
  [78, 22],
  [74, 34],
  [80, 44],
  [62, 50],
  [44, 48],
  [30, 52],
  [16, 44],
  [20, 32],
];
const plotLine = (
  ctx: CanvasRenderingContext2D,
  a: [number, number],
  b: [number, number],
) => {
  const n = Math.max(Math.abs(b[0] - a[0]), Math.abs(b[1] - a[1]));
  for (let i = 0; i <= n; i++)
    ctx.fillRect(
      Math.round(a[0] + ((b[0] - a[0]) * i) / n),
      Math.round(a[1] + ((b[1] - a[1]) * i) / n),
      1,
      1,
    );
};
/** the map of Gaul (first half of the film) */
const gaulBoard = () =>
  chalkboardTex(
    "lesson-7-gaul",
    [
      { text: "LESSON VII", x: 4, y: 3 },
      { text: "GAUL", x: 38, y: 29 },
      { text: "ROME", x: 98, y: 50 },
    ],
    (ctx) => {
      ctx.fillStyle = "#ECECE4";
      GAUL.forEach((p, i) => plotLine(ctx, p, GAUL[(i + 1) % GAUL.length]));
      // Rome, far away to the south-east
      ctx.fillStyle = "#F4B6B6";
      ctx.fillRect(108, 42, 3, 3);
      ctx.fillStyle = "#ECECE4";
      for (let i = 0; i < 9; i++)
        ctx.fillRect(84 + i * 2.5, 40 - i * 0.3, 1, 1);
    },
  );
/** bar chart: stocks (uncertain) vs paying off debt (certain) */
const barsBoard = () =>
  chalkboardTex(
    "lesson-7-bars",
    [
      { text: "LESSON VII", x: 4, y: 3 },
      { text: "STOCKS", x: 12, y: 52 },
      { text: "PAYOFF", x: 50, y: 52 },
    ],
    (ctx) => {
      ctx.fillStyle = "#ECECE4";
      ctx.fillRect(8, 12, 1, 38);
      ctx.fillRect(8, 49, 80, 1);
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
// the debt pile: IOU scrolls stacked in a pyramid
const SCROLLS: [number, number, number][] = [];
[
  [4, 0],
  [3, 1],
  [2, 2],
  [1, 3],
].forEach(([n, row]) => {
  for (let i = 0; i < n; i++)
    SCROLLS.push([
      (i - (n - 1) / 2) * 0.12,
      0.05 + row * 0.085,
      (row % 2) * 0.02,
    ]);
});

const DEBT_START = findWord(L2, "drowning", FPS) - 4;
const KILL_AT = findWord(L8, "highest", FPS);

/** scrolls appear one by one; from `killAt` they fly apart */
const DebtPile: React.FC<{ f: number }> = ({ f }) => {
  const { fps } = useVideoConfig();
  const broken = f >= KILL_AT;
  const t = broken ? (f - KILL_AT) / fps : 0;
  return (
    <group position={[DESK.x + 0.48, DESK.h + 0.06, DESK.z - 0.15]}>
      {SCROLLS.map(([x, y, z], i) => {
        const at = DEBT_START + i * 2;
        const s = pop(f, at, fps);
        if (s <= 0) return null;
        let px = x;
        let py = y;
        let pz = z;
        let rot = 0;
        if (broken) {
          px += (x * 6 + ((i % 3) - 1) * 0.4) * t;
          pz += (0.8 + (i % 2) * 0.4) * t;
          py = Math.max(0.05, y + (1.6 + (i % 4) * 0.3) * t - 4.9 * t * t);
          rot = t * (5 + i);
        }
        return (
          <group
            key={i}
            position={[px, py, pz]}
            rotation={[rot, 0, rot * 0.5]}
            scale={s}
          >
            <mesh castShadow>
              <boxGeometry args={[0.11, 0.08, 0.3]} />
              <meshLambertMaterial map={noiseTex("#EADFC2", 0.06, 8)} />
            </mesh>
            <mesh position={[0, 0, 0.152]}>
              <boxGeometry args={[0.05, 0.05, 0.01]} />
              <meshLambertMaterial color="#B3262E" />
            </mesh>
          </group>
        );
      })}
    </group>
  );
};

/** the student's credit card, slowly eating his coin stack */
const CardAndCoins: React.FC<{ f: number; start: number; eatFrom: number }> = ({
  f,
  start,
  eatFrom,
}) => {
  const { fps } = useVideoConfig();
  const s = pop(f, start, fps);
  const eaten = Math.floor(interpolate(f, [eatFrom, eatFrom + 60], [0, 5], CL));
  const base: [number, number, number] = [
    STUDENT_SPOT[0] + 0.35,
    0.87,
    STUDENT_SPOT[2] - 0.62,
  ];
  return (
    <group position={base}>
      {s > 0 && (
        <group position={[0, 0.02, 0]} rotation={[0, 0.3, 0]} scale={s}>
          <mesh castShadow>
            <boxGeometry args={[0.32, 0.025, 0.2]} />
            <meshLambertMaterial map={noiseTex("#1F3B73", 0.08, 8)} />
          </mesh>
          <mesh position={[-0.08, 0.014, -0.03]}>
            <boxGeometry args={[0.06, 0.005, 0.045]} />
            <meshLambertMaterial color={GOLD} />
          </mesh>
          <mesh position={[0, 0.014, 0.06]}>
            <boxGeometry args={[0.24, 0.005, 0.02]} />
            <meshLambertMaterial color="#9FB4E0" />
          </mesh>
        </group>
      )}
      {/* coin stack shrinking as interest eats it */}
      {Array.from({ length: 6 - eaten }, (_, k) => (
        <mesh key={k} position={[-0.32, 0.02 + k * 0.038, 0.02]} castShadow>
          <boxGeometry args={[0.1, 0.035, 0.1]} />
          <meshLambertMaterial map={noiseTex(GOLD, 0.14, 8)} />
        </mesh>
      ))}
    </group>
  );
};

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
        <Classroom board={gaulBoard()} coins={false} />
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
/** "I was drowning in debt... creditors wouldn't let me leave Rome" */
const DebtShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.debt[0];
  const shame = interpolate(f, [DEBT_START, DEBT_START + 20], [0, 1], {
    ...CL,
    easing: ease,
  });
  const creditorsAt = findWord(L3, "creditors", fps);
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      {SCROLLS.map((_, i) => (
        <Sfx
          key={i}
          name="pop"
          at={DEBT_START + i * 2 - SHOT.debt[0]}
          volume={0.3}
          rate={0.8 + i * 0.05}
        />
      ))}
      <Canvas3D>
        <CameraRig
          position={MEDIUM_CAM.position}
          target={MEDIUM_CAM.target}
          fov={54}
        />
        <Classroom board={gaulBoard()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={-0.05}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            brow: 0.4 - 1.2 * shame,
            browLift: 0.8 * shame,
            mouth: -0.4,
            headTilt: 0.1 * shame,
            armL: [-0.9 * shame, 0, 0.4 * shame],
            armOverride: 1,
          }}
        />
        <DebtPile f={f} />
      </Canvas3D>
      <Sequence
        from={DEBT_START + 16 - SHOT.debt[0]}
        durationInFrames={creditorsAt - DEBT_START - 16}
        layout="none"
      >
        <RepPop
          text="IOU: 830 TALENTS"
          x={540}
          y={1250}
          size={80}
          color={RED}
        />
      </Sequence>
      <Sequence from={creditorsAt - SHOT.debt[0]} layout="none">
        <RepPop
          text="CAN'T LEAVE ROME"
          x={540}
          y={1250}
          size={80}
          color={RED}
        />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** the map of Gaul: conquered, debt paid. "You don't have a Gaul." */
const GaulShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s0 = SHOT.gaul[0];
  const conqAt = findWord(L4, "conquered", fps) - s0;
  const paidAt = findWord(L4, "off", fps) - s0;
  const noGaulAt = findWord(L4, "don't", fps) - s0;
  const sweep = interpolate(local, [conqAt, paidAt], [0, 1], {
    ...CL,
    easing: ease,
  });
  // a red chalk arrow from Rome sweeping into Gaul
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.2} />
      <Sfx name="chalk" at={conqAt} volume={0.4} />
      <Sfx name="shimmer" at={paidAt} volume={0.5} />
      <Sfx name="pop" at={noGaulAt + 4} volume={0.5} rate={0.6} />
      <Canvas3D>
        <CameraRig
          position={BOARD_CAM.position}
          target={BOARD_CAM.target}
          fov={62}
        />
        <Classroom board={gaulBoard()} coins={false} />
        <ChalkLine
          pts={[
            [86, 44],
            [70, 38],
            [56, 32],
            [46, 30],
          ]}
          p={sweep}
          color="#FF8A8A"
          width={0.09}
        />
        {sweep >= 1 && (
          <mesh
            position={boardPos(42, 33, 0.07)}
            scale={pop(local, paidAt, fps)}
          >
            <boxGeometry args={[0.5, 0.5, 0.02]} />
            <meshBasicMaterial
              color={GOLD}
              toneMapped={false}
              transparent
              opacity={0.45}
            />
          </mesh>
        )}
      </Canvas3D>
      <Sequence
        from={paidAt}
        durationInFrames={noGaulAt - paidAt}
        layout="none"
      >
        <RepPop text="DEBT: PAID" x={540} y={1250} size={96} color={GREEN} />
      </Sequence>
      <Sequence from={noGaulAt + 4} layout="none">
        <RepPop text="YOU: NO GAUL" x={540} y={1250} size={96} color={RED} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const CardShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.card[0];
  const cardAt = findWord(L5, "credit", fps);
  const pctAt = findWord(L5, "twenty", fps);
  const worry = interpolate(f, [pctAt, pctAt + 10], [0, 1], {
    ...CL,
    easing: ease,
  });
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Sfx name="pop" at={cardAt - SHOT.card[0]} volume={0.5} />
      <Sfx name="fall" at={pctAt - SHOT.card[0]} volume={0.45} />
      <Canvas3D>
        <CameraRig
          position={STUDENT_CAM.position}
          target={STUDENT_CAM.target}
          fov={50}
        />
        <Classroom board={gaulBoard()} coins={false} />
        <Voxel
          position={STUDENT_SPOT}
          facing={Math.PI}
          pose={{
            ...life(f, 2),
            sit: 1,
            brow: 0.3 - 1.2 * worry,
            browLift: 0.9 * worry,
            mouth: 0.4 - 1.2 * worry,
            arms: "forward",
            armBlend: 0.8,
            headTilt: 0.2,
          }}
        />
        <CardAndCoins f={f} start={cardAt} eatFrom={pctAt} />
      </Canvas3D>
      <Sequence from={pctAt - SHOT.card[0]} layout="none">
        <RepPop text="20%+ A YEAR" x={540} y={560} size={110} color={RED} />
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
  const base = boardPos(x, 49, 0.06);
  return (
    <mesh position={[base[0], base[1] + (h * k) / 2, base[2]]}>
      <boxGeometry args={[10 * k, h * k, 0.02]} />
      <meshBasicMaterial color={color} toneMapped={false} />
    </mesh>
  );
};

/** stocks: uncertain wobbling bar. Paying off debt: a solid, certain bar. */
const BarsShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s0 = SHOT.bars[0];
  const guaranteedAt = findWord(L6, "guaranteed", fps) - s0;
  const pctAt = findWord(L6, "twenty", fps) - s0;
  const stocks =
    interpolate(local, [2, 16], [0, 1], { ...CL, easing: ease }) *
    (18 + 9 * Math.sin(local * 0.35) + 4 * Math.sin(local * 0.9));
  const payoff = interpolate(local, [guaranteedAt, pctAt + 6], [0, 30], {
    ...CL,
    easing: Easing.out(Easing.back(1.2)),
  });
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.2} />
      <Sfx name="rise" at={guaranteedAt} volume={0.5} />
      <Sfx name="hit" at={pctAt + 6} volume={0.5} rate={1.2} />
      <Canvas3D>
        <CameraRig
          position={BOARD_CAM.position}
          target={BOARD_CAM.target}
          fov={62}
        />
        <Classroom board={barsBoard()} coins={false} />
        <Bar x={23} h={stocks} color="#F2F2EA" />
        <Bar x={61} h={payoff} color="#8CF0A2" />
      </Canvas3D>
      <Sequence from={4} durationInFrames={guaranteedAt - 4} layout="none">
        <RepPop text="STOCKS: ???" x={540} y={1250} size={88} />
      </Sequence>
      <Sequence from={pctAt + 6} layout="none">
        <RepPop
          text="GUARANTEED 20%"
          x={540}
          y={1250}
          size={88}
          color={GREEN}
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
  const idiotAt = findWord(L7, "fucking", fps);
  const point = interpolate(f, [idiotAt - 6, idiotAt], [0, 1], {
    ...CL,
    easing: ease,
  });
  const cam = CLOSE_CAM(
    interpolate(local, [0, 100], [0, 1], { ...CL, easing: ease }),
  );
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.25} />
      <Canvas3D>
        <CameraRig position={cam.position} target={cam.target} fov={48} />
        <Classroom board={barsBoard()} coins={false} />
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
        <DebtPile f={f} />
      </Canvas3D>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
/** "Kill the highest interest debt first": Caesar runs the pile through */
const KillShot: React.FC = () => {
  const local = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = local + SHOT.kill[0];
  const kill = KILL_AT - SHOT.kill[0];
  const investAt = findWord(L8, "invest", fps) - SHOT.kill[0];
  const raise = interpolate(local, [0, kill - 3], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.quad),
  });
  const down = interpolate(local, [kill - 3, kill], [0, 1], {
    ...CL,
    easing: Easing.in(Easing.quad),
  });
  const calm = interpolate(local, [kill + 14, kill + 26], [0, 1], {
    ...CL,
    easing: ease,
  });
  const armR: [number, number, number] = [
    (-2.8 * raise + 1.6 * down) * (1 - calm) - 0.5 * calm,
    0,
    0.15 * raise * (1 - down) * (1 - calm),
  ];
  const impact = spring({
    frame: local - kill,
    fps,
    config: { damping: 7, stiffness: 260 },
  });
  const shake =
    local >= kill && local < kill + 7 ? (1 - (local - kill) / 7) * 0.05 : 0;
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={kill - 3} volume={0.15} rate={1.4} />
      <Sfx name="stab" at={kill} volume={0.8} />
      <Sfx name="hit" at={kill + 1} volume={0.6} />
      <Sfx name="shimmer" at={investAt} volume={0.5} />
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
        <Classroom board={barsBoard()} coins={false} />
        <Voxel
          position={CAESAR_SPOT}
          facing={-0.1}
          outfit="caesar"
          ruler
          pose={{
            ...caesarTalk(f, fps),
            squash: local >= kill ? interpolate(impact, [0, 1], [0.9, 1]) : 1,
            brow: 1 - 0.7 * calm,
            mouth: -0.3 + 0.8 * calm,
            armR,
            armOverride: 1,
          }}
        />
        <DebtPile f={f} />
      </Canvas3D>
      <Sequence from={kill} durationInFrames={9} layout="none">
        <SpeedLines cx={700} cy={1000} />
      </Sequence>
      <Sequence from={kill} durationInFrames={3} layout="none">
        <Flash strength={0.6} />
      </Sequence>
      <Sequence
        from={kill + 2}
        durationInFrames={investAt - kill - 2}
        layout="none"
      >
        <RepPop text="DEBT: SLAIN" x={540} y={560} size={96} color={CRIMSON} />
      </Sequence>
      <Sequence from={investAt} layout="none">
        <RepPop text="NOW INVEST" x={540} y={560} size={96} color={GREEN} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
export const Lesson07: React.FC = () => (
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
          from={SHOT.debt[0]}
          durationInFrames={len("debt")}
          name="Caesar: drowning in debt"
        >
          <DebtShot />
        </Sequence>
        <Sequence
          from={SHOT.gaul[0]}
          durationInFrames={len("gaul")}
          name="Board: Gaul"
        >
          <GaulShot />
        </Sequence>
        <Sequence
          from={SHOT.card[0]}
          durationInFrames={len("card")}
          name="Student: credit card"
        >
          <CardShot />
        </Sequence>
        <Sequence
          from={SHOT.bars[0]}
          durationInFrames={len("bars")}
          name="Board: guaranteed return"
        >
          <BarsShot />
        </Sequence>
        <Sequence
          from={SHOT.idiot[0]}
          durationInFrames={len("idiot")}
          name="Caesar: idiot"
        >
          <IdiotShot />
        </Sequence>
        <Sequence
          from={SHOT.kill[0]}
          durationInFrames={len("kill")}
          name="Caesar: kill the debt"
        >
          <KillShot />
        </Sequence>
        <Sequence
          from={SHOT.title[0]}
          durationInFrames={len("title")}
          name="Title card"
        >
          <TitleCard
            word="PAYOFF"
            line1="Highest interest first."
            line2="Lesson VII."
            startAt={6}
            letterEvery={6}
            underlineFrames={20}
            line1At={60}
            line2At={100}
            fadeFrames={40}
          />
        </Sequence>

        <Subtitles lines={LINES} />
        <LessonHud numeral="VII" hideFrom={SHOT.title[0]} />
      </AbsoluteFill>
    </LookContext.Provider>
  </SafeContext.Provider>
);
