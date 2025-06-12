let AutoAdvanceInput = {
  mounted() {
    this.focusIfFirst();
    this.attachEvents();
  },
  updated() {
    this.focusIfFirst();
  },
  focusIfFirst() {
    if (
      this.el.dataset.index === "0" &&
      this.el.value === "" &&
      document.activeElement !== this.el
    ) {
      setTimeout(() => this.el.focus(), 100);
    }
  },
  attachEvents() {
    this.el.addEventListener("input", (e) => {
      const value = this.el.value;
      if (value.length === 1 && /^[0-9]$/.test(value)) {
        const next = document.querySelector(`#input-${parseInt(this.el.dataset.index) + 1}`);
        if (next) setTimeout(() => next.focus(), 50);
      }
    });
    this.el.addEventListener("keydown", (e) => {
      const idx = parseInt(this.el.dataset.index);
      // Enter = avançar, já tinhas
      if (e.key === "Enter") {
        e.preventDefault();
        const next = document.querySelector(`#input-${idx + 1}`);
        if (next) {
          next.focus();
        } else {
          document.getElementById("reverse-sequence-form").requestSubmit();
        }
      }
      if (e.key === "ArrowRight") {
        e.preventDefault();
        const next = document.querySelector(`#input-${idx + 1}`);
        if (next) next.focus();
      }
      if (e.key === "ArrowLeft") {
        e.preventDefault();
        const prev = document.querySelector(`#input-${idx - 1}`);
        if (prev) prev.focus();
      }
    });
  }
}
export default AutoAdvanceInput;
