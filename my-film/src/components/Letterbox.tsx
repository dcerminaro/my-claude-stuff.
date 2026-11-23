import React from "react";
import { AbsoluteFill } from "remotion";
import { BAR } from "../theme";

export const Letterbox: React.FC = () => (
  <AbsoluteFill style={{ pointerEvents: "none" }}>
    <div
      style={{
        position: "absolute",
        top: 0,
        left: 0,
        right: 0,
        height: BAR,
        background: "#000",
      }}
    />
    <div
      style={{
        position: "absolute",
        bottom: 0,
        left: 0,
        right: 0,
        height: BAR,
        background: "#000",
      }}
    />
  </AbsoluteFill>
);
