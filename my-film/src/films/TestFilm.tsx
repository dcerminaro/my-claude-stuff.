import React from "react";
import { AbsoluteFill, interpolate, Sequence, spring, useCurrentFrame, useVideoConfig, Easing } from "remotion";
import { Flash, SpeedLines } from "../components/Effects";
import { Figure } from "../components/Figure";
import { Glow } from "../components/Glow";
import { Letterbox } from "../components/Letterbox";
import { City, PhoneCloseUp, Room } from "../components/Sets";
import { Sfx } from "../components/Sfx";
import { DayCounter, NarratorText, RepPop, ShadowText } from "../components/Text";
import { TitleCard } from "../components/TitleCard";
import { C, FLOOR_Y, H, W } from "../theme";

/**
 * 10-second test film (300 frames). A compressed version of the channel
 * format: calm opening, shadow appears, 1-second montage, mini title card.
 */

const CL = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const ease = Easing.inOut(Easing.cubic);

// ---- shot timings (global frames) ----
const T = {
  room: [0, 150],
  phone: [150, 175],
  run: [175, 205],
  rep: [205, 225],
  title: [225, 300],
} as const;
const len = (k: keyof typeof T) => T[k][1] - T[k][0];

const REPS = [
  [10, 38],
  [38, 66],
  [66, 94],
] as const;

const HERO_X = 880;
const SHADOW_X = 650;

// --------------------------------------------------------------------------
const RoomShot: React.FC = () => {
  const f = useCurrentFrame();

  // squat reps
  let s = 0;
  for (const [a, b] of REPS) {
    if (f >= a && f < b) s = 0.5 - 0.5 * Math.cos(((f - a) / (b - a)) * Math.PI * 2);
  }
  const breathe = 0.012 * Math.sin(f * 0.15);

  // emotion: effort → proud → worried when the shadow arrives
  const worry = interpolate(f, [108, 135], [0, 1], { ...CL, easing: ease });
  const proud = interpolate(f, [94, 102], [0, 1], CL) * (1 - worry);
  const brow = interpolate(s, [0, 1], [0.45, 0.9]) * (1 - worry) - 0.9 * worry - 0.2 * proud;
  const mouth = interpolate(s, [0, 1], [0.15, -0.35]) * (1 - proud - worry) + 0.6 * proud - 0.55 * worry;
  const blink = Math.max(0, 1 - Math.abs(f - 101) / 3, 1 - Math.abs(f - 142) / 3);

  // shadow rises out of the floor; it grows as he weakens
  const weakness = interpolate(f, [105, 150], [0.2, 0.7], CL);
  const emerge = interpolate(f, [105, 126], [0, 1], { ...CL, easing: Easing.out(Easing.back(1.4)) });

  // slow push-in on the emotional moment
  const push = interpolate(f, [108, 150], [1, 1.08], { ...CL, easing: ease });

  return (
    <AbsoluteFill>
      <Sfx name="hum" at={0} duration={len("room")} loop volume={0.35} />
      {REPS.map(([, b], i) => (
        <Sfx key={i} name="pop" at={b} volume={0.7} />
      ))}
      <Sfx name="drone" at={104} volume={0.9} />

      <AbsoluteFill style={{ transform: `scale(${push})`, transformOrigin: "760px 600px" }}>
        <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`}>
          <Room />
          {f >= 105 && (
            <Figure
              x={SHADOW_X}
              y={FLOOR_Y}
              scale={1.2 * (1 + 0.35 * weakness)}
              variant="shadow"
              emerge={emerge}
              pose={{ lean: 3 * Math.sin(f * 0.06), squash: 1 + 0.015 * Math.sin(f * 0.1), t: f }}
            />
          )}
          <Figure
            x={HERO_X}
            y={FLOOR_Y}
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
          {/* the lamp's light washes over him */}
          <Glow x={470} y={560} r={900} color={C.warmLight} opacity={0.1} />
        </svg>

        <Sequence from={120} durationInFrames={30} layout="none">
          <ShadowText text="You'll quit tomorrow." x={150} y={300} />
        </Sequence>
      </AbsoluteFill>

      {REPS.map(([, b], i) => (
        <Sequence key={i} from={b} durationInFrames={26} layout="none">
          <RepPop text={`${i + 1}`} x={HERO_X + 150} y={520} />
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
      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`}>
        <PhoneCloseUp buzz={buzz} time="5:00" label="DAY 2" />
      </svg>
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
      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`}>
        <City scroll={f * 26 + 300} />
        <Figure
          x={860}
          y={FLOOR_Y}
          pose={{
            runPhase: phase,
            lift: Math.abs(Math.sin(phase)) * 10,
            squash: 1 + 0.05 * Math.cos(phase * 2),
            lean: 10,
            brow: 0.7,
            mouth: 0.1,
            arms: "run",
            armBlend: 1,
            headband: true,
            t: f,
          }}
        />
      </svg>
      <Sequence  durationInFrames={30} layout="none">
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

  const crouch = interpolate(f, [0, LAUNCH], [0.1, 0.75], { ...CL, easing: ease });
  const u = (f - LAUNCH) / (LAND - LAUNCH);
  const air = f >= LAUNCH && f < LAND;
  const lift = air ? 150 * 4 * u * (1 - u) : 0;
  const landS = spring({ frame: f - LAND, fps, config: { damping: 8, stiffness: 300 } });

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

      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`}>
        <Room />
        <Figure
          x={SHADOW_X}
          y={FLOOR_Y}
          scale={0.9 * (0.6 + 0.4 * shadowFade)}
          variant="shadow"
          opacity={shadowFade}
          eyeGlow={shadowFade}
          pose={{ t: f }}
        />
        <Figure
          x={HERO_X}
          y={FLOOR_Y}
          pose={{
            squat,
            lift,
            squash,
            brow: 1,
            mouth: air ? 0.7 : 0.2,
            arms: air ? "up" : "forward",
            armBlend: air ? 1 : crouch,
            headband: true,
            t: f,
          }}
        />
        <Glow x={470} y={560} r={900} color={C.warmLight} opacity={0.1} />
      </svg>

      <Sequence from={LAUNCH} durationInFrames={10} layout="none">
        <SpeedLines cx={HERO_X} cy={620} />
      </Sequence>
      <Sequence from={LAUNCH} durationInFrames={4} layout="none">
        <Flash />
      </Sequence>
      <Sequence from={LAUNCH} durationInFrames={15} layout="none">
        <RepPop text="50!" x={HERO_X + 190} y={400} size={120} />
      </Sequence>
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------
const dayAt = (frame: number) => {
  if (frame < T.phone[0]) return 1;
  if (frame < T.run[0]) return 2;
  if (frame < T.rep[0]) return Math.round(interpolate(frame, [T.run[0] + 2, T.run[1] - 4], [2, 30], CL));
  return 30;
};

const DayHud: React.FC = () => {
  const f = useCurrentFrame();
  if (f >= T.title[0]) return null;
  const day = dayAt(f);
  let since = 0;
  while (f - since > 0 && dayAt(f - since - 1) === day) since++;
  return <DayCounter day={day} since={day === 1 ? 30 : since} />;
};

export const TestFilm: React.FC = () => (
  <AbsoluteFill style={{ background: "#000" }}>
    <Sequence from={T.room[0]} durationInFrames={len("room")} name="Room">
      <RoomShot />
    </Sequence>
    <Sequence from={T.phone[0]} durationInFrames={len("phone")} name="Phone close-up">
      <PhoneShot />
    </Sequence>
    <Sequence from={T.run[0]} durationInFrames={len("run")} name="Run">
      <RunShot />
    </Sequence>
    <Sequence from={T.rep[0]} durationInFrames={len("rep")} name="Big rep">
      <RepShot />
    </Sequence>
    <Sequence from={T.title[0]} durationInFrames={len("title")} name="Title card">
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
);
