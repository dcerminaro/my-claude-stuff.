import React from "react";
import * as THREE from "three";
import { useCurrentFrame } from "remotion";
import {
  booksTex,
  clockTex,
  creamWallTex,
  deskTex,
  lightPlanksTex,
  noiseTex,
  numeralStripTex,
  piePosterTex,
  skyTex,
  spqrTex,
  wainscotTex,
} from "./textures";
import { Glow3D } from "./World";

/**
 * Caesar's classroom: a bright, daytime classroom built from blocks.
 * Cream walls over wooden panelling, a wood floor, ceiling lights, sunlight
 * from a window on the left, a chalkboard with a Roman-numeral strip,
 * a clock, an SPQR banner, a pie-chart poster, a marble bust, a bookshelf.
 *
 * Laid out for a vertical (9:16) frame: everything important sits within
 * about 2.5 blocks of the centre line (x = 0).
 */
export const BOARD = { x: 0, y: 2.75, z: -2.94, w: 4.0, h: 2.0 };
export const DESK = { x: 0, z: -0.2, h: 1.05 };
export const CAESAR_SPOT: [number, number, number] = [0, 0, -1.05];
export const STUDENT_SPOT: [number, number, number] = [1.3, 0, 1.8];
const WALL_Z = -3;
const CEIL = 5.4;

const B: React.FC<{
  size: [number, number, number];
  position: [number, number, number];
  rotation?: [number, number, number];
  color?: string;
  map?: THREE.Texture;
  noise?: number;
  emissive?: boolean;
}> = ({
  size,
  position,
  rotation,
  color = "#555",
  map,
  noise = 0.08,
  emissive,
}) => (
  <mesh position={position} rotation={rotation} castShadow receiveShadow>
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

/** a flat picture on the wall */
const WallPic: React.FC<{
  map: THREE.Texture;
  position: [number, number, number];
  size: [number, number];
}> = ({ map, position, size }) => (
  <mesh position={position} receiveShadow>
    <planeGeometry args={size} />
    <meshLambertMaterial map={map} />
  </mesh>
);

export const Desk: React.FC<{
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
        color="#5A5A64"
      />
    ))}
  </group>
);

/** a pupil's desk with its chair behind it (the chair back faces +z) */
const DeskAndChair: React.FC<{ x: number; z: number }> = ({ x, z }) => (
  <group>
    <Desk position={[x, 0, z - 0.7]} w={0.95} d={0.7} h={0.8} />
    <group position={[x, 0, z + 0.05]}>
      <B size={[0.55, 0.08, 0.55]} position={[0, 0.44, 0]} color="#3A6EA5" />
      <B size={[0.55, 0.6, 0.08]} position={[0, 0.78, 0.26]} color="#3A6EA5" />
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
          color="#5A5A64"
        />
      ))}
    </group>
  </group>
);

export const Classroom: React.FC<{
  board: THREE.Texture;
  coins?: boolean; // the coin stack on Caesar's desk (hide it when a lesson brings its own props)
}> = ({ board, coins = true }) => {
  const frame = useCurrentFrame();
  const seconds = frame / 30;

  return (
    <group>
      <color attach="background" args={["#BFD8EE"]} />

      {/* daylight: soft ambient, sky/ground bounce, sun through the window */}
      <ambientLight color="#FFF3E0" intensity={0.75} />
      <hemisphereLight color="#E3EEFF" groundColor="#8A6A4A" intensity={0.8} />
      <directionalLight
        color="#FFE9C4"
        intensity={2.0}
        position={[-6, 7, 5]}
        castShadow
        shadow-mapSize-width={1024}
        shadow-mapSize-height={1024}
        shadow-camera-left={-6}
        shadow-camera-right={6}
        shadow-camera-top={6}
        shadow-camera-bottom={-6}
        shadow-bias={-0.0015}
      />
      <pointLight
        color="#FFF6E8"
        intensity={8}
        position={[0, CEIL - 0.4, -0.5]}
        decay={1.5}
      />

      {/* floor */}
      <mesh
        rotation={[-Math.PI / 2, 0, 0]}
        position={[0, 0, 2.2]}
        receiveShadow
      >
        <planeGeometry args={[10, 10.6]} />
        <meshLambertMaterial map={lightPlanksTex([10, 11])} />
      </mesh>
      {/* sun patches on the floor */}
      <Glow3D
        position={[-1.6, 0.02, 1.2]}
        size={3.2}
        color="#FFE6B0"
        opacity={0.35}
        flat
      />
      <Glow3D
        position={[0.4, 0.02, 2.6]}
        size={3}
        color="#FFE6B0"
        opacity={0.3}
        flat
      />

      {/* back wall: cream plaster over wooden panelling */}
      <mesh position={[0, 3.2, WALL_Z]} receiveShadow>
        <planeGeometry args={[7.2, 4.4]} />
        <meshLambertMaterial map={creamWallTex([7, 4])} />
      </mesh>
      <mesh position={[0, 0.5, WALL_Z + 0.01]} receiveShadow>
        <planeGeometry args={[7.2, 1.0]} />
        <meshLambertMaterial map={wainscotTex([7, 1])} />
      </mesh>
      <B
        size={[7.2, 0.08, 0.08]}
        position={[0, 1.02, WALL_Z + 0.04]}
        color="#6E4826"
      />

      {/* side walls; the left one has a window with sky */}
      <mesh
        position={[-3.6, 2.7, 2.2]}
        rotation={[0, Math.PI / 2, 0]}
        receiveShadow
      >
        <planeGeometry args={[10.4, 5.4]} />
        <meshLambertMaterial map={creamWallTex([10, 5])} />
      </mesh>
      <mesh position={[-3.58, 2.9, 0.2]} rotation={[0, Math.PI / 2, 0]}>
        <planeGeometry args={[2.2, 2]} />
        <meshBasicMaterial map={skyTex()} toneMapped={false} />
      </mesh>
      <mesh
        position={[3.6, 2.7, 2.2]}
        rotation={[0, -Math.PI / 2, 0]}
        receiveShadow
      >
        <planeGeometry args={[10.4, 5.4]} />
        <meshLambertMaterial map={creamWallTex([10, 5])} />
      </mesh>

      {/* ceiling with two light panels */}
      <mesh position={[0, CEIL, 2.2]} rotation={[Math.PI / 2, 0, 0]}>
        <planeGeometry args={[7.2, 10.4]} />
        <meshLambertMaterial color="#EDE7DA" />
      </mesh>
      {[-1.6, 1.2].map((z) => (
        <group key={z}>
          <B
            size={[1.6, 0.06, 0.5]}
            position={[0, CEIL - 0.03, z]}
            color="#FFFDF4"
            noise={0.02}
            emissive
          />
          <Glow3D
            position={[0, CEIL - 0.25, z + 0.3]}
            size={2.4}
            color="#FFF6E0"
            opacity={0.25}
          />
        </group>
      ))}

      {/* chalkboard, frame, tray, chalk */}
      <group position={[BOARD.x, BOARD.y, BOARD.z]}>
        <mesh position={[0, 0, 0.02]} receiveShadow>
          <planeGeometry args={[BOARD.w, BOARD.h]} />
          <meshLambertMaterial map={board} />
        </mesh>
        <B
          size={[BOARD.w + 0.3, 0.15, 0.12]}
          position={[0, BOARD.h / 2 + 0.07, 0.03]}
          color="#7A5530"
        />
        <B
          size={[BOARD.w + 0.3, 0.15, 0.12]}
          position={[0, -BOARD.h / 2 - 0.07, 0.03]}
          color="#7A5530"
        />
        <B
          size={[0.15, BOARD.h + 0.3, 0.12]}
          position={[-BOARD.w / 2 - 0.07, 0, 0.03]}
          color="#7A5530"
        />
        <B
          size={[0.15, BOARD.h + 0.3, 0.12]}
          position={[BOARD.w / 2 + 0.07, 0, 0.03]}
          color="#7A5530"
        />
        <B
          size={[BOARD.w, 0.08, 0.25]}
          position={[0, -BOARD.h / 2 - 0.16, 0.12]}
          color="#7A5530"
        />
        <B
          size={[0.22, 0.06, 0.06]}
          position={[1.2, -BOARD.h / 2 - 0.09, 0.15]}
          color="#F4F4EE"
        />
        <B
          size={[0.3, 0.1, 0.12]}
          position={[-1.3, -BOARD.h / 2 - 0.07, 0.15]}
          color="#3A3A44"
        />
        {/* Roman-numeral strip above the board */}
        <WallPic
          map={numeralStripTex()}
          position={[0, BOARD.h / 2 + 0.45, 0.02]}
          size={[BOARD.w, BOARD.w * (11 / 128)]}
        />
      </group>

      {/* clock with moving hands */}
      <group position={[-2.55, 4.35, WALL_Z + 0.03]}>
        <WallPic map={clockTex()} position={[0, 0, 0]} size={[0.75, 0.75]} />
        <mesh
          position={[0, 0, 0.02]}
          rotation={[0, 0, -(seconds / 60) * Math.PI * 2]}
        >
          <boxGeometry args={[0.025, 0.3, 0.01]} />
          <meshBasicMaterial color="#B3262E" />
        </mesh>
        <mesh
          position={[0, 0, 0.015]}
          rotation={[0, 0, -2.1 - seconds * 0.002]}
        >
          <boxGeometry args={[0.05, 0.22, 0.01]} />
          <meshBasicMaterial color="#2B2B33" />
        </mesh>
      </group>

      {/* posters */}
      <WallPic
        map={piePosterTex()}
        position={[-2.65, 2.75, WALL_Z + 0.02]}
        size={[0.8, 1.07]}
      />
      <WallPic
        map={spqrTex()}
        position={[2.7, 3.15, WALL_Z + 0.02]}
        size={[0.85, 1.28]}
      />

      {/* marble bust on a pedestal */}
      <group position={[-2.55, 0, -2.45]}>
        <B
          size={[0.6, 1.05, 0.6]}
          position={[0, 0.525, 0]}
          color="#D9D4CA"
          noise={0.06}
        />
        <B size={[0.7, 0.08, 0.7]} position={[0, 1.09, 0]} color="#CFC9BE" />
        <B
          size={[0.5, 0.28, 0.32]}
          position={[0, 1.27, 0]}
          color="#E6E2DA"
          noise={0.05}
        />
        <B
          size={[0.42, 0.44, 0.42]}
          position={[0, 1.63, 0]}
          color="#ECE8E0"
          noise={0.05}
        />
        <B
          size={[0.08, 0.12, 0.08]}
          position={[0, 1.6, 0.24]}
          color="#E6E2DA"
        />
        {[-0.22, 0.22].map((x) => (
          <B
            key={x}
            size={[0.06, 0.08, 0.36]}
            position={[x, 1.78, -0.02]}
            color="#9CB04A"
          />
        ))}
      </group>

      {/* bookshelf with a plant on top */}
      <group position={[2.55, 0, -2.6]}>
        <B size={[1.1, 1.7, 0.4]} position={[0, 0.85, 0]} color="#7A5530" />
        {[0.35, 0.9, 1.42].map((y) => (
          <mesh key={y} position={[0, y, 0.15]}>
            <boxGeometry args={[0.95, 0.42, 0.12]} />
            <meshLambertMaterial map={booksTex()} />
          </mesh>
        ))}
        <B size={[0.32, 0.3, 0.32]} position={[0.2, 1.85, 0]} color="#B8643A" />
        {[
          [0.2, 2.15, 0],
          [0.08, 2.05, 0.08],
          [0.32, 2.08, -0.06],
          [0.2, 2.3, 0.05],
        ].map((p, i) => (
          <B
            key={i}
            size={[0.2, 0.2, 0.2]}
            position={p as [number, number, number]}
            color="#4E8A4A"
            noise={0.15}
          />
        ))}
      </group>

      {/* Caesar's desk: coins, an apple, a scroll */}
      <Desk position={[DESK.x, 0, DESK.z]} w={2.0} d={0.95} h={DESK.h} />
      <B
        size={[2.0, 0.7, 0.06]}
        position={[DESK.x, 0.62, DESK.z + 0.44]}
        color="#8A5A32"
      />
      {(coins ? [0, 1, 2, 3] : []).map((i) => (
        <B
          key={i}
          size={[0.22, 0.05, 0.22]}
          position={[DESK.x + 0.65, DESK.h + 0.085 + i * 0.05, DESK.z + 0.1]}
          color="#E8C04A"
          noise={0.12}
        />
      ))}
      <B
        size={[0.24, 0.24, 0.24]}
        position={[DESK.x - 0.7, DESK.h + 0.18, DESK.z + 0.15]}
        color="#C8302E"
        noise={0.1}
      />
      <B
        size={[0.04, 0.1, 0.04]}
        position={[DESK.x - 0.7, DESK.h + 0.35, DESK.z + 0.15]}
        color="#5A3A1A"
      />
      <B
        size={[0.12, 0.04, 0.08]}
        position={[DESK.x - 0.64, DESK.h + 0.38, DESK.z + 0.15]}
        color="#4E8A4A"
      />
      <B
        size={[0.5, 0.1, 0.1]}
        position={[DESK.x + 0.05, DESK.h + 0.11, DESK.z + 0.25]}
        color="#E6D7B0"
      />

      {/* back of the room (seen when the camera faces the student) */}
      <mesh position={[0, 3.2, 7.4]} rotation={[0, Math.PI, 0]} receiveShadow>
        <planeGeometry args={[7.2, 4.4]} />
        <meshLambertMaterial map={creamWallTex([7, 4])} />
      </mesh>
      <mesh position={[0, 0.5, 7.39]} rotation={[0, Math.PI, 0]} receiveShadow>
        <planeGeometry args={[7.2, 1.0]} />
        <meshLambertMaterial map={wainscotTex([7, 1])} />
      </mesh>
      {/* cork notice board with pinned papers */}
      <group position={[0.6, 2.6, 7.35]}>
        <B
          size={[2.4, 1.4, 0.06]}
          position={[0, 0, 0]}
          color="#B98A58"
          noise={0.18}
        />
        {[
          [-0.8, 0.3, "#F4EEDC"],
          [-0.3, -0.2, "#F2D36B"],
          [0.3, 0.25, "#F4EEDC"],
          [0.8, -0.15, "#9FD3A8"],
          [0.05, -0.35, "#F4B6B6"],
        ].map(([x, y, c], i) => (
          <B
            key={i}
            size={[0.42, 0.5, 0.02]}
            position={[x as number, y as number, -0.04]}
            color={c as string}
            noise={0.03}
          />
        ))}
      </group>
      <B size={[1.0, 2.2, 0.08]} position={[-2.4, 1.1, 7.35]} color="#8A5A32" />
      <B
        size={[0.08, 0.08, 0.12]}
        position={[-2.05, 1.1, 7.28]}
        color="#D8B448"
      />

      {/* pupils' desks: our student's, plus empty ones */}
      <DeskAndChair x={STUDENT_SPOT[0]} z={STUDENT_SPOT[2]} />
      <DeskAndChair x={-1.25} z={1.8} />
      <DeskAndChair x={-1.25} z={3.6} />
      <DeskAndChair x={STUDENT_SPOT[0]} z={3.6} />
    </group>
  );
};
