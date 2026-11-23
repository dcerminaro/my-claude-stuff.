import React from "react";
import { Composition } from "remotion";
import { TestFilm } from "./films/TestFilm";
import { TestFilm3D } from "./films/TestFilm3D";
import { CAESAR_TEST_DURATION, CaesarTest } from "./films/CaesarTest";
import { LESSON_02_DURATION, Lesson02 } from "./films/Lesson02";
import { LookName } from "./looks";
import { FPS, H, W } from "./theme";

const STYLES: { id: string; look: LookName }[] = [
  { id: "TestFilm", look: "original" },
  { id: "TestFilm-Blocky", look: "blocky" },
  { id: "TestFilm-Neon", look: "neon" },
  { id: "TestFilm-Paper", look: "paper" },
  { id: "TestFilm-Ink", look: "ink" },
  { id: "TestFilm-Clay", look: "clay" },
];

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {STYLES.map((s) => (
        <Composition
          key={s.id}
          id={s.id}
          component={TestFilm}
          defaultProps={{ look: s.look }}
          durationInFrames={300}
          fps={FPS}
          width={W}
          height={H}
        />
      ))}
      <Composition
        id="Lesson02"
        component={Lesson02}
        durationInFrames={LESSON_02_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
      />
      <Composition
        id="CaesarTest"
        component={CaesarTest}
        durationInFrames={CAESAR_TEST_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
      />
      <Composition
        id="TestFilm-3D-Blocks"
        component={TestFilm3D}
        durationInFrames={300}
        fps={FPS}
        width={W}
        height={H}
      />
    </>
  );
};
