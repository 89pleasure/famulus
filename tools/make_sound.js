// Writes the live feed's sound, a soft double click, to Famulus/Media/click.ogg.
// Node draws the wave; ffmpeg encodes it as Ogg Vorbis, one of the two formats
// the game plays from an addon folder (.ogg and .mp3).
//
//   node tools/make_sound.js [out.ogg]
//
// ffmpeg is looked up on the PATH; FFMPEG=<path> overrides that. The noise is
// seeded and the encoder told to leave out its version, so the same script
// writes the same file. To try other sounds, require this file and call
// make({ ...SOUND, pitch: 670 }, 'try.ogg').

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const RATE = 44100;

// A click is a short knock: a low, round tone with a faint inharmonic
// overtone, like a wood block, dying away within a few hundredths of a
// second, and a breath of noise for the attack. The second click is a whole
// tone higher, so the pair sounds like a soft, friendly "tock-tock" rather
// than a double tap. Chosen by the owner from four tries ("soft", a little
// lower), 2026-11-25.
const SOUND = {
  pitch: 800, // Hz, the first click
  step: 1.1225, // the second click's pitch over the first: a whole tone up
  gap: 0.11, // seconds from the first click to the second
  ring: 0.022, // seconds for the tone to die down to a third
  overtone: 0.15, // the wood block's overtone, at 2.76 times the pitch
  edge: 0.1, // noise at the attack
  edgeRing: 0.0015,
  first: 0.9, // the first click's loudness against the second's
  length: 0.26, // seconds, the tail included
  peak: 0.5, // about -6 dB: a notice, not an alarm
};

function draw(sound) {
  let seed = 1;
  const noise = () => {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    return seed / 1073741824 - 1;
  };
  const clicks = [
    { at: 0, pitch: sound.pitch, gain: sound.first },
    { at: sound.gap, pitch: sound.pitch * sound.step, gain: 1 },
  ];
  const samples = new Float64Array(Math.round(sound.length * RATE));
  for (const click of clicks) {
    const start = Math.round(click.at * RATE);
    let previous = 0;
    for (let i = start; i < samples.length; i++) {
      const t = (i - start) / RATE;
      const attack = Math.min(1, t / 0.0006);
      const body = Math.sin(2 * Math.PI * click.pitch * t) * Math.exp(-t / sound.ring)
        + sound.overtone * Math.sin(2 * Math.PI * click.pitch * 2.76 * t) * Math.exp(-t / (sound.ring / 2));
      // The difference of white noise leans to the highs: a crisp edge, no hiss.
      const white = noise();
      const edge = (white - previous) * 0.5 * Math.exp(-t / sound.edgeRing);
      previous = white;
      samples[i] += click.gain * attack * (body + sound.edge * edge);
    }
  }
  // The last few milliseconds fade to silence, so the end does not click itself.
  const fade = Math.round(0.01 * RATE);
  for (let i = 0; i < fade; i++) {
    samples[samples.length - 1 - i] *= i / fade;
  }
  return samples;
}

// 16-bit mono WAV, peak at sound.peak.
function wav(samples, peak) {
  let loudest = 0;
  for (const sample of samples) {
    loudest = Math.max(loudest, Math.abs(sample));
  }
  const data = Buffer.alloc(44 + samples.length * 2);
  data.write('RIFF', 0);
  data.writeUInt32LE(36 + samples.length * 2, 4);
  data.write('WAVEfmt ', 8);
  data.writeUInt32LE(16, 16);
  data.writeUInt16LE(1, 20); // PCM
  data.writeUInt16LE(1, 22); // mono
  data.writeUInt32LE(RATE, 24);
  data.writeUInt32LE(RATE * 2, 28);
  data.writeUInt16LE(2, 32);
  data.writeUInt16LE(16, 34);
  data.write('data', 36);
  data.writeUInt32LE(samples.length * 2, 40);
  samples.forEach((sample, i) => {
    data.writeInt16LE(Math.round(sample / loudest * peak * 32767), 44 + i * 2);
  });
  return data;
}

function make(sound, out) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'famulus-sound-'));
  const source = path.join(temp, 'click.wav');
  try {
    fs.writeFileSync(source, wav(draw(sound), sound.peak));
    execFileSync(process.env.FFMPEG || 'ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-y',
      '-i', source,
      '-c:a', 'libvorbis', '-q:a', '5',
      '-map_metadata', '-1', '-fflags', '+bitexact', '-flags:a', '+bitexact',
      out,
    ], { stdio: 'inherit' });
  } finally {
    fs.rmSync(temp, { recursive: true, force: true });
  }
  console.log(`${out}: ${fs.statSync(out).size} bytes, ${Math.round(sound.length * 1000)} ms`);
}

module.exports = { SOUND, make };

if (require.main === module) {
  make(SOUND, process.argv[2] || path.join(__dirname, '..', 'Famulus', 'Media', 'click.ogg'));
}
