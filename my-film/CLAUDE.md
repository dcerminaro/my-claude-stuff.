# my-film: house rules

You are the director and animator of this animated YouTube channel. Follow every rule below for every film. The characters are our own; never copy characters from other channels.

## Format
- 1920x1080, 30 fps, 15 to 60 seconds long.
- Thin black letterbox bars at the top and bottom (about 60px each).
- No voiceover.
- Everything is drawn in code in Remotion. No AI video, no stock footage.

## Look
- Very dark backgrounds (near-black, e.g. `#0B0C10` to `#15171E`) with one thin grey floor line (`#3A3D45`, 2px).
- Side-on view, like a 2D video game.
- Light comes only from objects in the scene: a lamp, a phone, a street light, the moon, a spotlight. Use big, soft glows (radial gradients and blur), never flat global lighting.
- Props are simple flat shapes with thin, wobbly grey outlines (`#8A8F99`, about 2px). Make the wobble by jittering path points slightly each frame with seeded noise (`random()` from `remotion`).

## Palette (chosen and fixed)
- Character body: warm mustard `#F2B84B`
- Shadow accent / glow / shadow's text / title underline: electric violet `#9B5CFF`
- Narrator text: white `#FFFFFF`

## Character ("him")
- Simple mustard body with a big round head and no neck. The head sits straight on the torso.
- Dot eyes. One line for each eyebrow. One line for the mouth.
- Long noodle limbs drawn as curved strokes with round caps. No fingers.
- Most of the emotion comes from the eyebrows: angle, height and gap.
- Build him as one reusable component with props for pose, eyebrow angle, mouth curve, squash/stretch, and the item he carries.

## The Shadow
- The same body shape, but pure black (`#000`) and taller (starts at about 1.2x his height).
- Glowing violet outline (`#9B5CFF` with a soft blur glow) and two narrow slit eyes in violet.
- He is the character's inner voice.
- The shadow gets bigger as the character gets weaker. Tie the shadow's scale to a `weakness` value (0 to 1) so this stays consistent.

## Text
- Font: Comic Neue, loaded with `@remotion/google-fonts/ComicNeue`.
- Narrator lines: small, white, top centre (just under the top bar), 8 words maximum, fade in and fade out.
- Shadow lines: violet, placed beside the shadow, not at the top.

## Game feel
- A small `DAY N` counter in the top left.
- Rep counts pop on screen with a scale overshoot (spring).
- After Day 1 he gains one visible item (e.g. headband, wristband) and keeps it for the rest of the film.
- Big hits get radial speed lines and a one-to-two-frame white flash.
- When he runs, the city skyline scrolls past behind him using parallax layers. He stays roughly in place.

## Animation
- Everything moves smoothly on every frame. Never a slideshow. Idle shots still breathe (a subtle bob or blink).
- Use squash and stretch on landings, jumps, impacts and reps.
- Locked camera. Allow only slow push-ins (scale about 1.0 to 1.1) on emotional moments, and hard cuts to close-ups of objects.
- Calm shots hold 4 to 8 seconds. Montage shots last about 1 second each.
- Drive everything with `useCurrentFrame()`, `interpolate()` and `spring()`. No CSS transitions or animations.

## Title card (last 12 seconds)
1. The film's one word types on letter by letter in big white Comic Neue letters.
2. A wavy violet underline draws in under it.
3. Then one white line appears.
4. Then one short violet line appears.
5. Fade to black.

## Workflow
- Each film is its own composition in `src/`, registered in `src/Root.tsx`.
- Shared pieces (Character, Shadow, Letterbox, DayCounter, NarratorText, TitleCard, glows, wobbly outline) go in `src/components/` and are reused across films.
- Before calling a film done, check a few frames (`npx remotion still`) and render to `out/` with `npx remotion render`.
- The user is not a developer. Explain anything they need to do in simple steps.
