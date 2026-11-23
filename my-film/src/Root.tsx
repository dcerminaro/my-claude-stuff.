import React from "react";
import { Composition } from "remotion";
import { TestFilm } from "./films/TestFilm";
import { FPS, H, W } from "./theme";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition id="TestFilm" component={TestFilm} durationInFrames={300} fps={FPS} width={W} height={H} />
    </>
  );
};
