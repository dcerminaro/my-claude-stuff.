import React from "react";
import * as THREE from "three";
import { Pose } from "../components/Figure";
import { noiseTex, rulerTex } from "./textures";

/**
 * Every block character on the channel.
 * Big cube head, no neck, square dot eyes, one-block brows, stepped mouth,
 * plain limbs with no fingers.
 *
 * outfit "plain"  = the mustard student (default)
 * outfit "caesar" = Caesar: tan skin, toga, crimson sash, gold laurel,
 *                   balding hair cap, Roman nose, holds a ruler
 * variant "shadow" = black copy with a glowing violet shell
 *
 * Faces +z at facing=0 (toward the camera). π/2 faces right.
 * Units: 1 = one block. Standing height is about 2.3 blocks.
 */

const THIGH = 0.38;
const SHIN = 0.38;
const LEG_W = 0.26;
const TORSO = { w: 0.58, h: 0.7, d: 0.34 };
const HEAD = 0.86;
const ARM = { w: 0.22, l: 0.72 };

const VIOLET = "#9B5CFF";
const FACE = "#2B1D0E";
const BAND = "#E5484D";

const OUTFITS = {
  plain: { skin: "#F2B84B", limb: "#D19A34", legs: "#D19A34" },
  caesar: { skin: "#E2B07E", limb: "#D9A673", legs: "#D9A673" },
};
const TOGA = "#EEE8D8";
const SASH = "#B3262E";
const LAUREL = "#C9A633";
const HAIR = "#3B2A1E";
const SANDAL = "#6B4426";

export type VoxelPose = Pose & {
  sit?: number; // 0 standing .. 1 seated on a chair
  talk?: number; // 0 closed .. 1 mouth wide open
  /** per-arm rotation override [x, y, z] in radians, blended by armOverride */
  armL?: [number, number, number];
  armR?: [number, number, number];
  armOverride?: number;
  headYaw?: number; // turn the head left/right (radians)
  headTilt?: number; // nod (radians, + = chin down)
};

type PartProps = {
  size: [number, number, number];
  position?: [number, number, number];
  rotation?: [number, number, number];
  color: string;
  shadow: boolean;
  noise?: number;
  map?: THREE.Texture;
};

/** One block part. The shadow version gets a glowing violet shell. */
const Part: React.FC<PartProps> = ({
  size,
  position = [0, 0, 0],
  rotation,
  color,
  shadow,
  noise = 0.07,
  map,
}) => {
  const tex =
    map ?? noiseTex(shadow ? "#0A0A0E" : color, shadow ? 0.25 : noise, 8);
  return (
    <group position={position} rotation={rotation}>
      <mesh castShadow receiveShadow>
        <boxGeometry args={size} />
        <meshLambertMaterial map={tex} />
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

const Dark: React.FC<{
  size: [number, number, number];
  position: [number, number, number];
  rotation?: [number, number, number];
  color?: string;
}> = ({ size, position, rotation, color = FACE }) => (
  <mesh position={position} rotation={rotation}>
    <boxGeometry args={size} />
    <meshLambertMaterial color={color} />
  </mesh>
);

export const Voxel: React.FC<{
  position: [number, number, number];
  facing?: number;
  scale?: number;
  pose?: VoxelPose;
  variant?: "hero" | "shadow";
  outfit?: "plain" | "caesar";
  ruler?: boolean;
  emerge?: number;
  visible?: boolean;
}> = ({
  position,
  facing = Math.PI / 2 - 0.85,
  scale = 1,
  pose = {},
  variant = "hero",
  outfit = "plain",
  ruler = false,
  emerge = 1,
  visible = true,
}) => {
  const shadow = variant === "shadow";
  const caesar = outfit === "caesar" && !shadow;
  const col = OUTFITS[outfit];
  const {
    squat = 0,
    sit = 0,
    lift = 0,
    squash = 1,
    lean = 0,
    brow = 0,
    browLift = 0,
    mouth = 0,
    talk = 0,
    blink = 0,
    arms = "idle",
    armBlend = 0,
    armL,
    armR,
    armOverride = 0,
    runPhase,
    headband = false,
    headYaw = 0,
    headTilt = 0,
    t = 0,
  } = pose;

  const running = runPhase !== undefined;

  // legs: thigh swings forward, shin bends back
  const a = squat * 1.0;
  const legAngles = running
    ? [0, Math.PI].map((off) => {
        const p = runPhase! + off;
        return {
          thigh: -0.85 * Math.sin(p),
          shin: 1.1 * Math.max(0, Math.cos(p)),
        };
      })
    : [0, 1].map(() => ({
        thigh: -a - (Math.PI / 2) * sit,
        shin: 2 * a + (Math.PI / 2) * sit,
      }));
  const standHip = running ? THIGH + SHIN - 0.04 : (THIGH + SHIN) * Math.cos(a);
  const hipY = standHip + (0.5 - standHip) * sit;

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
    const base: [number, number, number] = [
      idleSwing + (x - idleSwing) * armBlend,
      0,
      z * armBlend,
    ];
    const ov = idx ? armR : armL;
    if (!ov || armOverride <= 0) return base;
    return [0, 1, 2].map((k) => base[k] + (ov[k] - base[k]) * armOverride) as [
      number,
      number,
      number,
    ];
  };

  const sy = squash * emerge;
  const sxz = 1 / Math.sqrt(squash);

  const skin = shadow ? "#000" : col.skin;
  const limbColor = shadow ? "#000" : col.limb;
  const legColor = shadow ? "#000" : col.legs;
  const browA = brow * 0.4;
  const browY = 0.2 + browLift * 0.05;
  const faceZ = HEAD / 2 + 0.012;
  const leanRad = (lean * Math.PI) / 180 + 0.32 * squat;
  const openH = 0.03 + 0.15 * talk;

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
            color={legColor}
            shadow={shadow}
          />
          <group position={[0, -THIGH, 0]} rotation={[l.shin, 0, 0]}>
            <Part
              size={[LEG_W, SHIN, LEG_W]}
              position={[0, -SHIN / 2, 0]}
              color={legColor}
              shadow={shadow}
            />
            {caesar && (
              <Part
                size={[LEG_W + 0.03, 0.07, LEG_W + 0.08]}
                position={[0, -SHIN + 0.035, 0.03]}
                color={SANDAL}
                shadow={false}
              />
            )}
          </group>
        </group>
      ))}

      {/* upper body pivots at the hips */}
      <group position={[0, hipY + lift, 0]} rotation={[leanRad, 0, 0]}>
        <Part
          size={[TORSO.w, TORSO.h, TORSO.d]}
          position={[0, TORSO.h / 2, 0]}
          color={skin}
          shadow={shadow}
        />

        {caesar && (
          <group>
            {/* toga over the body, hanging past the hips like a skirt */}
            <Part
              size={[TORSO.w + 0.06, TORSO.h * 0.82, TORSO.d + 0.06]}
              position={[0, TORSO.h * 0.41 + 0.02, 0]}
              color={TOGA}
              shadow={false}
              noise={0.05}
            />
            <Part
              size={[TORSO.w + 0.1, 0.42 - 0.3 * sit, TORSO.d + 0.1]}
              position={[0, -0.15 + 0.15 * sit, 0]}
              color={TOGA}
              shadow={false}
              noise={0.05}
            />
            {/* crimson sash across the chest */}
            <Part
              size={[0.14, TORSO.h * 1.15, 0.03]}
              position={[0.02, TORSO.h * 0.5, TORSO.d / 2 + 0.05]}
              rotation={[0, 0, 0.62]}
              color={SASH}
              shadow={false}
            />
            <Part
              size={[0.16, TORSO.h * 0.7, 0.2]}
              position={[-TORSO.w / 2 - 0.02, TORSO.h * 0.55, 0]}
              color={SASH}
              shadow={false}
            />
          </group>
        )}

        {/* arms pivot at the shoulders */}
        {[0, 1].map((idx) => (
          <group
            key={idx}
            position={[
              (idx ? 1 : -1) * (TORSO.w / 2 + ARM.w / 2 + (caesar ? 0.03 : 0)),
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
            {/* ruler held in the right hand, extending along the arm like a sword */}
            {ruler && idx === 1 && (
              <mesh position={[0, -ARM.l - 0.42, 0.02]} castShadow>
                <boxGeometry args={[0.05, 1.05, 0.13]} />
                <meshLambertMaterial map={rulerTex()} />
              </mesh>
            )}
          </group>
        ))}

        {/* big head, sits straight on the body */}
        <group
          position={[0, TORSO.h + HEAD / 2, 0]}
          rotation={[headTilt, headYaw, 0]}
        >
          <Part
            size={[HEAD, HEAD, HEAD]}
            color={skin}
            shadow={shadow}
            noise={0.05}
          />

          {shadow ? (
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
              {[-1, 1].map((s) => (
                <Dark
                  key={`b${s}`}
                  size={[caesar ? 0.24 : 0.22, caesar ? 0.07 : 0.055, 0.02]}
                  position={[s * 0.18, browY, 0.004]}
                  rotation={[0, 0, s * browA]}
                />
              ))}
              {caesar && (
                <Part
                  size={[0.12, 0.2, 0.12]}
                  position={[0, -0.07, 0.06]}
                  color={col.skin}
                  shadow={false}
                  noise={0.04}
                />
              )}
              {talk > 0.02 ? (
                // open mouth while speaking
                <group position={[0, -0.24 + mouth * 0.01, 0]}>
                  <Dark
                    size={[0.22, openH, 0.02]}
                    position={[0, 0, 0]}
                    color="#3A0E0E"
                  />
                  <Dark
                    size={[0.07, 0.05, 0.02]}
                    position={[-0.14, openH / 2 - 0.02 + mouth * 0.04, 0]}
                  />
                  <Dark
                    size={[0.07, 0.05, 0.02]}
                    position={[0.14, openH / 2 - 0.02 + mouth * 0.04, 0]}
                  />
                </group>
              ) : (
                [-1, 0, 1].map((k) => (
                  <Dark
                    key={`m${k}`}
                    size={[0.07, 0.05, 0.02]}
                    position={[
                      k * 0.07,
                      (caesar ? -0.24 : -0.2) + (k ? mouth * 0.05 : 0),
                      0,
                    ]}
                  />
                ))
              )}
            </group>
          )}

          {caesar && (
            <group>
              {/* thin hair cap with a bald patch on top */}
              {[
                [-0.31, 0.31],
                [0.31, 0.31],
                [0, -0.31],
                [-0.31, 0],
                [0.31, 0],
                [-0.31, -0.31],
                [0.31, -0.31],
              ].map(([x, z], i) => (
                <Part
                  key={i}
                  size={[0.25, 0.07, 0.25]}
                  position={[x, HEAD / 2 + 0.035, z]}
                  color={HAIR}
                  shadow={false}
                />
              ))}
              <Part
                size={[HEAD + 0.02, 0.18, 0.08]}
                position={[0, HEAD / 2 - 0.09, -HEAD / 2 + 0.03]}
                color={HAIR}
                shadow={false}
              />
              {/* combover strands across the front */}
              {[-0.2, 0, 0.2].map((x) => (
                <Part
                  key={x}
                  size={[0.12, 0.04, 0.3]}
                  position={[x, HEAD / 2 + 0.03, 0.2]}
                  color={HAIR}
                  shadow={false}
                />
              ))}
              {/* gold laurel wreath: leaves on the sides and back */}
              {Array.from({ length: 10 }, (_, i) => {
                // φ = 0 is the face; leave the front open
                const phi = Math.PI * 0.3 + (i / 9) * Math.PI * 1.4;
                const r = HEAD / 2 + 0.05;
                return (
                  <Part
                    key={`l${i}`}
                    size={[0.14, 0.1, 0.14]}
                    position={[
                      Math.sin(phi) * r,
                      HEAD / 2 - 0.12 + (i % 2) * 0.06,
                      Math.cos(phi) * r,
                    ]}
                    rotation={[0, phi, 0.3 * (i % 2 ? 1 : -1)]}
                    color={LAUREL}
                    shadow={false}
                    noise={0.12}
                  />
                );
              })}
            </group>
          )}

          {headband && !shadow && (
            <group>
              <Dark
                size={[HEAD + 0.04, 0.12, HEAD + 0.04]}
                position={[0, 0.24, 0]}
                color={BAND}
              />
              {[0, 1].map((i) => (
                <Dark
                  key={i}
                  size={[0.08, 0.08, 0.38]}
                  position={[i ? 0.1 : -0.1, 0.2 - i * 0.06, -HEAD / 2 - 0.2]}
                  rotation={[
                    0.5 + Math.sin(t * 0.5 + i) * 0.25,
                    i ? 0.25 : -0.25,
                    0,
                  ]}
                  color={BAND}
                />
              ))}
            </group>
          )}
        </group>
      </group>
    </group>
  );
};
