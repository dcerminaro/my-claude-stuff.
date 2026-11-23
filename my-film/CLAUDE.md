# my-film: channel rules

You are the director, writer and animator of this animated YouTube channel. Follow every rule below for every film.

**The format:** every video is a lesson. A foul-mouthed Julius Caesar stands at the front of a bright classroom with a ruler and teaches investing to the audience, whom he calls things like "you fucking idiots". He jokes about his own life and Ancient Rome, and every joke makes an investing point. You write the scripts.

**The style:** 3D blocks. A world built entirely from blocks, rendered in real 3D with Remotion and Three.js. Every character, prop and texture is our own design; never copy characters from other channels or games.

## Format
- Made for **Instagram Reels**: vertical 1080x1920 (9:16), 30 fps, 15 to 60 seconds long (the test films are about 10 seconds). No letterbox bars.
- Keep all text and key action inside the Reels safe zone, because Instagram covers the edges of the screen with its own interface. That means keeping clear of the top 220px, the bottom 440px (caption, username, audio) and about 150px on the right (like, comment and share buttons). The safe zone is `SAFE_REELS` in `src/layout.ts`; wrap each film in `SafeContext.Provider value={SAFE_REELS}` and the overlays position themselves.
- Caesar's voice is a free AI voiceover made with Kokoro (see "Voice"). Sound effects always. No music unless the user asks.
- Everything else is made in code in Remotion: models, textures and sound effects. No AI video, stock footage, downloaded images or downloaded sound effects.

## Writing the lessons
- One lesson per video, with one clear investing idea, such as: diversify, keep fees low, think long-term, don't panic-sell, don't try to time the market, keep an emergency fund, compound interest, pay off high-interest debt first, dollar-cost averaging, avoid hype and get-rich-quick schemes.
- Give sound, general, widely accepted advice only. Never recommend a specific stock, coin or fund by name, never predict prices, and never promise returns. Caesar may give a jokey disclaimer ("I'm not a financial advisor, I'm a god").
- Every lesson has at least one Ancient Rome or Caesar joke that makes the point, for example:
  - **Brutus and the stabbing:** don't trust one stock with everything.
  - **Crossing the Rubicon:** commit and don't panic-sell.
  - **"All Gaul is divided into three parts":** a three-part portfolio.
  - **The Ides of March:** you can't time the market.
  - **Romans paid partly in salt:** saving.
  - **Rome wasn't built in a day:** long-term investing.
  - **Bread and circuses:** hype and distraction.
  - **His baldness, Cleopatra, the Senate, the triumphs, crossing the Alps** (that was Hannibal, so Caesar can be jealous about it).
- Caesar is arrogant, theatrical and impatient. He insults the audience freely ("you fucking idiots", "you absolute plebs", "you sniveling senators") and swears uncensored, but never with slurs or insults about race, religion, gender, sexuality or disability.
- Keep lines short and punchy. Aim for about 2.5 spoken words per second of film, and leave room for slams, pauses and the title card.
- Save each film's script as `voice/<film-id>.json` (see "Voice") so the voice can be regenerated.

## The cast
- **Caesar (the lead):** built by `Voxel` in `src/three/Voxel.tsx` with the Caesar outfit. He has a big cube head and no neck, tan skin, a white toga with a crimson sash, a gold laurel wreath, and a thin hair cap with a bald patch (a running joke). He always holds a wooden ruler. He faces the camera when he talks to the audience, and turns to the student or the board when the joke needs it.
- **The student:** our mustard block figure (`#F2B84B`, darker `#D19A34` limbs), sitting at a desk in the front row. He takes the abuse: he flinches at slams, looks confused, and occasionally gets something right. He never speaks.
- **Faces:** made of small blocks: square dot eyes, a single block for each eyebrow, and a stepped mouth. Most emotion comes from the eyebrows. Caesar's mouth opens and closes in sync with his voice.
- **Limbs:** plain blocks with no hands or fingers.
- **The shadow (optional):** the student's inner voice, used when a lesson is about fear or temptation (panic-selling, FOMO). It's a tall black copy of the student with a glowing violet shell (`#9B5CFF`) and slit eyes. It grows when he's weak.
- Any other character (Brutus, Cleopatra, a senator) is built from the same `Voxel` design with its own colours and items. Never use real modern people or copyrighted characters.

## The classroom
- A bright, daytime classroom built from blocks (`Classroom` in `src/three/Classroom.tsx`). It has cream walls over wooden panelling, a light wood floor, ceiling light panels and sunlight from a window on the left.
- Caesar's desk (with coins, an apple and a scroll) is at the front, and the chalkboard is on the back wall with a strip of Roman-numeral cards above it. The student's desk is in the front row, and there are empty pupils' desks with blue chairs.
- The walls have a ticking clock, an SPQR banner, a pie-chart poster, a marble bust on a pedestal and a bookshelf with a plant. Swap posters or props to suit a lesson, but keep the room recognisable from film to film.
- Everything important sits within about 2.5 blocks of the centre line, so it fits a vertical frame.
- The chalkboard shows the lesson in chalky pixel letters and simple diagrams. Use Roman numerals for lesson numbers.
- Lighting is warm daylight: soft ambient light and bounce light from the sky and floor, one shadow-casting sun through the window, and glowing ceiling panels. Keep it bright and friendly, never dark or gloomy.
- Everything is built from blocks, with pixel textures (8 to 16 pixels square) generated in code in `src/three/textures.ts`. Use nearest-neighbour filtering and seeded `random()`. Never copy a real game's textures, characters or logos, and never name a real game on screen.

## Camera and editing
- Compose every shot for a vertical frame. Keep faces and action in the middle band of the screen, between the safe-zone top and the subtitles.
- Default wide shot: a slightly high camera looking down the classroom. Caesar is behind his desk in the centre with the board above him, and the student is in the bottom-right foreground, seen from behind and to the side.
- Cut to a close-up of Caesar's face for insults and punchlines, using a slow push-in on the big ones.
- Hard cut to a close-up of the chalkboard or a prop when the diagram makes the point. The board is wider than the frame, so frame the part that matters and put pop-up numbers over the rest of the board.
- Cut on the beat of the dialogue: each spoken line or punchline gets its own shot. Montage shots last about 1 second.
- No orbiting or handheld movement. Add a short camera shake only on big ruler slams.

## Voice
- Caesar's voice comes from **Kokoro**, a free, open-source voice model (Apache 2.0 licence, commercial use allowed) that runs locally, so there's no account, no cost and no content filter. Word timings come from **Whisper** (faster-whisper, also free and open source).
- The voice: Kokoro's `bm_george` (deep, mature British male) at speed 0.95. Use the same voice in every film so Caesar always sounds the same. Change it only if the user asks; `--samples` makes comparison clips in `out/voice-samples/`.
- Each film's script lives in `voice/<film-id>.json`: one entry per line, with `text` (what the subtitles show) and an optional `say` (how Kokoro should say it: add "..." for pauses or CAPITALS for emphasis).
- Generate it with `.venv-voice/bin/python scripts/make-voice-kokoro.py voice/<film-id>.json`. This writes the audio to `public/voice/<film-id>/` and the letter and word timings to `src/voice/<film-id>.ts`.
- After generating, transcribe the audio with Whisper to check every word came out right, because you can't hear audio. The user approves how it sounds.
- All timing comes from the generated word timings. Shots, subtitles, mouth movement and ruler slams are lined up to the words, never guessed. Place lines with `placeLines()` and find moments with `findWord()` from `src/voice/sync.ts`.
- One-time setup in a new session: `python3 -m venv .venv-voice && .venv-voice/bin/pip install kokoro-onnx soundfile faster-whisper`, then download `kokoro-v1.0.onnx` and `voices-v1.0.bin` from huggingface.co/fastrtc/kokoro-onnx into `.voice-models/`. The Whisper model downloads itself on first use. Both folders are gitignored.
- Paid upgrade path: `scripts/make-voice.mjs` does the same job with ElevenLabs (more expressive acting) if the user ever adds an ElevenLabs key. It needs a paid plan for commercial use.

## Text
- Font: Pixelify Sans (the `blocky` look in `src/looks.ts`).
- Subtitles: Caesar's words appear centred near the bottom (just above the safe zone's bottom edge), a few words at a time, timed to the voice, uncensored, in normal sentence case (this pixel font's capital C and B are hard to read). The word being spoken is highlighted in crimson.
- The lesson counter sits top left: `LESSON I`, `LESSON II`, and so on.
- The shadow's lines (when used) appear beside it in violet.

## Game feel
- Ruler slams on the desk get a `hit` sound, speed lines, a white flash lasting a frame or two, a squash on Caesar and a flinch from the student.
- Numbers and money pop on screen with a springy overshoot (`RepPop`): stab counts, percentages, coins.
- Every pop, slam, footstep, chalk mark and cut gets a sound effect, timed to the exact frame.

## Animation
- Everything moves smoothly on every frame. Never a slideshow. When nobody is talking, characters still breathe, blink and sway slightly.
- Use squash and stretch on slams, jumps and impacts.
- Animate everything from `useCurrentFrame()` with `interpolate()` and `spring()`. Never use `useFrame()` from React Three Fiber, CSS animations or anything that runs on its own clock, because those flicker in renders.

## Title card (at the end, length chosen per film)
- Choose the length to fit each film so the lesson gets most of the time. As a guide: about 2 to 3 seconds for a 10-second test, about 4 seconds for a 15-second film, 6 to 8 seconds for 30 seconds, and up to 12 seconds for 60 seconds.
- The steps:
  1. The lesson's one word types on letter by letter in big white pixel letters.
  2. A wavy crimson underline draws in.
  3. Optionally one white line, then one short crimson line.
  4. Fade to black.
- Let each line sit on screen for at least a second before the fade.
- Caesar may say the word as it types on.

## Sound effects
- All sound effects are generated in code from maths (oscillators, seeded noise, envelopes) in `scripts/make-sfx.mjs`, so they're 100% original. Only Caesar's voice comes from the AI voice model.
- To add a sound: add a recipe to `scripts/make-sfx.mjs`, run `node scripts/make-sfx.mjs`, and add its name to `SfxName` in `src/components/Sfx.tsx`.
- Place sounds with `<Sfx name="..." at={frame} />`.
- Library: `pop`, `whoosh`, `hit`, `step`, `type`, `alarm`, `drone`, `shimmer`, `hum`, `chalk`, `stab`.
- Keep effects under the voice: room tone about 0.25 volume, effects 0.4 to 0.9, and the voice at full volume.

## Where things live
- `src/films/`: one file per film, each registered in `src/Root.tsx` as a 1080x1920, 30 fps composition.
- `src/three/Voxel.tsx`: every block character (Caesar outfit, student, shadow, any cast).
- `src/three/Classroom.tsx`: the classroom set and chalkboard. `src/three/World.tsx`: shared helpers (`CameraRig`, `Glow3D`) and older sets.
- `src/three/textures.ts`: pixel textures and the pixel font for the chalkboard and screens.
- `src/components/`: 2D overlays on top of the 3D picture (`DayCounter`, `Subtitles`, `RepPop`, `SpeedLines`, `Flash`, `TitleCard`, `Sfx`). Wrap each film in `SafeContext.Provider value={SAFE_REELS}` and in `LookContext.Provider` with the blocky look (crimson accent, as in `CaesarTest.tsx`).
- `voice/`: scripts. `public/voice/`: generated audio. `src/voice/`: generated timings.
- The earlier test films (`TestFilm`, `TestFilm3D` and the 2D looks) are an archive of experiments. Don't use their story for new films.

## Checking and rendering
- Before calling a film done, look at a few frames from every shot (`npx remotion still`), fix anything cut off, overlapping, too dark or outside the safe zone, then render to `out/` with `npx remotion render`, and check the file has sound.
- In the cloud environment add `--gl=swangle --browser-executable=/opt/pw-browsers/chromium` to `still` and `render`. On the user's own computer neither flag is needed.
- The user is not a developer. Explain anything they need to do in simple steps.
