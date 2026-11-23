import React from "react";
import * as THREE from "three";
import { useCurrentFrame } from "remotion";
import { classWallTex, deskTex, noiseTex, tileFloorTex } from "./textures";
import { Glow3D } from "./World";

/**
 * Caesar's dark classroom, built from blocks.
 *
 * Layout (1 unit = 1 block):
 *  - back wall at z = -3, chalkboard centred at x = BOARD.x
 *  - Caesar's desk at x = DESK.x, z = DESK.z; Caesar stands behind it
 *  - the student's desk in the front row at STUDENT
 *  - window with the moon on the right of the back wall
 */
export const BOARD = { x: -0.3, y: 2.55, z: -2.94, w: 5.2, h: 2.6 };
export const DESK = { x: -1.3, z: 0.1, h: 1.05 };
export const CAESAR_SPOT: [number, number, number] = [-1.3, 0, -0.85];
export const STUDENT_SPOT: [number, number, number] = [2.9, 0, 1.9];

const B: React.FC<{
  size: [number, number, number];
  position: [number, number, number];
  color?: string;
  map?: THREE.Texture;
  noise?: number;
  emissive?: boolean;
}> = ({ size, position, color = "#555", map, noise = 0.08, emissive }) => (
  <mesh position={position} castShadow receiveShadow>
    <boxGeometry args={size} />
    {emissive ? (
      <meshBasicMaterial
        map={map ?? noiseTex(color, noise, 8)}
        toneMapped={false}
      />
    ) : (
      <meshLambertMaterial map={map ?? noiseTex(color, noise, 8)} />
    )}
  </mesh>
);

const Desk: React.FC<{
  position: [number, number, number];
  w: number;
  d: number;
  h: number;
}> = ({ position, w, d, h }) => (
  <group position={position}>
    <B size={[w, 0.12, d]} position={[0, h, 0]} map={deskTex()} />
    {[
      [-1, -1],
      [1, -1],
      [-1, 1],
      [1, 1],
    ].map(([sx, sz], i) => (
      <B
        key={i}
        size={[0.1, h, 0.1]}
        position={[sx * (w / 2 - 0.1), h / 2, sz * (d / 2 - 0.1)]}
        color="#4A3020"
      />
    ))}
  </group>
);

export const Classroom: React.FC<{ board: THREE.Texture; dim?: number }> = ({
  board,
  dim = 1,
}) => {
  const frame = useCurrentFrame();
  const flicker = 1 + 0.05 * Math.sin(frame * 0.9) * Math.sin(frame * 0.37);

  return (
    <group>
      <color attach="background" args={["#0A0C14"]} />
      <ambientLight color="#5566AA" intensity={0.4 * dim} />
      <hemisphereLight
        color="#8FA0D0"
        groundColor="#2A2020"
        intensity={0.25 * dim}
      />
      <directionalLight
        color="#9DB4FF"
        intensity={0.35 * dim}
        position={[6, 6, 5]}
      />

      {/* board lamp: the main light, casts the shadows */}
      <spotLight
        color="#FFD9A0"
        intensity={70 * flicker * dim}
        position={[BOARD.x, 4.6, -1.6]}
        angle={0.85}
        penumbra={0.7}
        decay={1.5}
        distance={0}
        castShadow
        shadow-mapSize-width={1024}
        shadow-mapSize-height={1024}
        shadow-bias={-0.002}
      >
        <object3D attach="target" position={[BOARD.x - 0.4, 0.6, 0]} />
      </spotLight>

      {/* desk lamp on Caesar's desk */}
      <pointLight
        color="#FFB765"
        intensity={7 * flicker * dim}
        position={[DESK.x - 1.0, DESK.h + 0.8, DESK.z + 0.4]}
        decay={1.6}
        distance={0}
      />

      {/* floor and walls */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[24, 12]} />
        <meshLambertMaterial map={tileFloorTex([24, 12])} />
      </mesh>
      <mesh position={[0, 4, -3]} receiveShadow>
        <planeGeometry args={[24, 8]} />
        <meshLambertMaterial map={classWallTex([24, 8])} />
      </mesh>
      {/* skirting board */}
      <B size={[24, 0.3, 0.08]} position={[0, 0.15, -2.96]} color="#1E2E2E" />

      {/* chalkboard with wooden frame and chalk tray */}
      <group position={[BOARD.x, BOARD.y, BOARD.z]}>
        <mesh position={[0, 0, 0.02]} receiveShadow>
          <planeGeometry args={[BOARD.w, BOARD.h]} />
          <meshLambertMaterial map={board} />
        </mesh>
        <B
          size={[BOARD.w + 0.3, 0.15, 0.12]}
          position={[0, BOARD.h / 2 + 0.07, 0.03]}
          color="#5A3A22"
        />
        <B
          size={[BOARD.w + 0.3, 0.15, 0.12]}
          position={[0, -BOARD.h / 2 - 0.07, 0.03]}
          color="#5A3A22"
        />
        <B
          size={[0.15, BOARD.h + 0.3, 0.12]}
          position={[-BOARD.w / 2 - 0.07, 0, 0.03]}
          color="#5A3A22"
        />
        <B
          size={[0.15, BOARD.h + 0.3, 0.12]}
          position={[BOARD.w / 2 + 0.07, 0, 0.03]}
          color="#5A3A22"
        />
        <B
          size={[BOARD.w, 0.08, 0.25]}
          position={[0, -BOARD.h / 2 - 0.16, 0.12]}
          color="#5A3A22"
        />
        <B
          size={[0.22, 0.06, 0.06]}
          position={[1.2, -BOARD.h / 2 - 0.09, 0.15]}
          color="#EDEDE4"
        />
        {/* lamp above the board */}
        <B
          size={[1.4, 0.16, 0.3]}
          position={[0, BOARD.h / 2 + 0.45, 0.4]}
          color="#2A2A30"
        />
        <B
          size={[1.2, 0.06, 0.22]}
          position={[0, BOARD.h / 2 + 0.36, 0.42]}
          color="#FFE7B8"
          emissive
        />
        <Glow3D
          position={[0, BOARD.h / 2 + 0.3, 0.6]}
          size={4.5}
          color="#FFD9A0"
          opacity={0.45 * flicker * dim}
        />
      </group>

      {/* window with the moon */}
      <group position={[4.9, 2.9, -2.95]}>
        <mesh>
          <planeGeometry args={[1.8, 2]} />
          <meshBasicMaterial color="#141B33" />
        </mesh>
        <B
          size={[0.5, 0.5, 0.1]}
          position={[0.35, 0.45, 0.05]}
          color="#EEEBD8"
          noise={0.06}
          emissive
        />
        <Glow3D
          position={[0.35, 0.45, 0.2]}
          size={2.2}
          color="#CFDBFF"
          opacity={0.45 * dim}
        />
        <B size={[2, 0.14, 0.18]} position={[0, 1.04, 0.08]} color="#3A2A1E" />
        <B size={[2, 0.18, 0.28]} position={[0, -1.04, 0.12]} color="#3A2A1E" />
        <B size={[0.14, 2, 0.18]} position={[-0.95, 0, 0.08]} color="#3A2A1E" />
        <B size={[0.14, 2, 0.18]} position={[0.95, 0, 0.08]} color="#3A2A1E" />
        <B size={[0.08, 2, 0.1]} position={[0, 0, 0.06]} color="#3A2A1E" />
      </group>

      {/* Caesar's desk with a lamp, coins and a scroll */}
      <Desk position={[DESK.x, 0, DESK.z]} w={2.4} d={1.0} h={DESK.h} />
      <group position={[DESK.x - 1.0, DESK.h + 0.06, DESK.z + 0.1]}>
        <B size={[0.3, 0.06, 0.3]} position={[0, 0.03, 0]} color="#2A2A30" />
        <B size={[0.06, 0.5, 0.06]} position={[0, 0.3, 0]} color="#2A2A30" />
        <B
          size={[0.36, 0.22, 0.36]}
          position={[0, 0.62, 0]}
          color="#E0904A"
          emissive
        />
        <Glow3D
          position={[0, 0.58, 0.3]}
          size={2.6}
          color="#FFB765"
          opacity={0.5 * flicker * dim}
        />
      </group>
      {[0, 1, 2, 3].map((i) => (
        <B
          key={i}
          size={[0.22, 0.05, 0.22]}
          position={[DESK.x + 0.55, DESK.h + 0.085 + i * 0.05, DESK.z + 0.1]}
          color="#E8C04A"
          noise={0.12}
        />
      ))}
      <B
        size={[0.5, 0.1, 0.1]}
        position={[DESK.x + 0.05, DESK.h + 0.11, DESK.z + 0.25]}
        color="#E6D7B0"
      />
      <Glow3D
        position={[DESK.x, 0.02, DESK.z + 0.8]}
        size={4}
        color="#FFB765"
        opacity={0.25 * dim}
        flat
      />

      {/* the student's desk and chair in the front row */}
      <Desk
        position={[STUDENT_SPOT[0] - 0.75, 0, STUDENT_SPOT[2]]}
        w={0.9}
        d={0.9}
        h={0.8}
      />
      <group position={[STUDENT_SPOT[0] + 0.05, 0, STUDENT_SPOT[2]]}>
        <B size={[0.55, 0.08, 0.55]} position={[0, 0.44, 0]} color="#5A3A22" />
        <B
          size={[0.08, 0.7, 0.55]}
          position={[0.26, 0.78, 0]}
          color="#5A3A22"
        />
        {[
          [-1, -1],
          [1, -1],
          [-1, 1],
          [1, 1],
        ].map(([sx, sz], i) => (
          <B
            key={i}
            size={[0.06, 0.44, 0.06]}
            position={[sx * 0.22, 0.22, sz * 0.22]}
            color="#3A2A1E"
          />
        ))}
      </group>
    </group>
  );
};
