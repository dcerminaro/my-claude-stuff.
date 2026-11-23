import React, { useLayoutEffect } from "react";
import { useThree } from "@react-three/fiber";
import * as THREE from "three";
import { random, useCurrentFrame } from "remotion";
import {
  facadeTex,
  glowTex,
  noiseTex,
  phoneScreenTex,
  planksTex,
  roadTex,
  sidewalkTex,
  wallTex,
} from "./textures";

/** Locked camera; position/target can be animated per frame (push-ins). */
export const CameraRig: React.FC<{
  position: [number, number, number];
  target: [number, number, number];
  fov?: number;
}> = ({ position, target, fov = 34 }) => {
  const camera = useThree((s) => s.camera) as THREE.PerspectiveCamera;
  useLayoutEffect(() => {
    camera.position.set(...position);
    camera.fov = fov;
    camera.near = 0.1;
    camera.far = 200;
    camera.lookAt(...target);
    camera.updateProjectionMatrix();
  }, [camera, position, target, fov]);
  return null;
};

/** Additive light halo, facing the camera. */
export const Glow3D: React.FC<{
  position: [number, number, number];
  size: number;
  color: string;
  opacity?: number;
  flat?: boolean; // lie on the floor as a light pool
  squashY?: number;
}> = ({ position, size, color, opacity = 0.6, flat = false, squashY = 1 }) => (
  <mesh
    position={position}
    rotation={flat ? [-Math.PI / 2, 0, 0] : [0, 0, 0]}
    scale={[1, squashY, 1]}
    renderOrder={10}
  >
    <planeGeometry args={[size, size]} />
    <meshBasicMaterial
      map={glowTex()}
      color={color}
      transparent
      opacity={opacity}
      blending={THREE.AdditiveBlending}
      depthWrite={false}
      toneMapped={false}
    />
  </mesh>
);

const Block: React.FC<{
  size: [number, number, number];
  position: [number, number, number];
  color: string;
  noise?: number;
  emissive?: boolean;
}> = ({ size, position, color, noise = 0.08, emissive }) => (
  <mesh position={position} castShadow receiveShadow>
    <boxGeometry args={size} />
    {emissive ? (
      <meshBasicMaterial map={noiseTex(color, noise, 8)} toneMapped={false} />
    ) : (
      <meshLambertMaterial map={noiseTex(color, noise, 8)} />
    )}
  </mesh>
);

// --------------------------------------------------------------------------
/** His small room at night: block walls, plank floor, lamp, moon window. */
export const Room3D: React.FC = () => {
  const frame = useCurrentFrame();
  const flicker = 1 + 0.06 * Math.sin(frame * 0.9) * Math.sin(frame * 0.37);
  const LAMP_X = -3.2;
  return (
    <group>
      <color attach="background" args={["#0B0D16"]} />
      <ambientLight color="#5566AA" intensity={0.35} />

      {/* moonlight through the window */}
      <directionalLight color="#9DB4FF" intensity={0.5} position={[6, 6, 4]} />

      {/* lamp: one shadow-casting spot from the shade + a soft fill */}
      <spotLight
        color="#FFB765"
        intensity={60 * flicker}
        position={[LAMP_X, 2.55, 0]}
        angle={1.0}
        penumbra={0.8}
        decay={1.6}
        distance={0}
        castShadow
        shadow-mapSize-width={1024}
        shadow-mapSize-height={1024}
        shadow-bias={-0.002}
      >
        <object3D attach="target" position={[LAMP_X + 2.5, 0, 0.6]} />
      </spotLight>
      <pointLight
        color="#FFB765"
        intensity={10 * flicker}
        position={[LAMP_X, 2.4, 0.4]}
        decay={1.6}
        distance={0}
      />

      {/* floor */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0, 0]} receiveShadow>
        <planeGeometry args={[20, 8]} />
        <meshLambertMaterial map={planksTex([20, 8])} />
      </mesh>
      {/* back wall */}
      <mesh position={[0, 4, -2.2]} receiveShadow>
        <planeGeometry args={[20, 8]} />
        <meshLambertMaterial map={wallTex([20, 8])} />
      </mesh>

      {/* window with the moon */}
      <group position={[3.4, 2.7, -2.15]}>
        <mesh>
          <planeGeometry args={[2.2, 2.2]} />
          <meshBasicMaterial color="#141B33" />
        </mesh>
        <Block
          size={[0.6, 0.6, 0.1]}
          position={[0.45, 0.45, 0.05]}
          color="#EEEBD8"
          noise={0.06}
          emissive
        />
        <Glow3D
          position={[0.45, 0.45, 0.2]}
          size={2.6}
          color="#CFDBFF"
          opacity={0.5}
        />
        {/* frame */}
        <Block
          size={[2.4, 0.16, 0.2]}
          position={[0, 1.1, 0.08]}
          color="#4A3522"
        />
        <Block
          size={[2.4, 0.2, 0.3]}
          position={[0, -1.12, 0.12]}
          color="#4A3522"
        />
        <Block
          size={[0.16, 2.2, 0.2]}
          position={[-1.12, 0, 0.08]}
          color="#4A3522"
        />
        <Block
          size={[0.16, 2.2, 0.2]}
          position={[1.12, 0, 0.08]}
          color="#4A3522"
        />
        <Block
          size={[0.1, 2.2, 0.12]}
          position={[0, 0, 0.06]}
          color="#4A3522"
        />
        <Block
          size={[2.2, 0.1, 0.12]}
          position={[0, 0, 0.06]}
          color="#4A3522"
        />
      </group>
      <Glow3D
        position={[3.4, 0.02, -0.6]}
        size={3.6}
        color="#8FA8FF"
        opacity={0.18}
        flat
      />

      {/* floor lamp */}
      <group position={[LAMP_X, 0, 0]}>
        <Block
          size={[0.6, 0.12, 0.6]}
          position={[0, 0.06, 0]}
          color="#3A3A44"
        />
        <Block
          size={[0.12, 2.3, 0.12]}
          position={[0, 1.27, 0]}
          color="#3A3A44"
        />
        <Block
          size={[0.8, 0.5, 0.8]}
          position={[0, 2.62, 0]}
          color="#E0904A"
          noise={0.1}
          emissive
        />
        <Glow3D
          position={[0, 2.5, 0.5]}
          size={5.5}
          color="#FFB765"
          opacity={0.55 * flicker}
        />
        <Glow3D
          position={[0, 2.5, 0.5]}
          size={1.6}
          color="#FFE4B0"
          opacity={0.8 * flicker}
        />
        <Glow3D
          position={[0, 0.02, 0.4]}
          size={5}
          color="#FFB765"
          opacity={0.35 * flicker}
          flat
        />
      </group>

      {/* dumbbell */}
      <group position={[2.4, 0, 0.6]}>
        <Block size={[0.7, 0.1, 0.1]} position={[0, 0.2, 0]} color="#7A7A86" />
        <Block
          size={[0.18, 0.4, 0.4]}
          position={[-0.38, 0.2, 0]}
          color="#2C2C34"
        />
        <Block
          size={[0.18, 0.4, 0.4]}
          position={[0.38, 0.2, 0]}
          color="#2C2C34"
        />
      </group>
    </group>
  );
};

// --------------------------------------------------------------------------
type Building = {
  x: number;
  w: number;
  h: number;
  d: number;
  seed: number;
  color: string;
};

const BUILDINGS: Building[] = (() => {
  const out: Building[] = [];
  let x = 0;
  const colors = ["#3A3F57", "#47394A", "#3B4A4A", "#4A4238"];
  for (let i = 0; i < 12; i++) {
    const w = 2 + Math.floor(random(`bw${i}`) * 3);
    const h = 3 + Math.floor(random(`bh${i}`) * 5);
    out.push({ x, w, h, d: 2, seed: i, color: colors[i % colors.length] });
    x += w + 0.5 + Math.floor(random(`bg${i}`) * 2);
  }
  return out;
})();
const CITY_LOOP = BUILDINGS.reduce((m, b) => Math.max(m, b.x + b.w), 0) + 1.5;

/** Night street that scrolls past. `scroll` = blocks travelled. */
export const Street3D: React.FC<{ scroll: number }> = ({ scroll }) => {
  const road = roadTex([40, 5]);
  const walk = sidewalkTex([30, 2]);
  // scroll textures (1 repeat = 1 block)
  road.offset.x = scroll;
  walk.offset.x = scroll;
  const LAMP_GAP = 7;

  return (
    <group>
      <color attach="background" args={["#0A0D1A"]} />
      <ambientLight color="#6677BB" intensity={0.9} />
      <hemisphereLight color="#AFC2FF" groundColor="#3A2A20" intensity={0.6} />
      <directionalLight
        color="#AFC2FF"
        intensity={1.4}
        position={[-4, 8, 6]}
        castShadow
        shadow-mapSize-width={1024}
        shadow-mapSize-height={1024}
        shadow-camera-left={-6}
        shadow-camera-right={6}
        shadow-camera-top={6}
        shadow-camera-bottom={-6}
      />

      {/* moon + stars */}
      <Block
        size={[1.6, 1.6, 0.2]}
        position={[7, 7.2, -14]}
        color="#EEEBD8"
        noise={0.06}
        emissive
      />
      <Glow3D
        position={[7, 7.2, -13.6]}
        size={8}
        color="#CFDBFF"
        opacity={0.4}
      />
      {Array.from({ length: 40 }, (_, i) => (
        <mesh
          key={i}
          position={[
            -26 + random(`sx${i}`) * 52,
            6 + random(`sy${i}`) * 10,
            -16,
          ]}
        >
          <boxGeometry args={[0.12, 0.12, 0.05]} />
          <meshBasicMaterial color="#C8D2FF" toneMapped={false} />
        </mesh>
      ))}

      {/* sidewalk (where he runs) and road behind */}
      <mesh
        rotation={[-Math.PI / 2, 0, 0]}
        position={[0, 0, 0.5]}
        receiveShadow
      >
        <planeGeometry args={[30, 2]} />
        <meshLambertMaterial map={walk} />
      </mesh>
      <mesh
        rotation={[-Math.PI / 2, 0, 0]}
        position={[0, 0, -1.5]}
        receiveShadow
      >
        <planeGeometry args={[40, 5]} />
        <meshLambertMaterial map={road} />
      </mesh>

      {/* buildings, slower parallax */}
      {BUILDINGS.map((b) => {
        const px =
          ((((b.x - scroll * 0.5) % CITY_LOOP) + CITY_LOOP) % CITY_LOOP) - 18;
        return (
          <mesh
            key={b.seed}
            position={[px + b.w / 2, b.h / 2, -7]}
            receiveShadow
          >
            <boxGeometry args={[b.w, b.h, b.d]} />
            <meshLambertMaterial
              map={facadeTex(b.seed, b.w, b.h, b.color, false)}
              emissiveMap={facadeTex(b.seed, b.w, b.h, b.color, true)}
              emissive="#FFFFFF"
              emissiveIntensity={1}
            />
          </mesh>
        );
      })}

      {/* street lamps, moving at full speed */}
      {Array.from({ length: 5 }, (_, i) => {
        const x =
          ((((i * LAMP_GAP - scroll) % (LAMP_GAP * 5)) + LAMP_GAP * 5) %
            (LAMP_GAP * 5)) -
          14;
        return (
          <group key={i} position={[x, 0, -0.55]}>
            <Block
              size={[0.16, 3.6, 0.16]}
              position={[0, 1.8, 0]}
              color="#2A2A32"
            />
            <Block
              size={[0.9, 0.14, 0.16]}
              position={[0.38, 3.55, 0]}
              color="#2A2A32"
            />
            <Block
              size={[0.4, 0.2, 0.34]}
              position={[0.75, 3.42, 0]}
              color="#FFD27A"
              emissive
            />
            <Glow3D
              position={[0.75, 3.3, 0.3]}
              size={4}
              color="#FFB765"
              opacity={0.5}
            />
            <Glow3D
              position={[0.75, 0.02, 0.6]}
              size={4.2}
              color="#FFB765"
              opacity={0.4}
              flat
            />
          </group>
        );
      })}
    </group>
  );
};

// --------------------------------------------------------------------------
/** Close-up of the phone lying on a desk, screen glowing. */
export const Phone3D: React.FC<{ buzz: number }> = ({ buzz }) => {
  const frame = useCurrentFrame();
  const dx = Math.sin(frame * 2.7) * 0.03 * buzz;
  const rz = Math.sin(frame * 3.1) * 0.03 * buzz;
  return (
    <group>
      <color attach="background" args={["#07080D"]} />
      <ambientLight color="#4455AA" intensity={0.25} />
      <pointLight
        color="#A9C4FF"
        intensity={14}
        position={[0, 0.8, 1.2]}
        decay={1.6}
      />
      {/* desk */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[8, 6]} />
        <meshLambertMaterial map={planksTex([8, 6])} />
      </mesh>
      <group position={[dx, 0.06, 0]} rotation={[-Math.PI / 2, 0, rz]}>
        <mesh castShadow>
          <boxGeometry args={[1.05, 2.05, 0.12]} />
          <meshLambertMaterial map={noiseTex("#1A1C24", 0.1, 8)} />
        </mesh>
        <mesh position={[0, 0, 0.062]}>
          <planeGeometry args={[0.9, 1.8]} />
          <meshBasicMaterial map={phoneScreenTex()} toneMapped={false} />
        </mesh>
      </group>
      <Glow3D
        position={[0, 0.1, 0]}
        size={4.5}
        color="#A9C4FF"
        opacity={0.35}
        flat
      />
    </group>
  );
};
