export type VoiceChar = [string, number, number]; // character, start s, end s
export type VoiceWord = { text: string; start: number; end: number };
export type VoiceLine = {
  id: string;
  text: string;
  src: string | null; // audio file in public/, null for placeholder timings
  duration: number; // seconds
  chars: VoiceChar[];
  words: VoiceWord[];
};
export type VoiceTrack = {
  film: string;
  placeholder: boolean;
  voiceId: string;
  lines: VoiceLine[];
};
