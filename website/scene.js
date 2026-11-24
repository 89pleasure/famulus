// The landscape: ridges and forests drawn from seeded noise, layer behind
// layer, and a camp of friends at a fire made of hand-drawn silhouettes.
// The picture is generated here, so it is the same on every visit and
// nobody else's artwork is needed. Colours come from CSS (--r1a ...), which
// is how the scene follows the colour scheme.
//
//   FamulusScene.moon(host, moon)         the two moons, before build()
//   FamulusScene.build(host, layers)      adds one <svg class="layer ridge"> per layer
//   FamulusScene.stars(svg, count, seed)
//   FamulusScene.embers(host, count, focus)
//   FamulusScene.pan(scene, x)            keeps x of the drawing in view on narrow screens
//   FamulusScene.parallax(hero)           layers with data-depth follow scroll and pointer
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
      // between from and to, so that a tent or a horse stands straight, and
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
    return `M${f(x - r)} ${f(y)}a${f(r)} ${f(r)} 0 1 1 ${f(2 * r)} 0a${f(r)} ${f(r)} 0 1 1 ${f(-2 * r)} 0Z`;
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
  function forest(points, layer) {
    const { gap, height, clump, frame, clear, broad = 0, bushes = 0 } = layer.trees;
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
  //   cast    [{ figure, x, scale, facing }]: figures standing on the ridge
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
      const defs = node('defs');
      defs.append(gradient('linear', id, {
        gradientUnits: 'userSpaceOnUse',
        x1: 0,
        y1: top.toFixed(0),
        x2: 0,
        y2: Math.min(H, layer.base + (layer.haze || 120)),
      }, [[0, `var(--r${layer.tone}a)`], [1, `var(--r${layer.tone}b)`]]));
      svg.append(defs);

      if (layer.fire != null) {
        defs.append(gradient('radial', `fire-${uid}`, {}, [[0, 'var(--accent)', 0.5], [0.35, 'var(--accent)', 0.16], [1, 'var(--accent)', 0]]));
        svg.append(node('ellipse', {
          cx: layer.fire,
          cy: heightAt(points, layer.fire) + 6,
          rx: 230,
          ry: 150,
          fill: `url(#fire-${uid})`,
        }));
      }

      svg.append(node('path', { d, fill: `url(#${id})` }));
      const built = { svg, points, layer };
      for (const member of layer.cast || []) {
        const facing = member.facing || 1;
        const { body } = figure(FIGURES[member.figure], member.x, heightAt(points, member.x) + 1, member.scale || 1, facing);
        body.style.color = `var(--r${layer.tone}a)`;
        svg.append(body);
      }
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

  // The moons, drawn in the landscape's own units so they stay where the
  // drawing puts them at every window size. Azeroth has two: a large white
  // one and a small blue one. Bats cross the large one.
  //   { x, y, r, depth, small: { x, y, r }, bats: [[x, y, size], ...] }
  // Call before build(), so the ridges come in front.
  function moon(host, { x, y, r, depth, small, bats = [] }) {
    const id = ++uid;
    const svg = node('svg', {
      class: 'layer ridge',
      viewBox: `0 0 ${W} ${H}`,
      preserveAspectRatio: 'xMidYMax slice',
      focusable: 'false',
    });
    if (depth != null) svg.dataset.depth = depth;
    const defs = node('defs');
    defs.append(
      gradient('radial', `halo-${id}`, {}, [[0, 'var(--accent2)', 0.34], [0.32, 'var(--accent)', 0.12], [1, 'var(--accent)', 0]]),
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
    host.insertBefore(svg, host.querySelector('.ridge') || host.querySelector('.scene__embers'));
    return svg;
  }

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

  // ---------------------------------------------------------------------------
  // Figures: friends at the fire, their animals, a tent, an old tree.
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
  //   ['glow', x, y, r]         a light of its own: a crystal, an owl's eyes
  //   ['lit', points, opacity]  firelight inside, as in a tent
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

  // An owl seen from the front, sitting at (x, y), with glowing eyes.
  function owl(x, y) {
    const at = points => points.map(([px, py, tip]) => [x + px, y + py, tip]);
    return [
      ['blob', at([[0, -17], [-5, -15.5], [-7, -9], [-6.5, -3], [-3, 0], [3, 0], [6.5, -3], [7, -9], [5, -15.5]])],
      ['poly', at([[-5, -14], [-6.5, -20.5], [-2, -16]])],
      ['poly', at([[5, -14], [6.5, -20.5], [2, -16]])],
      ['poly', at([[-2, 0], [0, 4], [2, 0]])],
      ['glow', x - 2.4, y - 12, 0.9],
      ['glow', x + 2.4, y - 12, 0.9],
    ];
  }

  const FIGURES = {
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
    // A saddled horse, head up, waiting under the tree: arched neck, a long
    // head with small ears, a mane and a tail that flow, slender legs.
    horse: [
      ['blob', [[-37, -57], [-44, -55], [-50, -45], [-52, -31], [-50, -17], [-54, -6, 1], [-46, -14], [-44, -28], [-42, -42], [-38, -49]]],
      ['limb', [[-23, -45, 9], [-23, -28, 5.5], [-27, -19, 4.2], [-25, -8, 3.6], [-24, -3, 3.8]]],
      ['limb', [[15, -45, 8], [16, -26, 4.5], [14, -10, 3.8], [14, -3, 4]]],
      ['poly', [[-27.5, -4], [-21, -4], [-20, 0], [-28, 0]]],
      ['poly', [[11, -4], [17, -4], [18, 0], [10.5, 0]]],
      ['blob', [[-38, -56], [-30, -62], [-10, -63], [10, -63], [22, -61], [30, -54], [31, -46], [25, -40], [8, -38], [-12, -39], [-30, -41], [-38, -47]]],
      ['limb', [[-30, -47, 13], [-31, -30, 7], [-35, -20, 4.6], [-33, -8, 3.8], [-32, -3, 4]]],
      ['limb', [[22, -47, 10], [24, -27, 5], [23, -10, 4], [24, -3, 4.2]]],
      ['poly', [[-35.5, -4], [-29, -4], [-28, 0], [-36, 0]]],
      ['poly', [[21, -4], [27, -4], [28, 0], [20.5, 0]]],
      ['blob', [[12, -60], [16, -68], [22, -80], [30, -90], [36, -94], [40, -90], [42, -82], [38, -72], [33, -60], [30, -48], [22, -52]]],
      ['blob', [[34, -92], [39, -96.5], [44, -94], [50, -86], [56, -77], [57.5, -73, 1], [52, -70], [46, -72], [41, -78], [37, -84]]],
      ['poly', [[36, -95], [36.5, -101], [39.5, -96]]],
      ['poly', [[15, -63], [20, -74], [26, -85], [32, -93], [35.5, -95.5], [33, -88], [30.5, -86.5], [29.5, -80], [26.5, -78.5], [25, -72], [21.5, -70.5], [20, -64], [17, -60]]],
      ['poly', [[37.5, -95], [43, -90], [38.5, -89.5]]],
      ['blob', [[-12, -62], [-11.5, -68.5], [-4, -65], [3, -66], [5.5, -70.5, 1], [7.5, -62]]],
      ['line', [[-3, -62], [-3, -49]], 1],
      ['line', [[-5.5, -49], [-0.5, -49]], 1.8],
      ['curve', 'M51 -76Q32 -64 6 -65', 0.9],
    ],
    // A tent with the fire's light inside.
    tent: [
      ['line', [[-3, -48], [-7, -55]], 2],
      ['line', [[3, -48], [7, -55]], 2],
      ['poly', [[-32, 0], [-2, -49], [2, -49], [32, 0]]],
      ['line', [[-32, 0], [-42, 1.5]], 1],
      ['line', [[32, 0], [42, 1.5]], 1],
      ['lit', [[-9, 0], [0, -24], [9, 0]], 0.34],
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
    // A stag, head up, listening.
    deer: [
      ['limb', [[-18, -42, 7], [-20, -24, 4], [-22, -14, 3], [-19, 0, 2.5]]],
      ['limb', [[-12, -40, 6], [-12, -22, 3.5], [-13, 0, 2.5]]],
      ['limb', [[15, -42, 6], [16, -20, 3.5], [16, 0, 2.5]]],
      ['limb', [[10, -40, 5], [11, -20, 3], [12, 0, 2.5]]],
      ['blob', [[-22, -50], [-10, -54], [10, -54], [19, -50], [20, -42], [10, -38], [-12, -38], [-23, -43]]],
      ['poly', [[-21, -50], [-27, -49], [-22, -45]]],
      ['blob', [[11, -51], [16, -56], [21, -68], [25, -77], [21, -79], [15, -69], [10, -54]]],
      ['blob', [[20, -78], [25, -82], [29, -80], [35, -74], [36.5, -72, 1], [30, -71], [25, -72], [21, -74]]],
      ['poly', [[21, -80], [15, -86], [23, -82]]],
      ['line', [[24, -82], [22, -92], [17, -100], [14, -104]], 1.8],
      ['line', [[22, -92], [27, -99]], 1.5],
      ['line', [[23, -87], [30, -91]], 1.5],
      ['line', [[26, -82], [29, -93], [26, -103]], 1.6],
      ['line', [[29, -93], [35, -97]], 1.4],
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
    return node('path', { d: args[0] });
  }

  // One figure at (x, y), size k, looking right (facing 1) or left (-1).
  // Returns its silhouette (a <g> to show or to <use>) and, if it has any,
  // its own lights (a <g> for in front of it).
  function figure(parts, x, y, k, facing, id) {
    const transform = `translate(${f(x)} ${f(y)}) scale(${f(k * facing)} ${f(k)})`;
    const body = node('g', { id: `figure-${++uid}`, transform, fill: 'currentColor' });
    let lights = null;
    for (const piece of parts) {
      const [kind, ...args] = piece;
      if (kind !== 'glow' && kind !== 'lit') {
        body.append(part(piece));
        continue;
      }
      lights = lights || node('g', { transform });
      if (kind === 'lit') {
        const light = node('path', { d: poly(args[0]) });
        light.style.fill = 'var(--accent)';
        light.style.opacity = args[1];
        lights.append(light);
      } else {
        const [gx, gy, r] = args;
        lights.append(node('circle', { cx: gx, cy: gy, r: r * 4.5, fill: `url(#spark-${id})` }));
        const core = node('circle', { cx: gx, cy: gy, r });
        core.style.fill = 'var(--accent2)';
        lights.append(core);
      }
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
    lit.firstChild.style.color = 'var(--accent)';
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
      gradient('radial', `pool-${id}`, {}, [[0, 'var(--accent)', 0.42], [0.45, 'var(--accent)', 0.13], [1, 'var(--accent)', 0]]),
      gradient('radial', `halo-${id}`, {}, [[0, 'var(--accent)', 0.42], [0.3, 'var(--accent)', 0.12], [1, 'var(--accent)', 0]]),
      gradient('radial', `spark-${id}`, {}, [[0, 'var(--accent2)', 0.75], [0.3, 'var(--accent)', 0.22], [1, 'var(--accent)', 0]]),
      gradient('linear', `flame-${id}`, { x1: 0, y1: 0, x2: 0, y2: 1 }, [[0, 'var(--accent2)'], [0.45, 'var(--accent)'], [1, 'var(--flame-base)']]),
    );

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
        rim.style.color = 'var(--accent)';
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

  // Depth for everything in `hero` that carries data-depth: far layers stay
  // behind while the page scrolls, near ones follow the pointer more. Draws
  // only when something changed and only while the hero is on screen.
  function parallax(hero) {
    // Asked for whenever it matters: the setting can change while the page is open.
    const motion = matchMedia('(prefers-reduced-motion: reduce)');
    const layers = [...hero.querySelectorAll('[data-depth]')].map(element => ({
      element,
      depth: parseFloat(element.dataset.depth),
    }));
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
  }

  return { build, heightAt, place, pan, stars, embers, parallax, moon };
})();
