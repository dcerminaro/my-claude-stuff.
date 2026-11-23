import React from "react";
import * as THREE from "three";
import { Pose } from "../components/Figure";
import { noiseTex } from "./textures";

/**
 * Our character as a 3D block figure. Same personality as the 2D version:
 * a big head (here a big cube), no neck, dot eyes, one-block brows and a
 * stepped mouth, plain limbs with no fingers. Faces +x (right).
 *
 * Units: 1 = one block. Standing height is about 2.3 blocks.
 */

const THIGH = 0.38;
const SHIN = 0.38;
const LEG_W = 0.26;
const TORSO = { w: 0.58, h: 0.7, d: 0.34 };
const HEAD = 0.86;
const ARM = { w: 0.22, l: 0.72 };

const VIOLET = "#9B5CFF";
const HERO = "#F2B84B";
const HERO_DARK = "#D19A34";
const FACE = "#2B1D0E";
const BAND = "#E5484D";

type PartProps = {
  size: [number, number, number];
  position?: [number, number, number];
  color: string;
  shadow: boolean;
  noise?: number;
};

/** One block part. The shadow version gets a glowing violet shell. */
const Part: React.FC<PartProps> = ({
  size,
  position = [0, 0, 0],
  color,
  shadow,
  noise = 0.07,
}) => {
  const map = noiseTex(shadow ? "#0A0A0E" : color, shadow ? 0.25 : noise, 8);
  return (
    <group position={position}>
      <mesh castShadow receiveShadow>
        <boxGeometry args={size} />
        <meshLambertMaterial map={map} />
      </mesh>
      {shadow && (
        <mesh
          scale={[1 + 0.09 / size[0], 1 + 0.09 / size[1], 1 + 0.09 / size[2]]}
        >
          <boxGeometry args={size} />
          <meshBasicMaterial
            color={VIOLET}
            side={THREE.BackSide}
            toneMapped={false}
          />
        </mesh>
      )}
    </group>
  );
};

export const Voxel: React.FC<{
  position: [number, number, number];
  facing?: number; // y-rotation; π/2 = facing right, less turns his face toward camera
  scale?: number;
  pose?: Pose;
  variant?: "hero" | "shadow";
  emerge?: number;
  visible?: boolean;
}> = ({
  position,
  facing = Math.PI / 2 - 0.85,
  scale = 1,
  pose = {},
  variant = "hero",
  emerge = 1,
  visible = true,
}) => {
  const shadow = variant === "shadow";
  const {
    squat = 0,
    lift = 0,
    squash = 1,
    lean = 0,
    brow = 0,
    browLift = 0,
    mouth = 0,
    blink = 0,
    arms = "idle",
    armBlend = 0,
    runPhase,
    headband = false,
    t = 0,
  } = pose;

  const running = runPhase !== undefined;

  // legs: thigh swings forward by a, shin bends back so the foot stays under the hip
  const a = squat * 1.0;
  const legAngles = running
    ? [0, Math.PI].map((off) => {
        const p = runPhase! + off;
        const thigh = 0.85 * Math.sin(p);
        const knee = 1.1 * Math.max(0, Math.cos(p));
        return { thigh: -thigh, shin: knee };
      })
    : [
        { thigh: -a, shin: 2 * a },
        { thigh: -a, shin: 2 * a },
      ];
  const hipY = running ? THIGH + SHIN - 0.04 : (THIGH + SHIN) * Math.cos(a);

  // arms
  const armRot = (idx: number): [number, number, number] => {
    const side = idx ? 1 : -1;
    const idleSwing = Math.sin(t * 0.08 + idx) * 0.04;
    let x = idleSwing;
    let z = 0;
    if (arms === "forward") x = -1.45;
    if (arms === "up") {
      x = -2.75;
      z = side * 0.35;
    }
    if (arms === "run")
      x = 0.9 * Math.sin((runPhase ?? 0) + (idx ? 0 : Math.PI));
    return [idleSwing + (x - idleSwing) * armBlend, 0, z * armBlend];
  };

  const sy = squash * emerge;
  const sxz = 1 / Math.sqrt(squash);

  const torsoColor = shadow ? "#000" : HERO;
  const limbColor = shadow ? "#000" : HERO_DARK;
  const browA = brow * 0.4;
  const browY = 0.2 + browLift * 0.05;
  const faceZ = HEAD / 2 + 0.012;
  const leanRad = (lean * Math.PI) / 180 + 0.32 * squat;

  return (
    <group
      position={position}
      rotation={[0, facing, 0]}
      scale={[scale * sxz, scale * sy, scale * sxz]}
      visible={visible}
    >
      {/* legs */}
      {legAngles.map((l, i) => (
        <group
          key={i}
          position={[(i ? 1 : -1) * 0.14, hipY + lift, 0]}
          rotation={[l.thigh, 0, 0]}
        >
          <Part
            size={[LEG_W, THIGH, LEG_W]}
            position={[0, -THIGH / 2, 0]}
            color={limbColor}
            shadow={shadow}
          />
          <group position={[0, -THIGH, 0]} rotation={[l.shin, 0, 0]}>
            <Part
              size={[LEG_W, SHIN, LEG_W]}
              position={[0, -SHIN / 2, 0]}
              color={limbColor}
              shadow={shadow}
            />
          </group>
        </group>
      ))}

      {/* upper body pivots at the hips */}
      <group position={[0, hipY + lift, 0]} rotation={[leanRad, 0, 0]}>
        <Part
          size={[TORSO.w, TORSO.h, TORSO.d]}
          position={[0, TORSO.h / 2, 0]}
          color={torsoColor}
          shadow={shadow}
        />

        {/* arms pivot at the shoulders */}
        {[0, 1].map((idx) => (
          <group
            key={idx}
            position={[
              (idx ? 1 : -1) * (TORSO.w / 2 + ARM.w / 2),
              TORSO.h - 0.06,
              0,
            ]}
            rotation={armRot(idx)}
          >
            <Part
              size={[ARM.w, ARM.l, ARM.w]}
              position={[0, -ARM.l / 2 + 0.06, 0]}
              color={limbColor}
              shadow={shadow}
            />
          </group>
        ))}

        {/* big head, sits straight on the body */}
        <group position={[0, TORSO.h + HEAD / 2, 0]}>
          <Part
            size={[HEAD, HEAD, HEAD]}
            color={shadow ? "#000" : HERO}
            shadow={shadow}
            noise={0.05}
          />

          {shadow ? (
            // two glowing slit eyes
            [-1, 1].map((s) => (
              <mesh
                key={s}
                position={[s * 0.18, 0.04, faceZ + 0.01]}
                rotation={[0, 0, s * -0.25]}
              >
                <boxGeometry args={[0.24, 0.05, 0.02]} />
                <meshBasicMaterial color={VIOLET} toneMapped={false} />
              </mesh>
            ))
          ) : (
            <group position={[0, 0, faceZ]}>
              {/* dot eyes */}
              {[-1, 1].map((s) => (
                <mesh
                  key={`e${s}`}
                  position={[s * 0.18, 0.04, 0]}
                  scale={[1, Math.max(0.1, 1 - blink), 1]}
                >
                  <boxGeometry args={[0.11, 0.11, 0.02]} />
                  <meshLambertMaterial color={FACE} />
                </mesh>
              ))}
              {/* one-block eyebrows: inner ends drop when determined, rise when worried */}
              {[-1, 1].map((s) => (
                <mesh
                  key={`b${s}`}
                  position={[s * 0.18, browY, 0.004]}
                  rotation={[0, 0, s * browA]}
                >
                  <boxGeometry args={[0.22, 0.055, 0.02]} />
                  <meshLambertMaterial color={FACE} />
                </mesh>
              ))}
              {/* stepped mouth: three blocks, sides go up for a smile */}
              {[-1, 0, 1].map((k) => (
                <mesh
                  key={`m${k}`}
                  position={[k * 0.07, -0.2 + (k ? mouth * 0.05 : 0), 0]}
                >
                  <boxGeometry args={[0.07, 0.05, 0.02]} />
                  <meshLambertMaterial color={FACE} />
                </mesh>
              ))}
            </group>
          )}

          {headband && !shadow && (
            <group>
              <mesh position={[0, 0.24, 0]}>
                <boxGeometry args={[HEAD + 0.04, 0.12, HEAD + 0.04]} />
                <meshLambertMaterial color={BAND} />
              </mesh>
              {[0, 1].map((i) => (
                <mesh
                  key={i}
                  position={[i ? 0.1 : -0.1, 0.2 - i * 0.06, -HEAD / 2 - 0.2]}
                  rotation={[
                    0.5 + Math.sin(t * 0.5 + i) * 0.25,
                    i ? 0.25 : -0.25,
                    0,
                  ]}
                >
                  <boxGeometry args={[0.08, 0.08, 0.38]} />
                  <meshLambertMaterial color={BAND} />
                </mesh>
              ))}
            </group>
          )}
        </group>
      </group>
    </group>
  );
};
