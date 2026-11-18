async function initializeSideAnimation() {
if (!window.matchMedia("(min-width: 1281px)").matches || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
const THREE = await import("https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js");

const terminal = document.querySelector(".terminal-window");
const leftCanvas = document.querySelector("#left-side-animation");
const rightCanvas = document.querySelector("#right-side-animation");

if (!terminal || !leftCanvas || !rightCanvas) {
  throw new Error("Required terminal or side animation canvas was not found.");
}

const reducedMotion = window.matchMedia(
  "(prefers-reduced-motion: reduce)"
).matches;

class SideCluster {
  constructor(canvas, side) {
    this.canvas = canvas;
    this.side = side;
    this.width = 0;
    this.height = 0;
    this.pointer = new THREE.Vector2();
    this.clock = new THREE.Clock();
    this.tiles = [];

    this.renderer = new THREE.WebGLRenderer({
      canvas,
      alpha: true,
      antialias: true,
      powerPreference: "high-performance",
    });

    this.renderer.setClearColor(0x000000, 0);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.12;

    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.FogExp2(0x06100d, 0.075);

    this.camera = new THREE.OrthographicCamera(-4, 4, 5, -5, 0.1, 100);
    this.camera.position.set(0, 0, 12);
    this.camera.lookAt(0, 0, 0);

    this.scene.add(new THREE.AmbientLight(0x8fffb0, 0.62));

    const key = new THREE.DirectionalLight(0xc6ffd5, 2.3);
    key.position.set(side === "left" ? -4 : 4, 7, 10);
    this.scene.add(key);

    this.amberLight = new THREE.PointLight(0xff9f1c, 22, 16, 2);
    this.amberLight.position.set(side === "left" ? -1.5 : 1.5, 2, 5);
    this.scene.add(this.amberLight);

    this.cyanLight = new THREE.PointLight(0x5bb7ff, 11, 15, 2);
    this.cyanLight.position.set(side === "left" ? 1.5 : -1.5, -2.5, 4);
    this.scene.add(this.cyanLight);

    this.createTiles();
    this.bindEvents();

    this.renderer.setAnimationLoop(() => this.animate());
  }

  createFrontMaterial(seed) {
    return new THREE.ShaderMaterial({
      transparent: true,
      depthWrite: false,
      uniforms: {
        uTime: { value: 0 },
        uSeed: { value: seed },
      },
      vertexShader: `
        varying vec2 vUv;
        varying vec3 vNormalView;

        void main() {
          vUv = uv;
          vNormalView = normalize(normalMatrix * normal);
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        precision highp float;

        uniform float uTime;
        uniform float uSeed;

        varying vec2 vUv;
        varying vec3 vNormalView;

        float hash21(vec2 p) {
          p = fract(p * vec2(123.34, 456.21));
          p += dot(p, p + 45.32);
          return fract(p.x * p.y);
        }

        float noise2(vec2 p) {
          vec2 i = floor(p);
          vec2 f = fract(p);
          f = f * f * (3.0 - 2.0 * f);

          float a = hash21(i);
          float b = hash21(i + vec2(1.0, 0.0));
          float c = hash21(i + vec2(0.0, 1.0));
          float d = hash21(i + vec2(1.0, 1.0));

          return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
        }

        void main() {
          vec2 uv = vUv;
          vec2 shift = vec2(
            fract(uSeed * 0.173),
            fract(uSeed * 0.417)
          );

          float greenRegion = smoothstep(
            0.80,
            0.05,
            distance(uv, vec2(0.30, 0.70) + 0.09 * sin(uSeed))
          );

          float amberRegion = smoothstep(
            0.64,
            0.02,
            distance(uv, vec2(0.70, 0.28) + 0.08 * cos(uSeed * 1.7))
          );

          float cyanRegion = smoothstep(
            0.72,
            0.05,
            distance(uv, vec2(0.78, 0.78) + 0.05 * sin(uSeed * 2.2))
          );

          float grainLarge = noise2(uv * 7.0 + shift * 10.0);
          float grainFine = noise2(uv * 34.0 - shift * 6.0);
          float scan = sin((uv.y + uTime * 0.01) * 410.0) * 0.5 + 0.5;

          vec3 dark = vec3(0.014, 0.050, 0.037);
          vec3 green = vec3(0.18, 0.95, 0.40);
          vec3 amber = vec3(1.0, 0.47, 0.035);
          vec3 cyan = vec3(0.20, 0.56, 1.0);

          vec3 color = mix(dark, green, 0.30 + greenRegion * 0.66);
          color = mix(color, amber, amberRegion * 0.72);
          color = mix(color, cyan, cyanRegion * 0.28);

          float lighting = 0.48 + 0.52 * max(
            dot(
              normalize(vNormalView),
              normalize(vec3(-0.28, 0.66, 0.95))
            ),
            0.0
          );

          color *= lighting;
          color += (grainLarge - 0.5) * 0.11;
          color += (grainFine - 0.5) * 0.035;
          color += scan * 0.025;

          float edge = smoothstep(0.0, 0.075, uv.x)
            * smoothstep(0.0, 0.075, uv.y)
            * smoothstep(0.0, 0.075, 1.0 - uv.x)
            * smoothstep(0.0, 0.075, 1.0 - uv.y);

          gl_FragColor = vec4(color, mix(0.68, 0.98, edge));
        }
      `,
    });
  }

  createTiles() {
    const sideMaterial = new THREE.MeshStandardMaterial({
      color: 0x03100b,
      emissive: 0x06331a,
      emissiveIntensity: 0.68,
      roughness: 0.82,
      metalness: 0.10,
      transparent: true,
      opacity: 0.90,
    });

    const geometry = new THREE.BoxGeometry(1.32, 1.32, 0.20, 4, 4, 1);

    const offsets = [
      new THREE.Vector3(-0.70, 0.70, 0),
      new THREE.Vector3(0.70, 0.70, 0),
      new THREE.Vector3(-0.70, -0.70, 0),
      new THREE.Vector3(0.70, -0.70, 0),
    ];

    const tilt = new THREE.Quaternion().setFromEuler(
      new THREE.Euler(
        this.side === "left" ? -0.14 : 0.14,
        this.side === "left" ? 0.42 : -0.42,
        this.side === "left" ? -0.12 : 0.12,
        "XYZ"
      )
    );

    offsets.forEach((offset, index) => {
      const front = this.createFrontMaterial(
        (this.side === "left" ? 1 : 7) + index * 0.83
      );

      const mesh = new THREE.Mesh(geometry, [
        sideMaterial,
        sideMaterial,
        sideMaterial,
        sideMaterial,
        front,
        front,
      ]);

      const home = offset.clone().applyQuaternion(tilt);

      mesh.position.copy(home);
      mesh.quaternion.copy(tilt);

      mesh.userData = {
        homePosition: home.clone(),
        homeQuaternion: tilt.clone(),
        velocity: new THREE.Vector3(),
        angularVelocity: new THREE.Vector3(),
        phase: index * 0.72 + (this.side === "left" ? 0 : 1.6),
        frontMaterial: front,
      };

      this.scene.add(mesh);
      this.tiles.push(mesh);
    });
  }

  bindEvents() {
    this.canvas.addEventListener("pointerdown", (event) => {
      if (reducedMotion) return;

      const rect = this.canvas.getBoundingClientRect();
      const localX = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      const localY = -((event.clientY - rect.top) / rect.height) * 2 + 1;

      const impact = new THREE.Vector3(
        localX * 2.2,
        localY * 3.0,
        0
      );

      this.explode(impact);
    });

    this.canvas.addEventListener(
      "pointermove",
      (event) => {
        const rect = this.canvas.getBoundingClientRect();
        this.pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
        this.pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
      },
      { passive: true }
    );
  }

  explode(impact) {
    this.tiles.forEach((mesh, index) => {
      const data = mesh.userData;
      const direction = mesh.position.clone().sub(impact);

      if (direction.lengthSq() < 0.02) {
        direction.set(
          THREE.MathUtils.randFloatSpread(2),
          THREE.MathUtils.randFloatSpread(2),
          Math.random() + 0.25
        );
      }

      direction.normalize();
      direction.z += THREE.MathUtils.randFloat(0.25, 0.90);
      direction.y += THREE.MathUtils.randFloat(-0.20, 0.35);
      direction.normalize();

      const distance = Math.max(0.40, mesh.position.distanceTo(impact));
      const falloff = THREE.MathUtils.clamp(1.35 / distance, 0.75, 1.80);
      const speed = THREE.MathUtils.randFloat(4.8, 7.0) * falloff;

      data.velocity.addScaledVector(direction, speed);
      data.velocity.z += THREE.MathUtils.randFloat(0.45, 1.15);

      const angularDirection = index % 2 === 0 ? 1 : -1;
      data.angularVelocity.add(
        new THREE.Vector3(
          THREE.MathUtils.randFloat(-6.2, 6.2),
          THREE.MathUtils.randFloat(-6.2, 6.2),
          THREE.MathUtils.randFloat(-6.2, 6.2)
        ).multiplyScalar(angularDirection)
      );
    });
  }

  resize(width, height) {
    this.width = Math.max(1, Math.round(width));
    this.height = Math.max(1, Math.round(height));

    this.canvas.style.width = `${this.width}px`;
    this.canvas.style.height = `${this.height}px`;

    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
    this.renderer.setSize(this.width, this.height, false);

    const aspect = this.width / this.height;
    const verticalSpan = 10;

    this.camera.left = (-verticalSpan * aspect) / 2;
    this.camera.right = (verticalSpan * aspect) / 2;
    this.camera.top = verticalSpan / 2;
    this.camera.bottom = -verticalSpan / 2;
    this.camera.updateProjectionMatrix();

    const clusterX = this.side === "left"
      ? Math.max(-0.45, this.camera.right * 0.04)
      : Math.min(0.45, this.camera.left * 0.04);

    this.tiles.forEach((mesh) => {
      mesh.userData.homePosition.x += clusterX - this.getHomeCenterX();
      if (mesh.userData.velocity.lengthSq() < 0.0008) {
        mesh.position.x += clusterX - this.getCurrentCenterX();
      }
    });
  }

  getHomeCenterX() {
    return this.tiles.reduce(
      (sum, tile) => sum + tile.userData.homePosition.x,
      0
    ) / this.tiles.length;
  }

  getCurrentCenterX() {
    return this.tiles.reduce(
      (sum, tile) => sum + tile.position.x,
      0
    ) / this.tiles.length;
  }

  updateTile(mesh, elapsed, delta) {
    const data = mesh.userData;

    const target = data.homePosition.clone();
    if (!reducedMotion) {
      target.y += Math.sin(elapsed * 0.72 + data.phase) * 0.055;
    }

    const acceleration = target
      .clone()
      .sub(mesh.position)
      .multiplyScalar(18.5);

    data.velocity.addScaledVector(acceleration, delta);
    data.velocity.multiplyScalar(Math.exp(-6.3 * delta));
    mesh.position.addScaledVector(data.velocity, delta);

    const angularStep = data.angularVelocity.clone().multiplyScalar(delta);
    const angularQuaternion = new THREE.Quaternion().setFromEuler(
      new THREE.Euler(
        angularStep.x,
        angularStep.y,
        angularStep.z,
        "XYZ"
      )
    );

    mesh.quaternion.multiply(angularQuaternion);
    data.angularVelocity.multiplyScalar(Math.exp(-5.7 * delta));

    const rotationBlend = 1 - Math.exp(-4.5 * delta);
    mesh.quaternion.slerp(data.homeQuaternion, rotationBlend);

    data.frontMaterial.uniforms.uTime.value = elapsed;
  }

  animate() {
    const delta = Math.min(this.clock.getDelta(), 1 / 30);
    const elapsed = this.clock.elapsedTime;

    const targetCameraX = reducedMotion ? 0 : this.pointer.x * 0.10;
    const targetCameraY = reducedMotion ? 0 : this.pointer.y * 0.07;

    this.camera.position.x += (targetCameraX - this.camera.position.x) * 0.035;
    this.camera.position.y += (targetCameraY - this.camera.position.y) * 0.035;
    this.camera.lookAt(
      this.camera.position.x * 0.10,
      this.camera.position.y * 0.10,
      0
    );

    this.tiles.forEach((mesh) => this.updateTile(mesh, elapsed, delta));

    this.amberLight.position.y = 1.7 + Math.sin(elapsed * 0.42) * 1.4;
    this.cyanLight.position.y = -2.0 + Math.cos(elapsed * 0.36) * 1.1;

    this.renderer.render(this.scene, this.camera);
  }
}

const leftCluster = new SideCluster(leftCanvas, "left");
const rightCluster = new SideCluster(rightCanvas, "right");

function layoutSideCanvases() {
  const rect = terminal.getBoundingClientRect();

  const leftWidth = Math.max(0, Math.floor(rect.left));
  const rightWidth = Math.max(0, Math.floor(window.innerWidth - rect.right));

  leftCanvas.style.width = `${leftWidth}px`;
  rightCanvas.style.width = `${rightWidth}px`;

  leftCluster.resize(leftWidth, window.innerHeight);
  rightCluster.resize(rightWidth, window.innerHeight);

  leftCanvas.classList.toggle("is-ready", leftWidth >= 150);
  rightCanvas.classList.toggle("is-ready", rightWidth >= 150);
}

window.addEventListener("resize", layoutSideCanvases, { passive: true });

const terminalResizeObserver = new ResizeObserver(layoutSideCanvases);
terminalResizeObserver.observe(terminal);

layoutSideCanvases();

}
initializeSideAnimation().catch(() => { document.querySelector('.side-animation-layer')?.remove(); });
