// The landscape: ridges and pines drawn from seeded noise, layer behind
// layer. The picture is generated here, so it is the same on every visit
// and nobody else's artwork is needed. Colours come from CSS (--r1a ...),
// which is how the scene follows the colour scheme.
//
//   FamulusScene.build(host, layers)      adds one <svg class="layer ridge"> per layer
//   FamulusScene.stars(svg, count, seed)
//   FamulusScene.embers(host, count, focus)
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
      points.push([x, layer.base - layer.amp * height]);
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

  // Pines along a ridge.
  //   gap     [from, to] between two trees
  //   height  [from, to]
  //   clump   width of the patches they grow in (none: everywhere)
  //   frame   [from, to]: trees grow from small to tall between these
  //           distances from the middle (0) to the edge (1), so the tall
  //           ones frame the picture and leave its middle open
  function forest(points, layer) {
    const { gap, height, clump, frame } = layer.trees;
    const rand = random(layer.seed * 7 + 3);
    const patch = clump ? noise(random(layer.seed * 13 + 1)) : null;
    let d = '';
    let x = -MARGIN;
    while (x < W + MARGIN) {
      x += gap[0] + rand() * (gap[1] - gap[0]);
      let size = 0.25 + rand() * 0.75;
      if (patch && patch(x / clump) < 0.46) continue;
      if (frame) {
        const grow = smooth(frame[0], frame[1], Math.abs(x / W - 0.5) * 2);
        if (grow < 0.04 && rand() < 0.8) continue;
        size *= 0.12 + grow * 0.88;
      }
      const tall = height[0] + size * (height[1] - height[0]);
      d += pine(x, heightAt(points, x) + tall * 0.08, tall, tall * (0.34 + rand() * 0.14), rand);
    }
    return d;
  }

  // Adds the layers to `host`, far to near, before `host`'s embers if it has
  // any. Returns [{ svg, points, layer }].
  //   tone    1 (far, light and hazy) .. 5 (the ground of the page): --r<tone>a / --r<tone>b
  //   depth   for the parallax: 0 never moves, 1 scrolls with the page
  //   fire    x of a warm glow behind this ridge
  function build(host, layers) {
    const before = host.querySelector('.scene__embers');
    return layers.map(layer => {
      const points = outline(layer);
      const top = Math.min(...points.map(point => point[1]));
      let d = `M${-MARGIN} ${H + 40}`;
      for (const [x, y] of points) d += `L${x} ${y.toFixed(1)}`;
      d += `L${W + MARGIN} ${H + 40}Z`;
      if (layer.trees) d += forest(points, layer);

      const svg = node('svg', {
        class: 'layer ridge',
        viewBox: `0 0 ${W} ${H}`,
        preserveAspectRatio: 'xMidYMax slice',
        focusable: 'false',
      });
      if (layer.depth != null) svg.dataset.depth = layer.depth;

      // Each ridge grows hazier towards its foot, where the next one rises.
      const id = `ridge-${++uid}`;
      const gradient = node('linearGradient', {
        id,
        gradientUnits: 'userSpaceOnUse',
        x1: 0,
        y1: top.toFixed(0),
        x2: 0,
        y2: Math.min(H, layer.base + (layer.haze || 120)),
      });
      const from = node('stop', { offset: 0 });
      const to = node('stop', { offset: 1 });
      from.style.stopColor = `var(--r${layer.tone}a)`;
      to.style.stopColor = `var(--r${layer.tone}b)`;
      gradient.append(from, to);
      const defs = node('defs');
      defs.append(gradient);
      svg.append(defs);

      if (layer.fire != null) {
        const glow = node('radialGradient', { id: `fire-${uid}` });
        for (const [offset, opacity] of [[0, 0.5], [0.35, 0.16], [1, 0]]) {
          const stop = node('stop', { offset });
          stop.style.stopColor = 'var(--accent)';
          stop.style.stopOpacity = opacity;
          glow.append(stop);
        }
        defs.append(glow);
        svg.append(node('ellipse', {
          cx: layer.fire,
          cy: heightAt(points, layer.fire) + 6,
          rx: 230,
          ry: 150,
          fill: `url(#fire-${uid})`,
        }));
      }

      svg.append(node('path', { d, fill: `url(#${id})` }));
      host.insertBefore(svg, before);
      return { svg, points, layer };
    });
  }

  // Where a point of the drawing ends up inside its <svg>, as shares of the
  // element's size; y counts from the bottom. ("slice": the drawing covers
  // the element, and what does not fit is cut off.)
  function place(svg, x, y) {
    const { width, height } = svg.getBoundingClientRect();
    if (!width || !height) return { x: 0.5, y: 0.1 };
    const scale = Math.max(width / W, height / H);
    return {
      x: (width / 2 + (x - W / 2) * scale) / width,
      y: ((H - y) * scale) / height,
    };
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
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
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
    new IntersectionObserver(entries => {
      visible = entries[0].isIntersecting;
      hero.classList.toggle('is-away', !visible); // pauses sparks and stars
      if (visible) request();
    }).observe(hero);
    request();
  }

  return { build, heightAt, place, stars, embers, parallax };
})();
