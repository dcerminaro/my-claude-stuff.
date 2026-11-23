import React from "react";
import { ThreeCanvas } from "@remotion/three";
import {
  AbsoluteFill,
  Easing,
  interpolate,
  Sequence,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Flash, SpeedLines } from "../components/Effects";
import { Letterbox } from "../components/Letterbox";
import { LookDefs } from "../components/LookFx";
import { Sfx } from "../components/Sfx";
import { NarratorText, RepPop, ShadowText } from "../components/Text";
import { TitleCard } from "../components/TitleCard";
import { LookContext, LOOKS } from "../looks";
import { Voxel } from "../three/Voxel";
import { CameraRig, Phone3D, Room3D, Street3D } from "../three/World";
import { DayHud, REPS, T } from "./TestFilm";

/**
 * The same 10-second test film, rebuilt in real 3D with a block-game look.
 * Same story, timing and sound effects as TestFilm.
 */

const CL = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const ease = Easing.inOut(Easing.cubic);
const len = (k: keyof typeof T) => T[k][1] - T[k][0];

const HERO: [number, number, number] = [0.6, 0, 0.3];
const SHADOW: [number, number, number] = [-1.3, 0, -0.5];

const Canvas3D: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { width, height } = useVideoConfig();
  return (
    <ThreeCanvas width={width} height={height} shadows gl={{ antialias: true }}>
      {children}
    </ThreeCanvas>
  );
};

// --------------------------------------------------------------------------
const RoomShot: React.FC = () => {
  const f = useCurrentFrame();

  let s = 0;
  for (const [a, b] of REPS) {
    if (f >= a && f < b)
      s = 0.5 - 0.5 * Math.cos(((f - a) / (b - a)) * Math.PI * 2);
  }
  const breathe = 0.012 * Math.sin(f * 0.15);
  const worry = interpolate(f, [108, 135], [0, 1], { ...CL, easing: ease });
  const proud = interpolate(f, [94, 102], [0, 1], CL) * (1 - worry);
  const brow =
    interpolate(s, [0, 1], [0.45, 0.9]) * (1 - worry) -
    0.9 * worry -
    0.2 * proud;
  const mouth =
    interpolate(s, [0, 1], [0.15, -0.6]) * (1 - proud - worry) +
    0.8 * proud -
    0.8 * worry;
  const blink = Math.max(
    0,
    1 - Math.abs(f - 101) / 3,
    1 - Math.abs(f - 142) / 3,
  );

  const weakness = interpolate(f, [105, 150], [0.2, 0.7], CL);
  const emerge = interpolate(f, [105, 126], [0, 1], {
    ...CL,
    easing: Easing.out(Easing.back(1.4)),
  });

  // slow push-in on the emotional moment
  const push = interpolate(f, [108, 150], [0, 1], { ...CL, easing: ease });
  const cam: [number, number, number] = [
    0.1 - 0.4 * push,
    1.9,
    10 - 2.2 * push,
  ];
  const target: [number, number, number] = [
    -0.1 - 0.3 * push,
    1.3 + 0.25 * push,
    0,
  ];

  return (
    <AbsoluteFill>
      <Sfx name="hum" at={0} duration={len("room")} loop volume={0.35} />
      {REPS.map(([, b], i) => (
        <Sfx key={i} name="pop" at={b} volume={0.7} />
      ))}
      <Sfx name="drone" at={104} volume={0.9} />

      <Canvas3D>
        <CameraRig position={cam} target={target} />
        <Room3D />
        <Voxel
          position={SHADOW}
          variant="shadow"
          scale={1.2 * (1 + 0.35 * weakness)}
          emerge={emerge}
          visible={f >= 105}
          pose={{
            lean: 3 * Math.sin(f * 0.06),
            squash: 1 + 0.015 * Math.sin(f * 0.1),
            t: f,
          }}
        />
        {f >= 105 && (
          <pointLight
            color="#9B5CFF"
            intensity={6 * emerge}
            position={[SHADOW[0], 2, 0.6]}
            decay={1.5}
          />
        )}
        <Voxel
          position={HERO}
          pose={{
            squat: s * 0.95,
            squash: 1 - 0.07 * s + breathe - 0.03 * worry,
            lean: -4 * worry,
            brow,
            browLift: 0.6 * worry,
            mouth,
            blink,
            arms: "forward",
            armBlend: Math.min(1, s * 1.8),
            t: f,
          }}
        />
      </Canvas3D>

      <Sequence from={120} durationInFrames={30} layout="none">
        <ShadowText text="You'll quit tomorrow." x={40} y={470} width={520} />
      </Sequence>
      {REPS.map(([, b], i) => (
        <Sequence key={i} from={b} durationInFrames={26} layout="none">
          <RepPop text={`${i + 1}`} x={1180} y={360} size={90} />
        </Sequence>
      ))}
      <Sequence from={4} durationInFrames={96} layout="none">
        <NarratorText text="Day one. Just three squats." />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const PhoneShot: React.FC = () => {
  const f = useCurrentFrame();
  const buzz = (f >= 2 && f < 10) || (f >= 12 && f < 20) ? 1 : 0.15;
  return (
    <AbsoluteFill>
      <Sfx name="alarm" at={2} volume={0.6} />
      <Sfx name="alarm" at={12} volume={0.6} />
      <Canvas3D>
        <CameraRig position={[0.0, 3.4, 0.9]} target={[0, 0, 0]} fov={38} />
        <Phone3D buzz={buzz} />
      </Canvas3D>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const RunShot: React.FC = () => {
  const f = useCurrentFrame();
  const phase = f * 0.55;
  const steps = Array.from({ length: 6 }, (_, i) => 2 + i * 5);
  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.5} />
      {steps.map((at) => (
        <Sfx key={at} name="step" at={at} volume={0.7} />
      ))}
      <Canvas3D>
        <CameraRig position={[0, 2.2, 12.5]} target={[0, 2.1, 0]} />
        <Street3D scroll={f * 0.45 + 3} />
        <Voxel
          position={[0, 0, 0.5]}
          facing={Math.PI / 2 - 0.6}
          pose={{
            runPhase: phase,
            lift: Math.abs(Math.sin(phase)) * 0.08,
            squash: 1 + 0.04 * Math.cos(phase * 2),
            lean: 12,
            brow: 0.8,
            mouth: 0.1,
            arms: "run",
            armBlend: 1,
            headband: true,
            t: f,
          }}
        />
      </Canvas3D>
      <Sequence durationInFrames={30} layout="none">
        <NarratorText text="Every single morning." fadeFrames={6} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const RepShot: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const LAUNCH = 5;
  const LAND = 15;

  const crouch = interpolate(f, [0, LAUNCH], [0.1, 0.75], {
    ...CL,
    easing: ease,
  });
  const u = (f - LAUNCH) / (LAND - LAUNCH);
  const air = f >= LAUNCH && f < LAND;
  const lift = air ? 1.3 * 4 * u * (1 - u) : 0;
  const landS = spring({
    frame: f - LAND,
    fps,
    config: { damping: 8, stiffness: 300 },
  });

  let squat = crouch;
  let squash = 1 - 0.12 * (crouch / 0.75);
  if (air) {
    squat = 0.05;
    squash = interpolate(u, [0, 0.3, 1], [1.18, 1.02, 1.05]);
  } else if (f >= LAND) {
    squat = interpolate(landS, [0, 1], [0.55, 0.1]);
    squash = interpolate(landS, [0, 1], [0.84, 1]);
  }
  const shadowFade = interpolate(f, [0, 14], [1, 0], CL);

  return (
    <AbsoluteFill>
      <Sfx name="whoosh" at={0} volume={0.4} />
      <Sfx name="hit" at={LAUNCH} volume={1} />
      <Sfx name="pop" at={LAUNCH} volume={0.6} />
      <Sfx name="step" at={LAND} volume={1} rate={0.7} />

      <Canvas3D>
        <CameraRig position={[0.1, 1.9, 10.5]} target={[-0.1, 1.35, 0]} />
        <Room3D />
        <Voxel
          position={SHADOW}
          variant="shadow"
          scale={0.9 * (0.6 + 0.4 * shadowFade)}
          emerge={shadowFade}
          visible={shadowFade > 0.02}
          pose={{ t: f }}
        />
        <Voxel
          position={HERO}
          pose={{
            squat,
            lift,
            squash,
            brow: 1,
            mouth: air ? 0.9 : 0.2,
            arms: air ? "up" : "forward",
            armBlend: air ? 1 : crouch,
            headband: true,
            t: f,
          }}
        />
      </Canvas3D>

      <Sequence from={LAUNCH} durationInFrames={10} layout="none">
        <SpeedLines cx={1000} cy={520} />
      </Sequence>
      <Sequence from={LAUNCH} durationInFrames={4} layout="none">
        <Flash />
      </Sequence>
      <Sequence from={LAUNCH} durationInFrames={15} layout="none">
        <RepPop text="50!" x={1260} y={300} size={130} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
export const TestFilm3D: React.FC = () => (
  <LookContext.Provider value={LOOKS.blocky}>
    <AbsoluteFill style={{ background: "#000" }}>
      <LookDefs />
      <Sequence from={T.room[0]} durationInFrames={len("room")} name="Room">
        <RoomShot />
      </Sequence>
      <Sequence
        from={T.phone[0]}
        durationInFrames={len("phone")}
        name="Phone close-up"
      >
        <PhoneShot />
      </Sequence>
      <Sequence from={T.run[0]} durationInFrames={len("run")} name="Run">
        <RunShot />
      </Sequence>
      <Sequence from={T.rep[0]} durationInFrames={len("rep")} name="Big rep">
        <RepShot />
      </Sequence>
      <Sequence
        from={T.title[0]}
        durationInFrames={len("title")}
        name="Title card"
      >
        <TitleCard
          word="BEGIN"
          line1="Every day starts with one rep."
          line2="Day 1."
          startAt={3}
          letterEvery={4}
          underlineFrames={12}
          line1At={36}
          line2At={46}
          fadeFrames={16}
        />
      </Sequence>
      <DayHud />
      <Letterbox />
    </AbsoluteFill>
  </LookContext.Provider>
);
