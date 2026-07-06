/**
 * Sinh dữ liệu điện giả lập — cùng logic với app Flutter.
 * Chu kỳ: chờ → sạc → cảnh báo → sạc lại.
 */
class FakeElectricGenerator {
  constructor() {
    this.tick = 0;
    this.energy = 0.12;
    this.cycleLength = 36;
  }

  next() {
    this.tick++;
    const now = new Date();
    const phase = this.tick % this.cycleLength;

    let current = 0;
    let alarm = 0;
    const voltage = 218 + Math.random() * 6;

    if (phase >= 3 && phase < 22) {
      const progress = (phase - 3) / 19;
      current = 4 + progress * 11 + Math.random() * 0.8;
    } else if (phase >= 22 && phase < 25) {
      current = 8 + Math.random();
      alarm = 1;
    } else if (phase >= 25 && phase < 34) {
      const progress = (phase - 25) / 9;
      current = 14 - progress * 10 + Math.random() * 0.5;
    }

    if (current > 0.1) {
      this.energy += (voltage * current) / 1000 / 30;
    }

    const power = (voltage * current) / 1000;

    return {
      voltage: parseFloat(voltage.toFixed(1)),
      current: parseFloat(current.toFixed(2)),
      power: parseFloat(power.toFixed(2)),
      energy: parseFloat(this.energy.toFixed(3)),
      alarm,
      hour: now.getHours(),
      minute: now.getMinutes(),
    };
  }

  reset() {
    this.tick = 0;
    this.energy = 0.12;
  }
}

window.FakeElectricGenerator = FakeElectricGenerator;
