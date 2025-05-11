export const Drag = {
  mounted() {
    this.el.addEventListener("dragstart", (e) => {
      e.dataTransfer.setData("text/plain", this.el.dataset.animal);
    });
  }
}

export const Drop = {
  mounted() {
    this.el.addEventListener("dragover", (e) => {
      e.preventDefault();
    });

    this.el.addEventListener("drop", (e) => {
      e.preventDefault();
      const draggedAnimal = e.dataTransfer.getData("text/plain");
      const slot = this.el.dataset.slot;
      const droppedOnAnimal = this.el.querySelector("[data-animal]")?.dataset?.animal;

      if (slot && draggedAnimal) {
        this.pushEvent("drop_animal", {
          slot: slot,
          animal: draggedAnimal,
          displaced: droppedOnAnimal || null
        });
      }
    });
  }
}
