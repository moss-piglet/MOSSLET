// Modern stepper for the per-seat number input on the subscribe page.
// Wires the - / + buttons (data-seat-step) to the numeric input, clamping to
// the input's own min/max so the server-side clamp is never the first guardrail.
const SeatStepper = {
  mounted() {
    this.input = this.el.querySelector('input[type="number"]');
    if (!this.input) return;

    this.buttons = this.el.querySelectorAll("[data-seat-step]");
    this.buttons.forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        this.step(parseInt(btn.dataset.seatStep, 10));
      });
    });

    this.input.addEventListener("input", () => this.syncDisabled());
    this.syncDisabled();
  },

  step(delta) {
    const min = this.numAttr("min", 1);
    const max = this.numAttr("max", null);
    const current = parseInt(this.input.value, 10) || min;

    let next = current + delta;
    if (next < min) next = min;
    if (max !== null && next > max) next = max;

    if (next !== current) {
      this.input.value = next;
      this.input.dispatchEvent(new Event("input", { bubbles: true }));
    }
    this.syncDisabled();
  },

  numAttr(name, fallback) {
    const v = this.input.getAttribute(name);
    return v === null || v === "" ? fallback : parseInt(v, 10);
  },

  syncDisabled() {
    const min = this.numAttr("min", 1);
    const max = this.numAttr("max", null);
    const current = parseInt(this.input.value, 10) || min;

    this.buttons.forEach((btn) => {
      const delta = parseInt(btn.dataset.seatStep, 10);
      const atMin = delta < 0 && current <= min;
      const atMax = delta > 0 && max !== null && current >= max;
      btn.disabled = atMin || atMax;
    });
  },
};

export default SeatStepper;
