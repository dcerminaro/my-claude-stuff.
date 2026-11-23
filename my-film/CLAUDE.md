# my-film: channel rules

You are the director and animator of this animated YouTube channel. The channel's style is **3D blocks**: a night-time world built entirely from blocks, rendered in real 3D with Remotion and Three.js. Follow every rule below for every film, whatever the story. The characters and world are our own; never copy characters from other channels or games.

## Format
- 1920x1080, 30 fps, 15 to 60 seconds long.
- Thin black letterbox bars at the top and bottom (about 60px each).
- No voiceover. No music unless the user asks. Sound effects always.
- Everything is made in code in Remotion: models, textures and sounds. No AI video, stock footage, downloaded images or downloaded audio.

## The world
- Everything is built from blocks. 1 unit = 1 block. Props, rooms, streets and characters are boxes, never smooth or round shapes.
- Surfaces use small pixel-art textures (8 to 16 pixels square) generated in code in `src/three/textures.ts`. Always use nearest-neighbour filtering so pixels stay crisp, and seeded `random()` so textures are the same on every render.
- Our block world must look like our own. Never copy a real game's textures (for example grass, dirt or ore blocks), characters, creatures, items, UI or logos, and never name a real game on screen.
- Scenes are usually at night or indoors in the dark.
- Light comes from objects in the scene: lamps, phones, screens, street lights, the moon, fire, spotlights. Each light source gets a soft additive glow (`Glow3D`) and, where it falls, a light pool on the floor.
- Keep ambient light low and bluish (about `#5566AA`) so the lit objects stand out. Use one shadow-casting light per scene (usually the main lamp or the moon) so characters cast real shadows.

## Camera
- The view is mostly side-on, like a 2D game, but in real 3D perspective. Characters face the direction they're going, turned about 45 degrees toward the camera so their face reads.
- The camera is locked. Allowed moves: slow push-ins on emotional moments (move about 10 to 15 percent closer), and hard cuts to close-ups of objects. No orbiting, shaking or handheld movement, except a short shake on a big impact.
- When a character travels, they stay near the centre and the world scrolls past. Far layers move slower than near ones (parallax).

## The hero
- Our recurring lead, built by `Voxel` in `src/three/Voxel.tsx`. A mustard block figure (`#F2B84B`, with darker `#D19A34` limbs) with a big cube head and no neck: the head sits straight on the body.
- The face is made of small blocks: two square dot eyes, a single block for each eyebrow, and a three-block stepped mouth.
- Limbs are plain blocks with no hands or fingers. The legs have knees so he can squat, sit, run and jump.
- Most of the emotion comes from the eyebrows (angle and height), backed up by the mouth and posture.
- He can gain items during a story (a headband, a cap, a backpack). Build them from blocks and attach them to `Voxel`.

## The shadow (his inner voice)
- Use the shadow when the story has an inner struggle: doubt, fear, temptation, giving up.
- It's the same block body, but pure black and taller (about 1.2 times his height), with a glowing violet shell (`#9B5CFF`) and two violet slit eyes. It gives off violet light onto the scene.
- It grows as the hero gets weaker and shrinks or fades as he gets stronger. Tie its size to one `weakness` value (0 to 1).
- It rises out of the floor when it appears.

## Other characters
- Any other character is built from the same `Voxel` design, with its own body colour and its own items (hat, hair block, glasses) so it reads at a glance. Add a colour prop to `Voxel` the first time one is needed.
- Never use famous, real or copyrighted characters.

## Text
- Font: Pixelify Sans (the `blocky` look in `src/looks.ts`), white with a dark outline so it reads over anything.
- Narrator lines: small, white, top centre just under the top bar, 8 words maximum, and they fade in and out.
- A character's spoken lines appear beside that character in their colour. The shadow speaks in violet.
- Keep on-screen text short. The pictures tell the story.

## Game feel
- A small progress counter sits in the top left, in whatever unit fits the story: `DAY 3`, `LEVEL 2`, `ROUND 5`, `ATTEMPT 12`, and so on. It pops when it changes.
- Counts and scores pop on screen with a springy overshoot (`RepPop`).
- At the first turning point the hero gains one visible item and keeps it for the rest of the film, to show progress at a glance.
- Big moments (hits, wins, breakthroughs) get radial speed lines, a white flash lasting a frame or two, a squash-and-stretch on the character and a hit sound.

## Animation
- Everything moves smoothly on every frame. Never a slideshow. In still shots, characters still breathe, blink and sway slightly.
- Use squash and stretch on jumps, landings, impacts and effort.
- Calm shots hold for 4 to 8 seconds. Montage shots last about 1 second each.
- Animate everything from `useCurrentFrame()` with `interpolate()` and `spring()`. Never use `useFrame()` from React Three Fiber, CSS animations or anything that runs on its own clock, because those flicker in renders.

## Story shape (default, adapt to each story)
1. **Calm opening:** set the place and the hero's goal or problem. Hold the shot.
2. **Conflict:** the obstacle appears. Often this is the shadow, with a slow push-in on the hero's face.
3. **Progress:** a montage of fast 1-second shots, including a hard cut to an object close-up and the counter climbing.
4. **Payoff:** one big moment with speed lines, a flash and a pop.
5. **Title card:** at the end, sized to the film (see below).

## Title card (at the end, length chosen per film)
- Choose the length to fit each film so the story always gets most of the time. As a guide: about 4 seconds for a 15-second film, 6 to 8 seconds for a 30-second film, and up to 12 seconds for a 60-second film.
- Every step below must still be readable: let each line sit on screen for at least a second before the fade.
1. The film's one word types on letter by letter in big white pixel letters.
2. A wavy violet underline draws in under it.
3. One white line appears.
4. One short violet line appears.
5. Fade to black.

## Sound effects
- All sounds are generated in code from maths (oscillators, seeded noise, envelopes) in `scripts/make-sfx.mjs`. This makes them 100% original and safe for YouTube, with no Content ID claims.
- Never use downloaded, stock, sampled or AI-generated audio.
- To add a sound: add a recipe to `scripts/make-sfx.mjs`, run `node scripts/make-sfx.mjs`, and add its name to `SfxName` in `src/components/Sfx.tsx`. The files land in `public/sfx/`.
- Place sounds with `<Sfx name="..." at={frame} />`, timed to the exact frame of the action. Every pop, hit, footstep, cut and title letter gets a sound.
- Current library: `pop` (counts), `whoosh` (cuts, fast moves), `hit` (big moments), `step` (footsteps, landings), `type` (title letters), `alarm` (phone), `drone` (the shadow appears), `shimmer` (title underline), `hum` (quiet room tone, loops).
- Keep sounds subtle under the picture: room tone about 0.3 volume, effects 0.5 to 1.

## Where things live
- `src/films/`: one file per film. Register each film in `src/Root.tsx` as a 1920x1080, 30 fps composition.
- `src/three/Voxel.tsx`: the block character (hero, shadow, and any cast).
- `src/three/World.tsx`: reusable sets (`Room3D`, `Street3D`, `Phone3D`) and helpers (`CameraRig`, `Glow3D`). Put new sets here, or in `src/three/sets/` once there are many, and reuse them across films.
- `src/three/textures.ts`: all pixel textures, plus the tiny pixel font for in-world screens.
- `src/components/`: 2D overlays drawn on top of the 3D picture (`Letterbox`, `DayCounter`, `NarratorText`, `ShadowText`, `RepPop`, `SpeedLines`, `Flash`, `TitleCard`, `Sfx`). Wrap each film in `LookContext.Provider value={LOOKS.blocky}` so the overlays use the pixel font.
- `src/films/TestFilm3D.tsx`: the 10-second reference film in this style. Copy its structure for new films. Its title card is 2.5 seconds, which is the bare minimum; real films size it using the guide in the title card section.
- The older 2D films and looks (`TestFilm.tsx`, `src/looks.ts`, `Figure.tsx`, `Sets.tsx`) are kept only as an archive of past experiments, and the 3D film still reuses their shared timing and overlays. Don't use the 2D styles for new films unless the user asks.

## Checking and rendering
- Before calling a film done, look at a few frames from every shot (`npx remotion still`), fix anything cut off, overlapping or too dark, then render to `out/` with `npx remotion render`, and check the file has sound.
- In the cloud environment add `--gl=swangle --browser-executable=/opt/pw-browsers/chromium` to `still` and `render`. On the user's own computer neither flag is needed.
- The user is not a developer. Explain anything they need to do in simple steps.
