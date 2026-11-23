import React from "react";
import { Composition } from "remotion";
import { TestFilm } from "./films/TestFilm";
import { TestFilm3D } from "./films/TestFilm3D";
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
