// The landscape: ridges and forests drawn from seeded noise, layer behind
// layer, and a camp of friends at a fire made of hand-drawn silhouettes.
// The picture is generated here, so it is the same on every visit and
// nobody else's artwork is needed. Colours come from CSS (--r1a ...), which
// is how the scene follows its world; fire, sparks and the moon's warmth
// use --fire and --fire2, not the accent, so the fire stays a fire whatever
// the page's accent.
//
//   FamulusScene.moon(host, moon)         the two moons, before build()
//   FamulusScene.aurora(host, sky)        northern lights, after moon()
//   FamulusScene.clouds(host, sky)        clouds lit from below, after moon()
//   FamulusScene.build(host, layers)      adds one <svg class="layer ridge"> per layer
//   FamulusScene.stars(svg, count, seed)
//   FamulusScene.embers(host, count, focus)
//   FamulusScene.snow(host, count)        snowflakes drifting down
//   FamulusScene.pan(scene, x)            keeps x of the drawing in view on narrow screens
//   FamulusScene.parallax(hero)           layers with data-depth follow scroll and pointer;
//                                         returns { refresh } for a scene drawn anew
window.FamulusScene = (() => {
  'use strict';

  const SVG = 'http://www.w3.org/2000/svg';
  const W = 1600;
  const H = 900;
  const MARGIN = 96; // drawn beyond both edges, for layers that shift sideways
  let uid = 0;

  // Small seeded generator (mulberry32): same seed, same landscape.
  function random(seed) {
    let a = seed >>> 0;
    return () => {
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // Smooth one-dimensional noise, 0..1.
  function noise(rand) {
    const size = 256;
    const values = Array.from({ length: size }, rand);
    const at = index => values[((index % size) + size) % size];
    return x => {
      const cell = Math.floor(x);
      const f = x - cell;
      const u = f * f * (3 - 2 * f);
      return at(cell) + (at(cell + 1) - at(cell)) * u;
    };
  }

  function smooth(from, to, x) {
    const t = Math.max(0, Math.min(1, (x - from) / (to - from)));
    return t * t * (3 - 2 * t);
  }

  function node(name, attributes = {}) {
    const element = document.createElementNS(SVG, name);
    for (const [key, value] of Object.entries(attributes)) element.setAttribute(key, value);
    return element;
  }

  // The outline of a ridge: [x, y] every few units.
  //   base    y where the ridge would be flat
  //   amp     how far it rises above that
  //   scale   width of the largest features
  //   sharp   peaks (mountains) instead of rounded hills
  //   valley  { at, width, depth }: the ridge sinks around x = at * W
  function outline(layer) {
    const value = noise(random(layer.seed));
    const points = [];
    for (let x = -MARGIN; x <= W + MARGIN; x += 8) {
      let sum = 0;
      let weight = 0;
      let frequency = 1 / layer.scale;
      let share = 1;
      for (let octave = 0; octave < (layer.octaves || 4); octave++) {
        let v = value(x * frequency + octave * 31.7);
        if (layer.sharp) v = 1 - Math.abs(2 * v - 1);
        sum += v * share;
        weight += share;
        frequency *= 2.1;
        share *= layer.sharp ? 0.46 : 0.42;
      }
      let height = sum / weight;
      if (layer.sharp) height = height ** 1.6;
      if (layer.valley) {
        const distance = (x / W - layer.valley.at) / layer.valley.width;
        height *= 1 - layer.valley.depth * Math.exp(-distance * distance);
      }
      let y = layer.base - layer.amp * height;
      // A level place for a camp: { from, to, y, edge }, exactly level
      // between from and to, so that the camp stands straight, and
      // rounding off into the ridge within `edge` on both sides.
      if (layer.plateau) {
        const { from, to, y: top, edge } = layer.plateau;
        const outside = x < from ? from - x : x > to ? x - to : 0;
        y += (top - y) * (1 - smooth(0, edge, outside));
      }
      points.push([x, y]);
    }
    if (layer.sharp) facet(points, random(layer.seed + 1000));
    return points;
  }

  // Rock instead of dunes: keep the summits, the saddles and a point every
  // now and then, and join them with straight edges.
  function facet(points, rand) {
    const kept = [0];
    let next = points[0][0];
    for (let i = 1; i < points.length - 1; i++) {
      const [x, y] = points[i];
      const turn = (y - points[i - 1][1]) * (points[i + 1][1] - y) <= 0;
      if (x < next && !(turn && x - points[kept[kept.length - 1]][0] >= 16)) continue;
      kept.push(i);
      next = x + 26 + rand() * 44;
    }
    kept.push(points.length - 1);
    for (let k = 0; k < kept.length - 1; k++) {
      const [x0, y0] = points[kept[k]];
      const [x1, y1] = points[kept[k + 1]];
      for (let i = kept[k] + 1; i < kept[k + 1]; i++) {
        points[i][1] = y0 + ((y1 - y0) * (points[i][0] - x0)) / (x1 - x0);
      }
    }
  }

  function heightAt(points, x) {
    const step = points[1][0] - points[0][0];
    const index = Math.max(0, Math.min(points.length - 2, Math.floor((x - points[0][0]) / step)));
    const t = (x - points[index][0]) / step;
    return points[index][1] + (points[index + 1][1] - points[index][1]) * t;
  }

  // Numbers in path data: two decimals are plenty.
  const f = value => Math.round(value * 100) / 100;

  // A circle as path data, drawn clockwise like the ridges and the trees, so
  // that shapes sharing one path add up instead of cutting holes.
  function circle(x, y, r) {
    return ellipse(x, y, r, r);
  }

  function ellipse(x, y, rx, ry) {
    return `M${f(x - rx)} ${f(y)}a${f(rx)} ${f(ry)} 0 1 1 ${f(2 * rx)} 0a${f(rx)} ${f(ry)} 0 1 1 ${f(-2 * rx)} 0Z`;
  }

  // A pine as one closed outline: tiers that widen towards the ground.
  function pine(x, ground, height, width, rand) {
    const tiers = Math.max(3, Math.min(9, Math.round(height / 24)));
    const top = ground - height;
    const right = [];
    const left = [];
    for (let tier = 1; tier <= tiers; tier++) {
      const y = top + (height * tier) / tiers;
      const reach = (width / 2) * (tier / tiers) * (0.82 + rand() * 0.36);
      right.push([x + reach, y]);
      left.push([x - reach * (0.9 + rand() * 0.2), y]);
      if (tier < tiers) {
        const tuck = (height / tiers) * 0.1;
        right.push([x + reach * 0.44, y + tuck]);
        left.push([x - reach * 0.44, y + tuck]);
      }
    }
    const line = points => points.map(([px, py]) => `L${px.toFixed(1)} ${py.toFixed(1)}`).join('');
    return `M${x.toFixed(1)} ${top.toFixed(1)}${line(right)}${line(left.reverse())}Z`;
  }

  // A broadleaf tree, as in the lowland forests: a trunk that forks into a
  // wide, lumpy crown of clumps.
  function broadleaf(x, ground, height, rand) {
    const trunk = height * 0.05;
    const crown = ground - height * 0.64;
    const wide = height * (0.36 + rand() * 0.1);
    const deep = height * 0.22;
    const lean = (rand() - 0.5) * wide * 0.3;
    let d = limb([[x, ground + 2, trunk * 2.4], [x + lean * 0.3, ground - height * 0.3, trunk * 1.5], [x - wide * 0.4, crown + deep * 0.3, trunk * 0.8]]);
    d += limb([[x + lean * 0.3, ground - height * 0.3, trunk * 1.3], [x + wide * 0.45, crown + deep * 0.2, trunk * 0.7]]);
    d += limb([[x + lean * 0.3, ground - height * 0.3, trunk * 1.2], [x + lean, crown - deep * 0.2, trunk * 0.7]]);
    const clumps = 9 + Math.floor(rand() * 5);
    for (let i = 0; i < clumps; i++) {
      const angle = rand() * Math.PI * 2;
      const reach = Math.sqrt(rand());
      const cy = crown + Math.sin(angle) * deep * 0.75 * reach;
      // Smaller clumps hang at the bottom of the crown, larger ones on top.
      const r = deep * (0.42 + rand() * 0.3) * (cy > crown + deep * 0.3 ? 0.7 : 1);
      d += circle(x + lean + Math.cos(angle) * wide * 0.78 * reach, cy, r);
    }
    return d;
  }

  // A bush: a few clumps side by side, the middle ones larger.
  function bush(x, ground, size, rand) {
    let d = '';
    const clumps = 3 + Math.floor(rand() * 3);
    for (let i = 0; i < clumps; i++) {
      const share = i / (clumps - 1) - 0.5;
      const r = size * (0.34 + rand() * 0.2) * (1 - Math.abs(share) * 0.7);
      d += circle(x + share * size * 1.5 + (rand() - 0.5) * size * 0.2, ground - r * 0.6, r);
    }
    return d;
  }

  // Tufts of grass along a ridge, a few thin blades each.
  function grass(points, { gap, height }, rand) {
    let d = '';
    for (let x = -MARGIN + rand() * gap[1]; x < W + MARGIN; x += gap[0] + rand() * (gap[1] - gap[0])) {
      const ground = heightAt(points, x) + 1.5;
      const blades = 2 + Math.floor(rand() * 3);
      for (let b = 0; b < blades; b++) {
        const tall = height[0] + rand() * (height[1] - height[0]);
        const base = x + (b - blades / 2) * 1.8;
        const lean = (rand() - 0.5) * tall * 0.7;
        d += `M${f(base - 1)} ${f(ground)}L${f(base + lean)} ${f(ground - tall)}L${f(base + 1)} ${f(ground)}Z`;
      }
    }
    return d;
  }

  // An ancient tree, as in the old elven forests: a massive trunk on spread
  // roots, rising far above the forest, its crown in flat tiers that widen
  // downwards, each on branches of its own.
  function ancient(x, ground, height, rand) {
    const trunk = height * 0.055;
    const top = ground - height;
    const lean = (rand() - 0.5) * height * 0.1;
    // Roots spread like the feet of a tent.
    let d = `M${f(x - trunk * 3.4)} ${f(ground + 3)}C${f(x - trunk * 1.4)} ${f(ground - trunk * 0.3)} ${f(x - trunk * 0.9)} ${f(ground - trunk * 1.6)} ${f(x - trunk * 0.62)} ${f(ground - trunk * 3.4)}`;
    d += `L${f(x + trunk * 0.62)} ${f(ground - trunk * 3.4)}C${f(x + trunk * 0.9)} ${f(ground - trunk * 1.6)} ${f(x + trunk * 1.4)} ${f(ground - trunk * 0.3)} ${f(x + trunk * 3.4)} ${f(ground + 3)}Z`;
    d += limb([[x, ground - trunk * 2, trunk * 1.3], [x + lean * 0.3, ground - height * 0.42, trunk], [x + lean, top + height * 0.12, trunk * 0.45]]);
    const tiers = 3;
    for (let t = 0; t < tiers; t++) {
      const ty = top + height * (0.09 + t * 0.15);
      const span = height * (0.14 + t * 0.09) * (0.85 + rand() * 0.3);
      const at = x + lean * (1 - (t + 1) * 0.22);
      const fork = ty + height * 0.07;
      d += limb([[at, fork, trunk * 0.5], [at - span * 0.62, ty + height * 0.012, trunk * 0.2]]);
      d += limb([[at, fork + height * 0.02, trunk * 0.46], [at + span * 0.66, ty + height * 0.016, trunk * 0.2]]);
      const clumps = 6 + Math.floor(rand() * 3);
      for (let i = 0; i < clumps; i++) {
        const share = (i / (clumps - 1)) * 2 - 1;
        const r = height * 0.036 * (1.15 - Math.abs(share) * 0.45) * (0.8 + rand() * 0.4);
        d += ellipse(at + share * span, ty - (1 - share * share) * height * 0.02 + (rand() - 0.5) * r * 0.5, r * 1.7, r * 0.78);
      }
    }
    return d;
  }

  // A world tree far off on the horizon: a trunk as wide as a mountain on a
  // flared foot of roots, great boughs spreading from the fork, and a crown
  // like a range of clouds. Foot and roots reach far below `ground`, so that
  // no edge of them shows where the ridge falls away beside the trunk.
  function worldtree(x, ground, height, rand) {
    const foot = height * 0.12;
    const waist = height * 0.05;
    const fork = ground - height * 0.5;
    const crown = ground - height * 0.78;
    const span = height * 0.56;
    const deep = ground + height * 0.3;
    let d = `M${f(x - foot * 1.7)} ${f(deep)}L${f(x - foot * 1.7)} ${f(ground + 4)}C${f(x - foot * 0.5)} ${f(ground - foot * 0.25)} ${f(x - waist * 1.5)} ${f(ground - height * 0.12)} ${f(x - waist)} ${f(ground - height * 0.3)}`;
    d += `L${f(x - waist * 0.85)} ${f(fork)}L${f(x + waist * 0.85)} ${f(fork)}L${f(x + waist)} ${f(ground - height * 0.3)}`;
    d += `C${f(x + waist * 1.5)} ${f(ground - height * 0.12)} ${f(x + foot * 0.5)} ${f(ground - foot * 0.25)} ${f(x + foot * 1.7)} ${f(ground + 4)}L${f(x + foot * 1.7)} ${f(deep)}Z`;
    d += limb([[x - waist * 0.8, ground - height * 0.06, waist * 0.9], [x - foot * 1.1, ground - foot * 0.1, waist * 0.5], [x - foot * 2.3, ground + 3, waist * 0.2], [x - foot * 2.6, deep, waist * 0.2]]);
    d += limb([[x + waist * 0.8, ground - height * 0.05, waist * 0.8], [x + foot * 1.2, ground - foot * 0.05, waist * 0.45], [x + foot * 2.1, ground + 3, waist * 0.2], [x + foot * 2.4, deep, waist * 0.2]]);
    // Boughs that curve up and out and end inside the crown.
    for (const [reach, rise, weight] of [[-0.95, 0.1, 0.55], [-0.5, -0.05, 0.7], [-0.05, -0.16, 0.7], [0.45, -0.06, 0.65], [0.9, 0.12, 0.5]]) {
      const end = crown + height * (0.05 + rise * 0.3);
      d += limb([[x, fork + height * 0.04, waist * 1.6 * weight], [x + reach * span * 0.3, fork - height * 0.08, waist * 1.1 * weight], [x + reach * span * 0.62, end + height * 0.03, waist * 0.7 * weight], [x + reach * span * 0.8, end, waist * 0.35 * weight]]);
    }
    // The crown: a tall dome of clumps, the largest in the middle.
    for (let i = 0; i < 110; i++) {
      const share = rand() * 2 - 1;
      const dome = Math.sqrt(1 - share * share);
      const r = height * (0.032 + rand() * 0.04) * (1 - Math.abs(share) * 0.4);
      d += circle(x + share * span, crown - dome * height * (0.06 + rand() * 0.16) + height * 0.06, r);
    }
    // Clumps hanging lower at the rim, where the boughs end.
    for (let i = 0; i < 22; i++) {
      const share = (rand() < 0.5 ? -1 : 1) * (0.35 + rand() * 0.6);
      d += circle(x + share * span * 0.92, crown + height * (0.06 + rand() * 0.07), height * (0.022 + rand() * 0.025));
    }
    return d;
  }

  // Trees along a ridge.
  //   gap     [from, to] between two trees
  //   height  [from, to]
  //   clump   width of the patches they grow in (none: everywhere)
  //   frame   [from, to]: trees grow from small to tall between these
  //           distances from the middle (0) to the edge (1), so the tall
  //           ones frame the picture and leave its middle open
  //   clear   [from, to]: no trees between these x, room for a camp
  //   broad   share of broadleaf trees among the pines
  //   bushes  share of bushes
  //   giants  [[x, height, kind], ...]: ancient trees standing above the
  //           others; kind 'world' for a world tree
  function forest(points, layer) {
    const { gap, height, clump, frame, clear, broad = 0, bushes = 0, giants = [] } = layer.trees;
    const rand = random(layer.seed * 7 + 3);
    const patch = clump ? noise(random(layer.seed * 13 + 1)) : null;
    let d = '';
    let x = -MARGIN;
    while (x < W + MARGIN) {
      x += gap[0] + rand() * (gap[1] - gap[0]);
      let size = 0.25 + rand() * 0.75;
      if (patch && patch(x / clump) < 0.46) continue;
      if (clear && x > clear[0] && x < clear[1]) continue;
      if (frame) {
        const grow = smooth(frame[0], frame[1], Math.abs(x / W - 0.5) * 2);
        if (grow < 0.04 && rand() < 0.8) continue;
        size *= 0.12 + grow * 0.88;
      }
      const tall = height[0] + size * (height[1] - height[0]);
      const ground = heightAt(points, x);
      // (Asked only where there is a choice, so older ridges keep their trees.)
      const pick = broad || bushes ? rand() : 1;
      if (pick < bushes) d += bush(x, ground + 2, tall * 0.4, rand);
      else if (pick < bushes + broad) d += broadleaf(x, ground + tall * 0.04, tall * 0.9, rand);
      else d += pine(x, ground + tall * 0.08, tall, tall * (0.34 + rand() * 0.14), rand);
    }
    const old = random(layer.seed * 17 + 5);
    for (const [gx, tall, kind] of giants) {
      // Rooted where the ground is lowest under its foot, so it stands in
      // the ridge rather than on its crest.
      let ground = 0;
      for (let dx = -0.2; dx <= 0.2; dx += 0.05) ground = Math.max(ground, heightAt(points, gx + dx * tall));
      d += (kind === 'world' ? worldtree : ancient)(gx, ground + 6, tall, old);
    }
    return d;
  }

  // Adds the layers to `host`, far to near, before `host`'s embers if it has
  // any. Returns [{ svg, points, layer, camp }].
  //   tone    1 (far, light and hazy) .. 5 (the ground of the page): --r<tone>a / --r<tone>b
  //   depth   for the parallax: 0 never moves, 1 scrolls with the page
  //   fire    x of a warm glow behind this ridge
  //   plateau { from, to, y, edge }: level ground for a camp
  //   grass   { gap, height }: tufts along the ridge
  //   bushes  [[x, size], ...]
  //   cast    [{ figure, x, scale, facing, sink }]: figures standing on the
  //           ridge (a tower, a castle), sink: how far into the ground
  //   float   [{ figure, x, y, scale, facing }]: figures in the air that bob
  //           (islands)
  //   mist    { y, height, opacity, puffs: [[x, y, rx, ry]] }: a band of mist
  //           behind this ridge
  //   snow    { line, depth, seed }: snow on everything above y = line, with
  //           a ragged edge `depth` deep
  //   camp    a camp on this ridge (see camp())
  //   flies   fireflies over it (see fireflies())
  function build(host, layers) {
    const before = host.querySelector('.scene__embers');
    return layers.map(layer => {
      const points = outline(layer);
      const top = Math.min(...points.map(point => point[1]));
      let d = `M${-MARGIN} ${H + 40}`;
      for (const [x, y] of points) d += `L${x} ${y.toFixed(1)}`;
      d += `L${W + MARGIN} ${H + 40}Z`;
      if (layer.trees) d += forest(points, layer);
      const rand = random(layer.seed * 5 + 11);
      for (const [x, size] of layer.bushes || []) d += bush(x, heightAt(points, x) + 2, size, rand);
      if (layer.grass) d += grass(points, layer.grass, rand);

      const svg = node('svg', {
        class: 'layer ridge',
        viewBox: `0 0 ${W} ${H}`,
        preserveAspectRatio: 'xMidYMax slice',
        focusable: 'false',
      });
      if (layer.depth != null) svg.dataset.depth = layer.depth;

      // Each ridge grows hazier towards its foot, where the next one rises.
      const id = `ridge-${++uid}`;
      const foot = Math.min(H, layer.base + (layer.haze || 120));
      const haze = [[0, `var(--r${layer.tone}a)`], [1, `var(--r${layer.tone}b)`]];
      const defs = node('defs');
      defs.append(gradient('linear', id, { gradientUnits: 'userSpaceOnUse', x1: 0, y1: top.toFixed(0), x2: 0, y2: foot }, haze));
      svg.append(defs);

      if (layer.fire != null) {
        defs.append(gradient('radial', `fire-${uid}`, {}, [[0, 'var(--fire)', 0.5], [0.35, 'var(--fire)', 0.16], [1, 'var(--fire)', 0]]));
        svg.append(node('ellipse', {
          cx: layer.fire,
          cy: heightAt(points, layer.fire) + 6,
          rx: 230,
          ry: 150,
          fill: `url(#fire-${uid})`,
        }));
      }

      if (layer.mist) mist(svg, defs, layer.mist);
      svg.append(node('path', { d, fill: `url(#${id})` }));
      if (layer.snow) snowcap(svg, defs, points, top, layer);
      const built = { svg, points, layer };
      const lit = ++uid;
      if (layer.cast || layer.float) lightDefs(defs, lit);
      // What stands on the ridge takes on its haze, so that a rock under a
      // castle runs into the slope without a seam. (The gradient lies in the
      // figure's own units, inside its transform.)
      for (const member of layer.cast || []) {
        const facing = member.facing || 1;
        const k = member.scale || 1;
        const y = heightAt(points, member.x) + (member.sink ?? 1);
        const { body, lights } = figure(FIGURES[member.figure], member.x, y, k, facing, lit);
        const fill = `${id}-${++uid}`;
        defs.append(gradient('linear', fill, { gradientUnits: 'userSpaceOnUse', x1: 0, y1: f((top - y) / k), x2: 0, y2: f((foot - y) / k) }, haze));
        body.setAttribute('fill', `url(#${fill})`);
        body.style.color = `var(--r${layer.tone}a)`;
        svg.append(body);
        if (lights) svg.append(lights);
      }
      (layer.float || []).forEach((member, index) => {
        const bob = node('g', { class: 'bob' });
        bob.style.animationDelay = `${-index * 3.7}s`;
        const { body, lights } = figure(FIGURES[member.figure], member.x, member.y, member.scale || 1, member.facing || 1, lit);
        body.style.color = `var(--r${member.tone || layer.tone}a)`;
        bob.append(body);
        if (lights) bob.append(lights);
        svg.append(bob);
      });
      if (layer.camp) built.camp = camp(built, layer.camp);
      if (layer.flies) fireflies(built, layer.flies);
      host.insertBefore(svg, before);
      return built;
    });
  }

  // kind: 'linear' or 'radial'; stops: [offset, colour, opacity = 1].
  function gradient(kind, id, attributes, stops) {
    const element = node(`${kind}Gradient`, { id, ...attributes });
    for (const [offset, color, opacity = 1] of stops) {
      const stop = node('stop', { offset });
      stop.style.stopColor = color;
      stop.style.stopOpacity = opacity;
      element.append(stop);
    }
    return element;
  }

  // The lights figures carry (see figure()): 'fire' in the fire's colours
  // (--fire, --fire2), 'magic' in the world's own (--magic, --magic2),
  // beams and water.
  function lightDefs(defs, id) {
    defs.append(
      gradient('radial', `spark-${id}`, {}, [[0, 'var(--fire2)', 0.75], [0.3, 'var(--fire)', 0.22], [1, 'var(--fire)', 0]]),
      gradient('radial', `magic-${id}`, {}, [[0, 'var(--magic2)', 0.8], [0.3, 'var(--magic)', 0.26], [1, 'var(--magic)', 0]]),
      gradient('linear', `beam-${id}`, { x1: 0, y1: 1, x2: 0, y2: 0 }, [[0, 'var(--magic2)', 0.6], [0.2, 'var(--magic)', 0.22], [1, 'var(--magic)', 0]]),
      gradient('linear', `fall-${id}`, { x1: 0, y1: 0, x2: 0, y2: 1 }, [[0, 'var(--water)', 0.8], [0.6, 'var(--water)', 0.32], [1, 'var(--water)', 0]]),
    );
  }

  // A band of mist, and puffs of it, behind a ridge.
  function mist(svg, defs, { y, height, opacity = 0.4, puffs = [] }) {
    const id = ++uid;
    defs.append(
      gradient('linear', `mist-${id}`, { x1: 0, y1: 0, x2: 0, y2: 1 }, [[0, 'var(--mist)', 0], [0.55, 'var(--mist)', opacity], [1, 'var(--mist)', 0]]),
      gradient('radial', `puff-${id}`, {}, [[0, 'var(--mist)', opacity * 1.1], [1, 'var(--mist)', 0]]),
    );
    svg.append(node('rect', { x: -MARGIN, y: y - height / 2, width: W + 2 * MARGIN, height, fill: `url(#mist-${id})` }));
    for (const [px, py, rx, ry] of puffs) svg.append(node('ellipse', { cx: px, cy: py, rx, ry, fill: `url(#puff-${id})` }));
  }

  // Snow on the peaks: the ridge once more in white, cut off below a ragged
  // line that runs down in streaks, as snow lies in the gullies.
  function snowcap(svg, defs, points, top, { seed, snow: { line, depth = 40 } }) {
    const id = ++uid;
    const broad = noise(random(seed * 3 + 1));
    const streak = noise(random(seed * 3 + 2));
    let edge = `M${-MARGIN} -10`;
    for (let x = -MARGIN; x <= W + MARGIN; x += 5) {
      const y = line + (broad(x / 60) - 0.5) * depth * 1.6 + streak(x / 16) ** 5 * depth * 0.9 + (streak(x / 3 + 70) - 0.5) * depth * 0.12;
      edge += `L${x} ${f(y)}`;
    }
    edge += `L${W + MARGIN} -10Z`;
    const clip = node('clipPath', { id: `snowline-${id}` });
    clip.append(node('path', { d: edge }));
    defs.append(clip, gradient('linear', `snow-${id}`, {
      gradientUnits: 'userSpaceOnUse', x1: 0, y1: f(top), x2: 0, y2: f(line + depth),
    }, [[0, 'var(--snow)', 0.95], [1, 'var(--snow)', 0.35]]));
    let d = `M${-MARGIN} ${H + 40}`;
    for (const [x, y] of points) d += `L${x} ${f(y)}`;
    d += `L${W + MARGIN} ${H + 40}Z`;
    svg.append(node('path', { d, fill: `url(#snow-${id})`, 'clip-path': `url(#snowline-${id})` }));
  }

  // The moons, drawn in the landscape's own units so they stay where the
  // drawing puts them at every window size. Azeroth has two: a large white
  // one and a small blue one. Bats cross the large one.
  //   { x, y, r, depth, small: { x, y, r }, bats: [[x, y, size], ...],
  //     dragons: [[x, y, size], ...] }
  // Call before build(), so the ridges come in front.
  function moon(host, { x, y, r, depth, small, bats = [], dragons = [] }) {
    const id = ++uid;
    const svg = node('svg', {
      class: 'layer ridge moon-sky',
      viewBox: `0 0 ${W} ${H}`,
      preserveAspectRatio: 'xMidYMax slice',
      focusable: 'false',
    });
    if (depth != null) svg.dataset.depth = depth;
    const defs = node('defs');
    defs.append(
      gradient('radial', `halo-${id}`, {}, [[0, 'var(--halo-in, var(--fire2))', 0.34], [0.32, 'var(--halo-out, var(--fire))', 0.12], [1, 'var(--halo-out, var(--fire))', 0]]),
      gradient('radial', `disc-${id}`, { cx: 0.36, cy: 0.34, r: 0.72 }, [[0, '#fff'], [0.55, 'var(--moon-mid)'], [1, 'var(--moon-rim)']]),
      gradient('radial', `blue-${id}`, { cx: 0.36, cy: 0.34, r: 0.72 }, [[0, '#fff'], [1, 'var(--moon-blue)']]),
      gradient('radial', `blue-halo-${id}`, {}, [[0, 'var(--moon-blue)', 0.4], [1, 'var(--moon-blue)', 0]]),
    );
    svg.append(defs);
    svg.append(node('circle', { cx: x, cy: y, r: r * 3.4, fill: `url(#halo-${id})` }));
    svg.append(node('circle', { cx: x, cy: y, r, fill: `url(#disc-${id})` }));
    if (small) {
      svg.append(node('circle', { cx: small.x, cy: small.y, r: small.r * 2.6, fill: `url(#blue-halo-${id})` }));
      svg.append(node('circle', { cx: small.x, cy: small.y, r: small.r, fill: `url(#blue-${id})` }));
    }
    // A bat: placed by the outer <g>, carried across by the middle one, and
    // beating its wings in the inner one (CSS; transforms of their own).
    bats.forEach(([bx, by, size], index) => {
      const at = node('g', { transform: `translate(${bx} ${by}) scale(${size})` });
      const flight = node('g', { class: 'bat' });
      flight.style.animationDelay = `${(-index * 4.5).toFixed(1)}s`;
      const wings = node('path', {
        class: 'bat__wings',
        d: 'M0 -1C-3 -4 -7 -6 -13 -4C-11 -2 -12 0 -13 2C-10 0 -8 1 -7 3C-5 1 -2 1 0 3C2 1 5 1 7 3C8 1 10 0 13 2C12 0 11 -2 13 -4C7 -6 3 -4 0 -1Z',
      });
      wings.style.animationDelay = `${(-index * 0.17).toFixed(2)}s`;
      const body = node('path', { d: 'M-1.6 -1L-1.8 -4.4L-0.6 -2.6L0.6 -2.6L1.8 -4.4L1.6 -1L1.4 3L-1.4 3Z' });
      flight.append(wings, body);
      flight.style.fill = 'var(--figure)';
      at.append(flight);
      svg.append(at);
    });
    // A dragon far off, gliding across with slow beats of its wings: the far
    // wing behind the body, the near one in front. Looks left.
    dragons.forEach(([dx, dy, size], index) => {
      const at = node('g', { transform: `translate(${dx} ${dy}) scale(${size})` });
      const flight = node('g', { class: 'dragon' });
      flight.style.animationDelay = `${(-14 - index * 23).toFixed(1)}s`;
      const far = node('g', { transform: 'translate(7 -1) scale(0.86)' });
      far.append(node('path', { class: 'dragon__wing', d: DRAGON.wing }));
      flight.append(far, node('path', { d: DRAGON.body }), node('path', { class: 'dragon__wing', d: DRAGON.wing }));
      flight.style.fill = 'var(--figure)';
      at.append(flight);
      svg.append(at);
    });
    host.insertBefore(svg, host.querySelector('.ridge') || host.querySelector('.scene__embers'));
    return svg;
  }

  // The dragon's silhouette, looking left: a long neck, horns, a tail with a
  // spade at its end, legs drawn in; the wing is a membrane between fingers.
  const DRAGON = {
    body: [
      'M-20 -2C-12 -8 8 -9 24 -4C30 -1 28 3 16 6C2 8 -12 7 -18 4Z',
      'M-17 -3C-26 -6 -34 -10 -42 -13C-48 -16 -54 -16 -60 -13L-68 -10C-62 -8 -56 -7 -50 -7C-42 -6 -32 -2 -20 3Z',
      'M-50 -14L-44 -24L-47 -14ZM-46 -14L-37 -21L-43 -13Z',
      'M22 -3C36 -2 50 4 66 3C78 2 88 -3 96 -3L106 -8L103 -1L108 5L96 1C86 3 76 7 64 8C48 9 34 4 20 3Z',
      'M14 4L20 12L28 13L20 10L18 4ZM-8 5L-6 12L0 14L-3 10L-4 5Z',
    ].join(''),
    wing: 'M-8 -5L-16 -34L-34 -66Q-22 -54 -12 -58L-4 -62Q0 -50 7 -48L18 -53Q16 -42 20 -36L33 -37Q24 -26 22 -18L14 -5Z',
  };

  // Fireflies over a stretch of a ridge: dots that wander and glow, CSS only.
  //   { from, to, count, seed, height }
  function fireflies({ svg, points }, { from, to, count, seed, height = 60 }) {
    const rand = random(seed);
    const swarm = node('g', { class: 'flies' });
    for (let i = 0; i < count; i++) {
      const x = from + rand() * (to - from);
      const fly = node('circle', {
        class: 'fly',
        cx: f(x),
        cy: f(heightAt(points, x) - 8 - rand() * height),
        r: f(1.1 + rand() * 0.9),
      });
      fly.style.cssText = [
        `--dx:${f((rand() - 0.5) * 40)}px`,
        `--dy:${f(-6 - rand() * 22)}px`,
        `animation-duration:${f(6 + rand() * 7)}s,${f(2 + rand() * 3)}s`,
        `animation-delay:${f(-rand() * 12)}s,${f(-rand() * 5)}s`,
      ].join(';');
      swarm.append(fly);
    }
    svg.append(swarm);
  }

  // A sheet of the sky in front of the moon and behind the ridges, in the
  // drawing's units: a <div class="layer world"> (for the parallax) holding
  // one <svg> per part, each in a <div> of its own that CSS can move cheaply.
  function sheet(host, depth, name) {
    const wrap = document.createElement('div');
    wrap.className = `layer world ${name}`;
    if (depth != null) wrap.dataset.depth = depth;
    // Behind the ridges, in front of the moon.
    const moonSvg = [...host.children].find(child => child.classList.contains('moon-sky'));
    host.insertBefore(wrap, moonSvg ? moonSvg.nextSibling : host.querySelector('.ridge') || host.querySelector('.scene__embers'));
    return part => {
      const holder = document.createElement('div');
      holder.className = `${name}__part`;
      const svg = node('svg', { class: 'layer ridge', viewBox: `0 0 ${W} ${H}`, preserveAspectRatio: 'xMidYMax slice', focusable: 'false' });
      const defs = node('defs');
      svg.append(defs);
      holder.append(svg);
      wrap.append(holder);
      if (part) holder.style.animationDelay = `${part}s`;
      return { svg, defs };
    };
  }

  // Northern lights: curtains of light across the sky, each a row of thin
  // strips that fade upwards, softened by a blur. Each curtain sways on its
  // own (CSS: .aurora__part).
  //   { depth, bands: [{ y, amp, height, seed, color, from, to, blur }] }
  function aurora(host, { depth, bands }) {
    const add = sheet(host, depth, 'aurora');
    bands.forEach((band, index) => {
      const { svg, defs } = add(-index * 6.5);
      const id = ++uid;
      defs.append(gradient('linear', `curtain-${id}`, { x1: 0, y1: 1, x2: 0, y2: 0 }, [[0, band.color, 0.9], [0.14, band.color, 0.55], [0.5, band.color, 0.16], [1, band.color, 0]]));
      const blur = node('filter', { id: `soft-${id}`, x: '-5%', y: '-20%', width: '110%', height: '140%' });
      blur.append(node('feGaussianBlur', { stdDeviation: band.blur || 2.4 }));
      defs.append(blur);
      const curtain = node('g', { filter: `url(#soft-${id})`, fill: `url(#curtain-${id})` });
      const course = noise(random(band.seed));
      const fold = noise(random(band.seed + 7));
      const from = band.from ?? -MARGIN;
      const to = band.to ?? W + MARGIN;
      for (let x = from; x < to; x += 4) {
        const y = band.y + (course(x / 300) - 0.5) * band.amp * 2 + (course(x / 60 + 40) - 0.5) * band.amp * 0.3;
        const tall = band.height * (0.4 + fold(x / 34) * 0.8);
        const fade = smooth(from, from + 260, x) * (1 - smooth(to - 260, to, x));
        const strip = node('rect', { x: f(x), y: f(y - tall), width: 4.6, height: f(tall) });
        strip.style.opacity = f(fade * (0.2 + fold(x / 13 + 9) ** 1.5 * 0.8));
        curtain.append(strip);
      }
      svg.append(curtain);
    });
  }

  // Long clouds, dark above and lit from below by a low sun; they drift a
  // little (CSS: .clouds__part).
  //   { depth, clouds: [[x, y, width, height, seed], ...] }
  function clouds(host, { depth, clouds: list }) {
    const add = sheet(host, depth, 'clouds');
    list.forEach(([cx, cy, width, height, seed], index) => {
      const { svg, defs } = add(-index * 11);
      const id = ++uid;
      defs.append(gradient('linear', `cloud-${id}`, { x1: 0, y1: 0, x2: 0, y2: 1 }, [[0, 'var(--cloud)', 0.15], [0.45, 'var(--cloud)', 0.7], [0.82, 'var(--cloud-lit)', 0.85], [1, 'var(--cloud-rim)', 0.95]]));
      const rand = random(seed);
      // Puffs along a long streak, thinning towards both ends, on a thin foot.
      let d = '';
      const puffs = 8 + Math.floor(rand() * 5);
      for (let i = 0; i < puffs; i++) {
        const share = (i / (puffs - 1)) * 2 - 1;
        const taper = 1 - Math.abs(share) ** 1.5 * 0.75;
        const rx = width * (0.06 + rand() * 0.07);
        const ry = height * (0.4 + rand() * 0.5) * taper;
        d += ellipse(cx + share * width * 0.44 + (rand() - 0.5) * width * 0.04, cy - ry * 0.4 + (rand() - 0.5) * height * 0.25, rx, ry);
      }
      d += ellipse(cx + (rand() - 0.5) * width * 0.1, cy + height * 0.12, width * 0.5, height * 0.16);
      const blur = node('filter', { id: `haze-${id}`, x: '-5%', y: '-50%', width: '110%', height: '200%' });
      blur.append(node('feGaussianBlur', { stdDeviation: 1.4 }));
      defs.append(blur);
      svg.append(node('path', { d, fill: `url(#cloud-${id})`, filter: `url(#haze-${id})` }));
    });
  }

  // ---------------------------------------------------------------------------
  // Figures: friends at the fire, the wolf, an old tree, and what stands
  // in the worlds around them (a tower, a castle, islands).
  //
  // Each is a dark silhouette made of a few parts. Units: a standing person is
  // 100 tall, the ground is y = 0, and the figure looks to the right (x > 0),
  // where the fire is.
  //   ['blob', points]          a smooth outline through the points; a point
  //                             [x, y, 1] is a tip (an ear, a horn, a hat)
  //   ['poly', points]          straight edges
  //   ['limb', [[x, y, w], ...]] an arm or a leg that tapers, round at the joints
  //   ['circle', x, y, r]
  //   ['line', points, width]   a staff, a haft, a string
  //   ['curve', d, width]       a bow
  //   ['path', d]
  //   ['glow', x, y, r, name, light]  a light of its own: a crystal, an owl's
  //                             eyes; name: a class for it, to animate it
  //                             (CSS); light: 'fire' (default) or 'magic'
  //   ['lit', points, opacity, light, name]  light inside, as in a window;
  //                             name: a class for it, as for 'glow'
  //   ['flag', x, y, size]      a pennant on a pole at (x, y), waving (CSS)
  //   ['beam', x, y, width, height]  a shaft of magic light rising
  //   ['fall', x, y, width, height]  water falling from (x, y)
  // ---------------------------------------------------------------------------

  // A smooth closed outline through points (Catmull-Rom as cubic Béziers).
  function blob(points) {
    const n = points.length;
    const at = i => points[(i + n) % n];
    const pull = i => {
      if (at(i)[2]) return [0, 0];
      return [(at(i + 1)[0] - at(i - 1)[0]) / 6, (at(i + 1)[1] - at(i - 1)[1]) / 6];
    };
    let d = `M${f(at(0)[0])} ${f(at(0)[1])}`;
    for (let i = 0; i < n; i++) {
      const [x0, y0] = at(i);
      const [x1, y1] = at(i + 1);
      const [ax, ay] = pull(i);
      const [bx, by] = pull(i + 1);
      d += `C${f(x0 + ax)} ${f(y0 + ay)} ${f(x1 - bx)} ${f(y1 - by)} ${f(x1)} ${f(y1)}`;
    }
    return `${d}Z`;
  }

  function poly(points) {
    return `M${points.map(([x, y]) => `${f(x)} ${f(y)}`).join('L')}Z`;
  }

  // A tapering limb: a round end at every joint and a band between, all
  // clockwise so that they add up within one path.
  function limb(joints) {
    let d = '';
    joints.forEach(([x, y, w], i) => {
      d += circle(x, y, w / 2);
      if (!i) return;
      const [px, py, pw] = joints[i - 1];
      const length = Math.hypot(x - px, y - py) || 1;
      const nx = -(y - py) / length;
      const ny = (x - px) / length;
      let band = [[px + (nx * pw) / 2, py + (ny * pw) / 2], [x + (nx * w) / 2, y + (ny * w) / 2], [x - (nx * w) / 2, y - (ny * w) / 2], [px - (nx * pw) / 2, py - (ny * pw) / 2]];
      const area = band.reduce((sum, [ax, ay], k) => sum + ax * band[(k + 1) % 4][1] - band[(k + 1) % 4][0] * ay, 0);
      if (area < 0) band = band.reverse();
      d += poly(band);
    });
    return d;
  }

  // A head in profile, looking right, around (x, y): r about 7 times s.
  function head(x, y, s = 1) {
    const outline = [[-6.5, -1], [-5.5, -6], [-1.5, -9], [3.5, -8], [6, -5], [6.3, -2], [8.8, 0.2, 1], [6.4, 1.6], [6.6, 3.6], [4, 6.6], [0, 7], [-4.6, 4.6]];
    return ['blob', outline.map(([px, py, tip]) => [x + px * s, y + py * s, tip])];
  }

  // An owl seen from the front, sitting at (x, y), with glowing eyes that
  // blink now and then (CSS: .blink).
  function owl(x, y) {
    const at = points => points.map(([px, py, tip]) => [x + px, y + py, tip]);
    return [
      ['blob', at([[0, -17], [-5, -15.5], [-7, -9], [-6.5, -3], [-3, 0], [3, 0], [6.5, -3], [7, -9], [5, -15.5]])],
      ['poly', at([[-5, -14], [-6.5, -20.5], [-2, -16]])],
      ['poly', at([[5, -14], [6.5, -20.5], [2, -16]])],
      ['poly', at([[-2, 0], [0, 4], [2, 0]])],
      ['glow', x - 2.4, y - 12, 0.9, 'blink'],
      ['glow', x + 2.4, y - 12, 0.9, 'blink'],
    ];
  }

  // A pointed window or door, its sill at y: w wide, h tall.
  function arch(x, y, w, h) {
    return [[x - w / 2, y], [x - w / 2, y - h + w * 0.6], [x, y - h], [x + w / 2, y - h + w * 0.6], [x + w / 2, y]];
  }

  // A round arch, its sill at y: w wide, h tall.
  function round(x, y, w, h) {
    const points = [[x - w / 2, y]];
    for (let i = 0; i <= 12; i++) {
      const angle = Math.PI - (i / 12) * Math.PI;
      points.push([x + (Math.cos(angle) * w) / 2, y - h + w / 2 - (Math.sin(angle) * w) / 2]);
    }
    points.push([x + w / 2, y]);
    return points;
  }

  // A wall from x0 to x1 with merlons on top: its walk at y, a merlon about
  // `size` wide, the wall's foot at `foot`.
  function crenels(x0, x1, y, size, foot = 2) {
    let n = Math.max(3, Math.round((x1 - x0) / size));
    if (n % 2 === 0) n += 1;
    const step = (x1 - x0) / n;
    const points = [[x0, foot]];
    for (let i = 0; i < n; i++) {
      const top = i % 2 ? y : y - step * 0.9;
      points.push([x0 + i * step, top], [x0 + (i + 1) * step, top]);
    }
    points.push([x1, foot]);
    return points;
  }

  // A round tower seen from the side: w wide, its wall h tall, a steep
  // roof that flares at the eaves, and a pennant if flag is its size.
  function spire(x, w, h, roof, { flag, foot = 2, flare = 0.22 } = {}) {
    const parts = [
      ['poly', [[x - w / 2, foot], [x - w / 2, -h], [x + w / 2, -h], [x + w / 2, foot]]],
      ['blob', [[x - w / 2 - w * flare, -h + 3, 1], [x - w * 0.15, -h - roof * 0.5], [x, -h - roof, 1], [x + w * 0.15, -h - roof * 0.5], [x + w / 2 + w * flare, -h + 3, 1]]],
    ];
    if (flag) parts.push(['line', [[x, -h - roof + 2], [x, -h - roof - flag * 3]], 1.4], ['flag', x, -h - roof - flag * 3, flag]);
    return parts;
  }

  // A small glowing mushroom: stem and a cap that shines.
  function mushroom(x, h, r) {
    const cap = [[x - r, -h + 1]];
    for (let i = 0; i <= 8; i++) {
      const angle = Math.PI - (i / 8) * Math.PI;
      cap.push([x + Math.cos(angle) * r, -h - Math.sin(angle) * r * 0.62]);
    }
    cap.push([x + r, -h + 1]);
    return [
      ['limb', [[x, 1, r * 0.42], [x + r * 0.15, -h, r * 0.32]]],
      ['lit', cap, 0.95, 'magic'],
      ['glow', x, -h - r * 0.3, r * 0.42, null, 'magic'],
    ];
  }

  const leaf = random(404);

  const FIGURES = {
    // A wizard's tower on a crag: a shaft that narrows upwards, ledges, a
    // turret on its side, a balcony, the chamber at the top whose windows
    // flash as mages inside cast their spells (CSS: .spell), and a crooked
    // spire that sends a beam skywards. The crag reaches far down, so the
    // tower stands on any slope.
    tower: [
      ['blob', [[-150, 190, 1], [-110, 40], [-72, -12], [-48, -30], [-20, -40], [12, -42], [40, -34], [62, -18], [112, 40], [150, 190, 1]]],
      ['poly', [[-46, -26], [-31, -98], [-22, -98], [-22, -26]]],
      ['poly', [[46, -26], [31, -98], [22, -98], [22, -26]]],
      ['poly', [[-30, -30], [-21, -300], [21, -300], [30, -30]]],
      ['poly', [[-36, -116], [36, -116], [32, -128], [-32, -128]]],
      ['poly', [[-30, -214], [30, -214], [27, -224], [-27, -224]]],
      ['poly', [[-24, -146], [-48, -152], [-46, -226], [-24, -226]]],
      ['blob', [[-57, -222, 1], [-42, -236], [-37, -276, 1], [-30, -236], [-15, -222, 1]]],
      ['poly', [[-48, -298], [48, -298], [48, -307], [-48, -307]]],
      ['poly', [[-21, -274], [-48, -298], [-21, -298]]],
      ['poly', [[21, -274], [48, -298], [21, -298]]],
      ['poly', [[-28, -306], [-31, -356], [31, -356], [28, -306]]],
      ['poly', [[-46, -352], [46, -352], [37, -366], [-37, -366]]],
      ['blob', [[-40, -364, 1], [-16, -392], [-6, -432], [8, -464], [32, -494, 1], [14, -454], [10, -414], [18, -386], [40, -364, 1]]],
      ['lit', arch(0, -70, 10, 22), 0.85, 'magic'],
      ['lit', arch(0, -160, 8, 18), 0.85, 'magic'],
      ['lit', arch(-36, -184, 6, 14), 0.8, 'magic'],
      ['lit', arch(0, -246, 8, 18), 0.85, 'magic'],
      ['glow', 0, -328, 7, 'spell spell--glow', 'magic'],
      ['lit', arch(-17, -314, 8, 28), 1, 'magic', 'spell spell--1'],
      ['lit', arch(0, -314, 8, 28), 1, 'magic', 'spell spell--2'],
      ['lit', arch(17, -314, 8, 28), 1, 'magic', 'spell spell--3'],
      ['beam', 32, -496, 4, 520],
      ['glow', 32, -496, 3.6, null, 'magic'],
    ],
    // A castle on its rock: a crenellated curtain wall between two towers, the
    // keep behind it, slender towers with steep roofs and pennants, lit
    // windows. The rock reaches far down, so the castle stands on any slope.
    keep: [
      ['blob', [[-280, 220, 1], [-226, 60], [-184, 4], [-120, -14], [0, -20], [110, -14], [180, 0], [232, 60], [286, 220, 1]]],
      ['poly', crenels(-150, 150, -62, 10)],
      ...spire(-150, 30, 112, 62),
      ...spire(150, 34, 124, 70, { flag: 7 }),
      ['poly', crenels(-78, 38, -146, 8)],
      ...spire(-104, 22, 160, 54),
      ...spire(66, 30, 190, 84, { flag: 6 }),
      ...spire(-22, 44, 238, 118, { flag: 9 }),
      ['lit', arch(-22, -168, 7, 16), 0.9],
      ['lit', arch(-22, -204, 7, 16), 0.9],
      ['lit', arch(-62, -104, 6, 13), 0.85],
      ['lit', arch(-44, -104, 6, 13), 0.6],
      ['lit', arch(14, -104, 6, 13), 0.85],
      ['lit', arch(66, -154, 6, 15), 0.9],
      ['lit', arch(-150, -80, 5, 12), 0.75],
      ['lit', arch(150, -94, 5, 13), 0.85],
      ['lit', arch(-104, -130, 5, 11), 0.8],
    ],
    // A hold of the mountain folk: two square towers with braziers burning
    // on their tops, between them a gabled front with a great round gate
    // full of light, and a broad stair, on a rock that reaches far down.
    hold: [
      ['blob', [[-270, 220, 1], [-214, 60], [-170, 2], [-80, -12], [0, -14], [80, -12], [170, 2], [218, 60], [274, 220, 1]]],
      ['poly', [[-58, 2], [-58, -4], [-50, -4], [-50, -8], [-42, -8], [-42, -12], [42, -12], [42, -8], [50, -8], [50, -4], [58, -4], [58, 2]]],
      ['poly', [[-78, -10], [-74, -150], [74, -150], [78, -10]]],
      ['poly', [[-90, -144], [90, -144], [90, -154], [-90, -154]]],
      ['poly', [[-86, -152], [0, -200], [86, -152]]],
      ['poly', [[-142, -6], [-138, -222], [-86, -222], [-82, -6]]],
      ['poly', crenels(-148, -76, -228, 9, -216)],
      ['poly', [[-126, -236], [-98, -236], [-103, -248], [-121, -248]]],
      ['poly', [[82, -6], [86, -222], [138, -222], [142, -6]]],
      ['poly', crenels(76, 148, -228, 9, -216)],
      ['poly', [[98, -236], [126, -236], [121, -248], [103, -248]]],
      ['lit', round(0, -12, 56, 108), 0.34],
      ['lit', round(0, -12, 40, 92), 0.26],
      ['lit', round(0, -12, 22, 70), 0.3],
      ['lit', [[-114, -118], [-108, -118], [-108, -142], [-114, -142]], 0.8],
      ['lit', [[-114, -170], [-108, -170], [-108, -192], [-114, -192]], 0.7],
      ['lit', [[108, -118], [114, -118], [114, -142], [108, -142]], 0.8],
      ['lit', [[108, -170], [114, -170], [114, -192], [108, -192]], 0.7],
      ['lit', [[-30, -164], [30, -164], [30, -168], [-30, -168]], 0.5],
      ['glow', -112, -254, 8, 'flicker'],
      ['glow', 112, -254, 8, 'flicker'],
    ],
    // An island of rock floating in the air, trees on it, a stream falling
    // off its edge.
    isle: [
      ['blob', [[-66, 0, 1], [-42, -7], [-14, -5], [14, -9], [42, -6], [68, 0, 1], [56, 10], [40, 16], [32, 30], [20, 48], [12, 70], [4, 104, 1], [-6, 74], [-14, 52], [-24, 38], [-40, 22], [-56, 10]]],
      ['path', pine(-38, -1, 56, 22, leaf)],
      ['path', pine(-22, -2, 36, 16, leaf)],
      ['path', broadleaf(26, -4, 50, leaf)],
      ['line', [[-30, 18], [-37, 38], [-34, 50]], 1.4],
      ['line', [[-10, 40], [-14, 58]], 1.1],
      ['line', [[28, 26], [33, 46]], 1.2],
      ['lit', [[-64, -0.5], [-42, -7.5], [-14, -5.5], [14, -9.5], [42, -6.5], [66, -0.5], [42, -3.5], [14, -6], [-14, -2.5], [-42, -4.5]], 0.5, 'magic'],
      ['fall', 60, -1, 6, 320],
    ],
    // A waterfall pouring over a ledge of rock and down the mountain.
    cascade: [
      ['blob', [[-26, 4, 1], [-20, -6], [-6, -10], [10, -8], [24, 4, 1]]],
      ['fall', 4, -6, 7, 200],
      ['glow', 4, -5, 2.2],
    ],
    // A smaller one, a pine and a bush on it.
    rock: [
      ['blob', [[-36, 0, 1], [-14, -5], [8, -3], [36, 0, 1], [26, 10], [16, 24], [8, 40], [0, 60, 1], [-8, 38], [-18, 22], [-28, 10]]],
      ['path', pine(-12, -2, 32, 13, leaf)],
      ['path', bush(14, -2, 14, leaf)],
      ['lit', [[-34, -0.5], [-14, -5.5], [8, -3.5], [34, -0.5], [8, -1.5], [-14, -3]], 0.45, 'magic'],
    ],
    // A cluster of glowing mushrooms.
    shrooms: [
      ...mushroom(0, 17, 9),
      ...mushroom(15, 10, 6),
      ...mushroom(-12, 7, 5),
    ],
    // A moonwell: a stone basin of shining water between two slender
    // pillars that curl inwards like crescents, a pale beam above it.
    well: [
      ['poly', [[-50, 2], [-44, -12], [44, -12], [50, 2]]],
      ['poly', [[-46, -10], [-43, -84], [-35, -84], [-34, -10]]],
      ['path', 'M-50 -82C-52 -104 -36 -116 -18 -112C-32 -108 -40 -98 -36 -82Z'],
      ['poly', [[46, -10], [43, -84], [35, -84], [34, -10]]],
      ['path', 'M50 -82C52 -104 36 -116 18 -112C32 -108 40 -98 36 -82Z'],
      ['beam', 0, -16, 6, 520],
      ['lit', [[-38, -12], [-30, -17], [30, -17], [38, -12]], 0.95, 'magic'],
      ['glow', 0, -16, 7, null, 'magic'],
    ],
    // A warrior on a boulder: horned helm, spiked pauldron, a beard, a mug
    // held out to the fire, the axe planted behind.
    warrior: [
      ['blob', [[-19, 0], [-20, -7], [-15, -15], [-4, -18], [8, -16], [13, -9], [12, 0]]],
      ['line', [[-16, 1], [-12, -66]], 3.2],
      ['blob', [[-12, -61, 1], [-5, -70], [-1, -62], [-4, -53], [-12, -57, 1], [-20, -53], [-23, -62], [-19, -70]]],
      ['limb', [[-2, -22, 14], [21, -25, 11], [24, -6, 8]]],
      ['blob', [[18, -10], [27, -10], [32, -5], [34, 0, 1], [17, 0, 1]]],
      ['blob', [[-9, -18], [-11, -30], [-6, -45], [3, -53], [13, -50], [18, -41], [16, -28], [10, -18]]],
      ['blob', [[-5, -46], [-3, -55], [5, -60], [14, -57], [18, -50], [14, -43], [4, -42]]],
      ['poly', [[0, -57], [-3, -67], [5, -59]]],
      ['poly', [[8, -60], [9, -69], [12, -59]]],
      ['limb', [[9, -46, 11], [20, -30, 8.5], [31, -35, 8]]],
      ['circle', 33, -35, 5],
      ['poly', [[30, -44], [39, -44], [39.5, -31], [30.5, -31]]],
      ['blob', [[29, -44], [31, -47.5], [35, -46], [38, -48], [40.5, -44]]],
      ['line', [[30, -41], [26.5, -39], [26.5, -34], [30, -33]], 2],
      head(20, -60, 1.05),
      ['blob', [[16, -57], [27, -56], [28, -50], [25, -43], [21, -36, 1], [18, -44], [15, -50]]],
      ['blob', [[12, -60], [13, -67], [19, -71], [25, -69], [28, -63], [27, -60]]],
      ['path', 'M24 -66C30 -68 33 -74 32 -83C29 -77 26 -73 21 -69Z'],
      ['path', 'M15 -66C9 -68 6 -74 7 -83C9 -77 12 -73 17 -69Z'],
    ],
    // A mage standing in a long robe: pointed hat, long beard, a staff with
    // a glowing crystal.
    mage: [
      ['blob', [[-5, -76], [-9, -60], [-12, -38], [-16, -15], [-21, -1, 1], [-8, 0], [6, 0], [15, 0, 1], [13, -12], [10, -35], [9, -58], [6, -74]]],
      ['blob', [[9, -4], [17, -4], [20.5, 0, 1], [9, 0, 1]]],
      ['blob', [[-1, -73], [7, -69], [14, -63], [20, -56], [19, -51, 1], [12, -53], [4, -60]]],
      ['circle', 17, -57, 3.4],
      ['line', [[18.5, -104], [14, 1]], 3.2],
      ['line', [[16, -104], [15, -112]], 2],
      ['line', [[21, -104], [22.5, -112]], 2],
      ['glow', 19, -110.5, 2.6],
      head(3, -84, 0.95),
      ['blob', [[1, -80], [10, -80], [11, -72], [8, -61], [5, -52, 1], [3, -63], [0, -72]]],
      ['blob', [[-15, -85], [-6, -89.5], [6, -90], [16, -87.5], [20, -84.5, 1], [8, -85], [-4, -85], [-14, -83.5]]],
      ['blob', [[-8, -88], [-8, -99], [-12, -110], [-22, -121, 1], [-10, -111], [-3, -101], [2, -94], [8, -88]]],
    ],
    // A hunter with long ears and a ponytail, one knee up, the bow and the
    // quiver on the back.
    hunter: [
      ['curve', 'M-10 -66Q-27 -40 -9 -9', 3],
      ['line', [[-10, -66], [-9, -9]], 0.8],
      ['poly', [[-10, -38], [-7, -58], [-2, -57], [-5, -37]]],
      ['poly', [[-8, -58], [-11, -65], [-6, -60]]],
      ['poly', [[-5, -58], [-4, -66], [-2, -58]]],
      ['blob', [[-1, -1], [11, -7], [20, -6], [23, -1, 1], [0, 0, 1]]],
      ['limb', [[0, -9, 13.5], [17, -27, 10], [21, -5, 7.5]]],
      ['blob', [[16, -9], [24, -8], [29, -3], [30, 0, 1], [15, 0, 1]]],
      ['limb', [[-3, -41, 7.5], [-11, -24, 6.5], [-13, -5, 5.5]]],
      ['blob', [[-8, -7], [-10, -22], [-7, -38], [0, -47], [9, -45], [12, -35], [10, -20], [8, -8]]],
      ['blob', [[-7, -42], [-2, -49], [7, -49], [12, -43], [3, -39]]],
      ['limb', [[4, -43, 8], [15, -30, 7], [23, -33, 6]]],
      ['circle', 24, -33, 3.2],
      head(4, -55, 0.95),
      ['blob', [[-4, -61], [2, -64], [8, -62], [8.5, -58.5], [2, -59], [-3, -55], [-6, -47], [-9, -38, 1], [-12, -46], [-9, -55]]],
      ['poly', [[-0.5, -57.5], [-16, -66], [-2.5, -52.5]]],
    ],
    // A rogue in a hooded cloak, arms round the knees.
    rogue: [
      ['blob', [[-5, -48], [-12, -42], [-16, -26], [-20, -9], [-28, 0, 1], [6, 0], [3, -20], [6, -38]]],
      ['limb', [[0, -8, 12], [17, -25, 10], [21, -4, 7]]],
      ['blob', [[16, -8], [24, -7], [28, -2], [29, 0, 1], [15, 0, 1]]],
      ['limb', [[5, -41, 8], [13, -26, 7], [19, -24, 6]]],
      ['blob', [[4, -61], [-3, -63.5], [-9, -61], [-13, -56], [-17, -49, 1], [-10, -48], [-5, -44], [5, -45], [10, -50], [10.5, -57]]],
      ['poly', [[9.5, -56], [13, -52.5], [9.5, -51]]],
    ],
    // The hunter's wolf, sitting up, ears pricked.
    wolf: [
      ['blob', [[-10, -2], [-17, -3], [-22, 0, 1], [-10, 0]]],
      ['blob', [[-12, 0], [-14, -8], [-12, -18], [-6, -26], [2, -34], [8, -38], [12, -33], [11, -20], [8, -6], [6, 0]]],
      ['limb', [[3, -24, 4.5], [4, -12, 3.5], [5, -1, 3.2]]],
      ['limb', [[6, -26, 5], [7, -12, 4], [8, -1, 3.5]]],
      ['blob', [[4, -1.5], [11, -1.5], [12, 0, 1], [4, 0, 1]]],
      ['blob', [[2, -36], [6, -44], [12, -46], [14, -38], [12, -28], [6, -28]]],
      ['blob', [[6, -46], [11, -50], [16, -49], [22, -46], [26, -44, 1], [19, -41], [13, -40], [8, -42]]],
      ['poly', [[8, -48], [8, -56], [12, -50]]],
      ['poly', [[11, -49], [13, -56], [15, -49]]],
    ],
    // An old tree, a long branch reaching out over the moon, an owl on it.
    oak: [
      ['blob', [[-44, 1, 1], [-24, -8], [-16, -22], [16, -22], [24, -8], [46, 1, 1]]],
      ['limb', [[0, -20, 40], [-7, -45, 32], [1, -95, 26], [-5, -140, 21], [-2, -180, 16]]],
      ['limb', [[-4, -122, 15], [-38, -140, 10], [-78, -149, 7], [-112, -151, 4.5], [-144, -161, 2.5]]],
      ['limb', [[-78, -149, 4.5], [-88, -168, 2.8], [-94, -182, 1.6]]],
      ['limb', [[-112, -151, 3], [-124, -142, 2], [-133, -138, 1.2]]],
      ['limb', [[-3, -170, 15], [-40, -205, 11], [-75, -222, 7]]],
      ['limb', [[-1, -175, 14], [40, -210, 10], [80, -220, 7]]],
      ['limb', [[-2, -178, 12], [6, -240, 9]]],
      ['circle', -104, -214, 22],
      ['circle', -78, -238, 32],
      ['circle', -36, -262, 40],
      ['circle', 12, -272, 42],
      ['circle', 58, -256, 38],
      ['circle', 96, -228, 30],
      ['circle', 116, -204, 18],
      ['circle', -124, -200, 14],
      ['circle', -48, -222, 30],
      ['circle', 30, -226, 34],
      ['circle', 76, -206, 24],
      ['circle', -8, -236, 32],
      ['circle', -88, -204, 18],
      ['circle', 4, -304, 24],
      ['circle', -58, -288, 22],
      ['circle', 52, -294, 22],
      ['circle', -138, -207, 9],
      ['circle', 130, -214, 11],
      ['circle', -22, -306, 14],
      ['circle', 92, -268, 18],
      ['circle', -62, -200, 13],
      ['circle', 40, -200, 15],
      ['circle', 102, -196, 11],
      ['circle', -142, -165, 7],
      ['circle', -132, -159, 5],
      ['circle', -150, -159, 4.5],
      ['circle', -90, -179, 6],
      ...owl(-100, -152),
    ],
  };

  function part([kind, ...args]) {
    const stroke = (d, width) => node('path', {
      d,
      fill: 'none',
      stroke: 'currentColor',
      'stroke-width': width,
      'stroke-linecap': 'round',
      'stroke-linejoin': 'round',
    });
    if (kind === 'blob') return node('path', { d: blob(args[0]) });
    if (kind === 'poly') return node('path', { d: poly(args[0]) });
    if (kind === 'limb') return node('path', { d: limb(args[0]) });
    if (kind === 'circle') return node('path', { d: circle(...args) });
    if (kind === 'line') return stroke(`M${args[0].map(([x, y]) => `${f(x)} ${f(y)}`).join('L')}`, args[1]);
    if (kind === 'curve') return stroke(args[0], args[1]);
    if (kind === 'flag') {
      const [x, y, s] = args;
      return node('path', { class: 'pennant', d: `M${f(x)} ${f(y)}C${f(x + s * 0.6)} ${f(y - s * 0.15)} ${f(x + s)} ${f(y + s * 0.1)} ${f(x + s * 1.9)} ${f(y + s * 0.3)}C${f(x + s)} ${f(y + s * 0.5)} ${f(x + s * 0.6)} ${f(y + s * 0.8)} ${f(x)} ${f(y + s * 0.75)}Z` });
    }
    return node('path', { d: args[0] });
  }

  const LIGHTS = new Set(['glow', 'lit', 'beam', 'fall']);

  // One of a figure's own lights (see the list above FIGURES).
  function shine([kind, ...args], id) {
    const tone = light => (light === 'magic' ? ['magic', 'var(--magic)', 'var(--magic2)'] : ['spark', 'var(--fire)', 'var(--fire2)']);
    if (kind === 'lit') {
      const [points, opacity, light, name] = args;
      const element = node('path', name ? { d: poly(points), class: name } : { d: poly(points) });
      element.style.fill = tone(light)[1];
      element.style.opacity = opacity;
      return element;
    }
    if (kind === 'glow') {
      const [gx, gy, r, name, light] = args;
      const [halo, , core] = tone(light);
      const glow = node('g', name ? { class: name } : {});
      glow.append(node('circle', { cx: gx, cy: gy, r: r * 4.5, fill: `url(#${halo}-${id})` }));
      const dot = node('circle', { cx: gx, cy: gy, r });
      dot.style.fill = core;
      glow.append(dot);
      return glow;
    }
    if (kind === 'beam') {
      const [bx, by, w, h] = args;
      const beam = node('g', { class: 'beam' });
      for (const [spread, opacity] of [[5, 0.35], [2.4, 0.6], [1, 1]]) {
        const shaft = node('path', { d: poly([[bx - (w * spread) / 2, by], [bx - w * spread * 1.4, by - h], [bx + w * spread * 1.4, by - h], [bx + (w * spread) / 2, by]]), fill: `url(#beam-${id})` });
        shaft.style.opacity = opacity;
        beam.append(shaft);
      }
      return beam;
    }
    // A fall of water: a sheet that fades towards its foot, streaks running
    // down it (CSS: .fall__flow).
    const [fx, fy, w, h] = args;
    const fall = node('g', { class: 'fall' });
    fall.append(node('path', { d: poly([[fx - w / 2, fy], [fx + w / 2, fy], [fx + w * 0.9, fy + h], [fx - w * 0.9, fy + h]]), fill: `url(#fall-${id})` }));
    for (const [share, delay] of [[-0.25, 0], [0.2, -0.5]]) {
      const flow = node('path', { class: 'fall__flow', d: `M${f(fx + share * w)} ${f(fy)}L${f(fx + share * w * 1.6)} ${f(fy + h * 0.8)}`, fill: 'none', 'stroke-width': f(w * 0.28) });
      flow.style.stroke = 'var(--water)';
      flow.style.animationDelay = `${delay}s`;
      fall.append(flow);
    }
    return fall;
  }

  // One figure at (x, y), size k, looking right (facing 1) or left (-1).
  // Returns its silhouette (a <g> to show or to <use>) and, if it has any,
  // its own lights (a <g> for in front of it). The lights' gradients are
  // made by lightDefs(defs, id).
  function figure(parts, x, y, k, facing, id) {
    const transform = `translate(${f(x)} ${f(y)}) scale(${f(k * facing)} ${f(k)})`;
    const body = node('g', { id: `figure-${++uid}`, transform, fill: 'currentColor' });
    let lights = null;
    for (const piece of parts) {
      if (!LIGHTS.has(piece[0])) {
        body.append(part(piece));
        continue;
      }
      lights = lights || node('g', { transform });
      lights.append(shine(piece, id));
    }
    return { body, lights };
  }

  // The fire: a light on the ground, a halo, crossed logs, the flame of the
  // logo (three tongues that flicker on their own, CSS only) and stones.
  // Units as for figures.
  function fireplace(x, y, k, id) {
    const back = node('g');
    const front = node('g');
    const place = `translate(${f(x)} ${f(y)}) scale(${f(k)})`;
    back.append(node('ellipse', { cx: x, cy: y + 1.5 * k, rx: 175 * k, ry: 30 * k, fill: `url(#pool-${id})` }));
    back.append(node('circle', { cx: x, cy: y - 22 * k, r: 120 * k, fill: `url(#halo-${id})` }));

    const logs = node('g', { transform: place, fill: 'currentColor' });
    logs.style.color = 'var(--figure)';
    logs.append(part(['line', [[-18, -2], [15, -10]], 5.5]), part(['line', [[-15, -10], [18, -2]], 5.5]));

    // The logo's flame (128 box, base at 64, 114), 55 units tall.
    const flame = node('g', { class: 'camp__flame', transform: `${place} translate(-33.9 -58.4) scale(0.53)` });
    const tongues = [
      ['M66 10C72 30 98 44 98 76 98 98 83 114 64 114 45 114 30 99 30 78 30 62 40 54 44 40 48 50 54 54 58 50 64 42 60 24 66 10Z', `url(#flame-${id})`],
      ['M66 44C70 58 84 66 84 84 84 98 75 108 64 108 53 108 44 99 44 86 44 76 51 72 54 62 57 68 61 69 63 66 66 60 64 52 66 44Z', 'var(--flame-inner)'],
      ['M64 76C68 84 74 88 74 96 74 103 69 108 64 108 59 108 54 103 54 97 54 90 60 86 64 76Z', 'var(--flame-core)'],
    ];
    for (const [d, fill] of tongues) {
      const tongue = node('path', { d });
      tongue.style.fill = fill;
      flame.append(tongue);
    }

    const stones = node('g', { transform: place, fill: 'currentColor' });
    for (const [sx, sy, rx, ry] of [[-24, -2, 6, 4], [-13, 0, 6.5, 4], [-1, 1, 6, 3.8], [11, 0, 6.5, 4], [23, -2, 6, 4]]) {
      stones.append(node('ellipse', { cx: sx, cy: sy, rx, ry }));
    }
    stones.style.color = 'var(--figure)';
    const lit = node('g', { transform: `translate(0 ${f(-1.2 * Math.max(1, k))})` });
    lit.append(stones.cloneNode(true));
    lit.firstChild.style.color = 'var(--fire)';
    lit.style.opacity = 0.7;
    front.append(logs, flame, lit, stones);
    return { back, front };
  }

  // Draws a camp onto a ridge that build() made:
  //   fire  x of the fire; the ground there is the ridge's height
  //   size  k: 1 draws a standing person 100 units tall
  //   cast  [{ figure, at, back, scale, lift, facing, rim }]
  //         at: distance from the fire in tens of units (negative: left)
  //         back: farther away than the fire, drawn before it
  //         facing: 1 or -1; by default towards the fire
  //         rim: false for no firelight on its edge (it fades with distance)
  // Returns { x, y } of the fire.
  function camp({ svg, points }, { fire: x, size: k, cast }) {
    const y = heightAt(points, x);
    const id = ++uid;
    const defs = svg.querySelector('defs');
    defs.append(
      gradient('radial', `pool-${id}`, {}, [[0, 'var(--fire)', 0.42], [0.45, 'var(--fire)', 0.13], [1, 'var(--fire)', 0]]),
      gradient('radial', `halo-${id}`, {}, [[0, 'var(--fire)', 0.42], [0.3, 'var(--fire)', 0.12], [1, 'var(--fire)', 0]]),
      gradient('linear', `flame-${id}`, { x1: 0, y1: 0, x2: 0, y2: 1 }, [[0, 'var(--fire2)'], [0.45, 'var(--fire)'], [1, 'var(--flame-base)']]),
    );

    lightDefs(defs, id);
    const group = node('g', { class: 'camp' });
    const { back, front } = fireplace(x, y, k, id);
    const rows = { back: node('g'), near: node('g') };
    for (const member of cast) {
      const fx = x + member.at * k * 10;
      const fy = heightAt(points, fx) - (member.lift || 0) * k;
      const towards = fx < x ? 1 : -1;
      const { body, lights } = figure(FIGURES[member.figure], fx, fy, k * (member.scale || 1), member.facing || towards, id);
      defs.append(body);
      const row = member.back ? rows.back : rows.near;
      // The rim: the same silhouette in the fire's colour, nudged towards
      // the fire, under the dark one.
      if (member.rim !== false) {
        const nudge = Math.max(0.6, 0.8 * k);
        const rim = node('use', { href: `#${body.id}`, transform: `translate(${f(towards * nudge)} 0)` });
        rim.style.color = 'var(--fire)';
        rim.style.opacity = f(Math.max(0.2, 1 - Math.abs(member.at) / 13));
        row.append(rim);
      }
      const shape = node('use', { href: `#${body.id}` });
      shape.style.color = 'var(--figure)';
      row.append(shape);
      if (lights) row.append(lights);
    }
    group.append(back, rows.back, front, rows.near);
    svg.append(group);
    return { x, y };
  }

  // Where a point of the drawing in `svg` ends up inside `host` (by default
  // the <svg> itself), as shares of the host's size; y counts from the
  // bottom. ("slice": the drawing covers the <svg>, and what does not fit is
  // cut off.)
  function place(svg, x, y, host = svg) {
    const box = svg.getBoundingClientRect();
    const to = host.getBoundingClientRect();
    if (!box.width || !box.height || !to.width || !to.height) return { x: 0.5, y: 0.1 };
    const scale = Math.max(box.width / W, box.height / H);
    return {
      x: (box.left + box.width / 2 + (x - W / 2) * scale - to.left) / to.width,
      y: (to.bottom - box.bottom + (H - y) * scale) / to.height,
    };
  }

  // Pans the drawings of `scene` sideways so that x of the drawing is in the
  // middle, as far as they still cover the scene: each <svg> becomes as wide
  // as its whole drawing and moves (CSS: --pan-left and --pan-width).
  function pan(scene, x) {
    scene.style.removeProperty('--pan-left');
    scene.style.removeProperty('--pan-width');
    const { height } = scene.querySelector('.ridge').getBoundingClientRect();
    const { width: room } = scene.getBoundingClientRect();
    if (!height || !room) return;
    const scale = Math.max(height / H, room / W);
    const width = W * scale;
    scene.style.setProperty('--pan-width', `${f(width)}px`);
    scene.style.setProperty('--pan-left', `${f(Math.max(room - width, Math.min(0, room / 2 - x * scale)))}px`);
  }

  function stars(svg, count, seed) {
    const rand = random(seed);
    for (let i = 0; i < count; i++) {
      const star = node('circle', {
        cx: (rand() * W).toFixed(1),
        cy: (rand() ** 1.5 * H * 0.72).toFixed(1),
        r: (0.5 + rand() * rand() * 1.5).toFixed(2),
      });
      star.style.opacity = (0.15 + rand() * 0.7).toFixed(2);
      if (rand() < 0.2) {
        star.setAttribute('class', 'twinkle');
        star.style.animationDelay = `${(-rand() * 7).toFixed(1)}s`;
      }
      svg.append(star);
    }
  }

  // Sparks rising, like the addon's: CSS animations, no script per frame.
  // `focus` is a place as returned by place(); most sparks rise from there.
  function embers(host, count, focus) {
    const rand = random(97);
    host.textContent = '';
    for (let i = 0; i < count; i++) {
      const near = focus && rand() < 0.62;
      const x = near ? focus.x * 100 + (rand() + rand() + rand() - 1.5) * 10 : rand() * 100;
      const y = near ? focus.y * 100 - 1 + rand() * 4 : 2 + rand() * 12;
      const spark = document.createElement('i');
      spark.style.cssText = [
        `left:${x.toFixed(2)}%`,
        `bottom:${y.toFixed(2)}%`,
        `--size:${(1.4 + rand() * 2.4).toFixed(1)}px`,
        `--rise:${(-(24 + rand() * 44)).toFixed(0)}vh`,
        `--drift:${((rand() - 0.5) * 14).toFixed(1)}vw`,
        `--time:${(7 + rand() * 9).toFixed(1)}s`,
        `animation-delay:${(-rand() * 16).toFixed(1)}s`,
      ].join(';');
      host.append(spark);
    }
  }

  // Snowflakes drifting down, CSS only, in a layer of their own in front of
  // the ridges.
  function snow(host, count) {
    const rand = random(61);
    const layer = document.createElement('div');
    layer.className = 'layer world scene__snow';
    layer.dataset.depth = 0.8;
    for (let i = 0; i < count; i++) {
      const flake = document.createElement('i');
      const near = rand() < 0.25;
      flake.style.cssText = [
        `left:${(rand() * 104 - 2).toFixed(2)}%`,
        `--size:${(near ? 2.6 + rand() * 1.6 : 1.1 + rand() * 1.4).toFixed(1)}px`,
        `--o:${(near ? 0.8 : 0.35 + rand() * 0.4).toFixed(2)}`,
        `--fall:${(100 + rand() * 20).toFixed(0)}vh`,
        `--drift:${((rand() - 0.3) * 12).toFixed(1)}vw`,
        `--time:${(near ? 9 + rand() * 5 : 16 + rand() * 12).toFixed(1)}s`,
        `animation-delay:${(-rand() * 28).toFixed(1)}s`,
      ].join(';');
      layer.append(flake);
    }
    host.insertBefore(layer, host.querySelector('.scene__embers'));
  }

  // Depth for everything in `hero` that carries data-depth: far layers stay
  // behind while the page scrolls, near ones follow the pointer more. Draws
  // only when something changed and only while the hero is on screen.
  function parallax(hero) {
    // Asked for whenever it matters: the setting can change while the page is open.
    const motion = matchMedia('(prefers-reduced-motion: reduce)');
    const collect = () => [...hero.querySelectorAll('[data-depth]')].map(element => ({
      element,
      depth: parseFloat(element.dataset.depth),
    }));
    let layers = collect();
    const copy = hero.querySelector('.hero__copy');
    const target = { x: 0, y: 0 };
    const now = { x: 0, y: 0 };
    let frame = 0;
    let visible = true;

    const request = () => {
      if (!frame) frame = requestAnimationFrame(draw);
    };

    function draw() {
      frame = 0;
      if (motion.matches) {
        // Still: everything where the page puts it.
        for (const { element } of layers) element.style.transform = '';
        if (copy) copy.style.transform = copy.style.opacity = '';
        now.x = now.y = 0;
        return;
      }
      if (!visible) return;
      now.x += (target.x - now.x) * 0.07;
      now.y += (target.y - now.y) * 0.07;
      const scrolled = Math.max(0, Math.min(scrollY, hero.offsetHeight));
      for (const { element, depth } of layers) {
        const dx = -now.x * depth * 34;
        const dy = scrolled * (1 - depth) * 0.55 - now.y * depth * 14;
        element.style.transform = `translate3d(${dx.toFixed(2)}px,${dy.toFixed(2)}px,0)`;
      }
      if (copy) {
        copy.style.transform = `translate3d(0,${(scrolled * 0.2).toFixed(1)}px,0)`;
        copy.style.opacity = Math.max(0, 1 - scrolled / (hero.offsetHeight * 0.62)).toFixed(3);
      }
      if (Math.abs(target.x - now.x) > 0.0015 || Math.abs(target.y - now.y) > 0.0015) request();
    }

    addEventListener('scroll', request, { passive: true });
    addEventListener('resize', request);
    if (matchMedia('(hover: hover) and (pointer: fine)').matches) {
      hero.addEventListener('pointermove', event => {
        target.x = event.clientX / innerWidth - 0.5;
        target.y = event.clientY / innerHeight - 0.5;
        request();
      });
      hero.addEventListener('pointerleave', () => {
        target.x = target.y = 0;
        request();
      });
    }
    motion.addEventListener('change', request);
    new IntersectionObserver(entries => {
      visible = entries[entries.length - 1].isIntersecting; // the latest
      hero.classList.toggle('is-away', !visible); // pauses sparks and stars
      if (visible) request();
    }).observe(hero);
    request();
    return {
      // The scene was drawn anew: find its layers again.
      refresh() {
        layers = collect();
        now.x = now.y = 0;
        request();
      },
    };
  }

  return { build, heightAt, place, pan, stars, embers, snow, parallax, moon, aurora, clouds };
})();
