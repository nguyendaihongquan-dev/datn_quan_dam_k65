/**
 * Animation luồng điện: Lưới điện → Trạm sạc → Pin xe
 * Port từ ChargingStationAnimation (Flutter).
 */
class ChargingFlowAnimation {
  constructor(canvasId = 'flowCanvas') {
    this.canvas = document.getElementById(canvasId);
    this.ctx = this.canvas?.getContext('2d');
    this.state = 'idle'; // idle | charging | alarm
    this.isFlowing = false;
    this.progress = 0;
    this.pulse = 0.6;
    this.pulseDir = 1;
    this.rafId = null;
    this.lastTs = 0;

    this.colors = {
      primary: '#00e676',
      accent: '#40c4ff',
      warning: '#ff5252',
      surfaceLight: '#171f30',
    };

    this._resizeObserver = null;
    this._onResize = () => this._resize();
    if (this.canvas) {
      this._resize();
      window.addEventListener('resize', this._onResize);
    }
  }

  _resize() {
    if (!this.canvas) return;
    const parent = this.canvas.parentElement;
    const w = parent?.clientWidth || 600;
    const h = 200;
    const dpr = window.devicePixelRatio || 1;
    this.canvas.width = w * dpr;
    this.canvas.height = h * dpr;
    this.canvas.style.width = `${w}px`;
    this.canvas.style.height = `${h}px`;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.width = w;
    this.height = h;
    this._draw();
  }

  get accentColor() {
    return this.state === 'alarm' ? this.colors.warning : this.colors.primary;
  }

  setState(state, isFlowing = null) {
    const prevState = this.state;
    const wasFlowing = this.isFlowing;
    const nextFlowing = isFlowing ?? (state === 'charging' || state === 'alarm');
    this.state = state;
    this.isFlowing = nextFlowing;

    document.getElementById('chargingDiagram')?.classList.remove(
      'charging-diagram--idle',
      'charging-diagram--charging',
      'charging-diagram--alarm',
    );
    document.getElementById('chargingDiagram')?.classList.add(
      `charging-diagram--${state}`,
    );

    if (this.isFlowing) {
      if (!this.rafId || !wasFlowing) {
        this.lastTs = 0;
        this._stopLoop();
        this._loop();
      }
    } else {
      this._stopLoop();
      this.lastTs = 0;
      this.progress = 0;
      this.pulse = 0.6;
      this._draw();
    }

    return prevState !== state || wasFlowing !== nextFlowing;
  }

  resize() {
    this._resize();
  }

  _stopLoop() {
    if (this.rafId) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
  }

  _loop(ts = 0) {
    const dt = this.lastTs ? (ts - this.lastTs) / 1000 : 0;
    this.lastTs = ts;

    this.progress = (this.progress + dt / 1.8) % 1;
    this.pulse += this.pulseDir * dt * 0.8;
    if (this.pulse >= 1) { this.pulse = 1; this.pulseDir = -1; }
    if (this.pulse <= 0.6) { this.pulse = 0.6; this.pulseDir = 1; }

    this._draw();
    this.rafId = requestAnimationFrame((t) => this._loop(t));
  }

  _draw() {
    if (!this.ctx || !this.width) return;
    const ctx = this.ctx;
    const w = this.width;
    const h = this.height;

    ctx.clearRect(0, 0, w, h);

    if (!this.isFlowing) {
      this._drawIdleLine(ctx, w, h);
      return;
    }

    const centerY = h / 2;
    const leftX = w * 0.18;
    const midX = w * 0.5;
    const rightX = w * 0.82;
    const color = this.accentColor;

    this._drawAnimatedPath(ctx, leftX + 28, centerY, (leftX + midX) / 2, centerY - 30, midX, centerY, color);
    this._drawAnimatedPath(ctx, midX, centerY, (midX + rightX) / 2, centerY + 30, rightX - 28, centerY, color);
  }

  _drawIdleLine(ctx, w, h) {
    const centerY = h / 2;
    ctx.strokeStyle = this.colors.surfaceLight;
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(w * 0.22, centerY);
    ctx.lineTo(w * 0.78, centerY);
    ctx.stroke();
  }

  _drawAnimatedPath(ctx, x1, y1, cx, cy, x2, y2, color) {
    const path = new Path2D();
    path.moveTo(x1, y1);
    path.quadraticCurveTo(cx, cy, x2, y2);

    ctx.strokeStyle = this._hexAlpha(color, 0.15);
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.stroke(path);

    const len = this._quadLength(x1, y1, cx, cy, x2, y2);
    for (let i = 0; i < 3; i++) {
      const t = (this.progress + i * 0.33) % 1;
      const pt = this._quadPoint(x1, y1, cx, cy, x2, y2, t);
      ctx.beginPath();
      ctx.arc(pt.x, pt.y, 4, 0, Math.PI * 2);
      ctx.fillStyle = this._hexAlpha(color, 0.9 * this.pulse);
      ctx.shadowColor = color;
      ctx.shadowBlur = 8;
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.beginPath();
      ctx.arc(pt.x, pt.y, 2, 0, Math.PI * 2);
      ctx.fillStyle = '#ffffff';
      ctx.fill();
    }

    const grad = ctx.createLinearGradient(0, 0, this.width, this.height);
    const p = this.progress;
    grad.addColorStop(Math.max(0, p - 0.15), 'transparent');
    grad.addColorStop(p, this._hexAlpha(color, 0.8));
    grad.addColorStop(Math.min(1, p + 0.15), 'transparent');
    ctx.strokeStyle = grad;
    ctx.lineWidth = 3;
    ctx.stroke(path);
  }

  _quadPoint(x1, y1, cx, cy, x2, y2, t) {
    const u = 1 - t;
    return {
      x: u * u * x1 + 2 * u * t * cx + t * t * x2,
      y: u * u * y1 + 2 * u * t * cy + t * t * y2,
    };
  }

  _quadLength(x1, y1, cx, cy, x2, y2) {
    let len = 0;
    let px = x1; let py = y1;
    for (let i = 1; i <= 20; i++) {
      const t = i / 20;
      const pt = this._quadPoint(x1, y1, cx, cy, x2, y2, t);
      len += Math.hypot(pt.x - px, pt.y - py);
      px = pt.x; py = pt.y;
    }
    return len;
  }

  _hexAlpha(hex, alpha) {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return `rgba(${r},${g},${b},${alpha})`;
  }

  destroy() {
    this._stopLoop();
    window.removeEventListener('resize', this._onResize);
  }
}

window.ChargingFlowAnimation = ChargingFlowAnimation;
