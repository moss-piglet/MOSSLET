const Menu = {
  getAttr(name) {
    let val = this.el.getAttribute(name);
    if (val === null) {
      throw new Error(`no ${name} attribute configured for menu`);
    }
    return val;
  },
  reset() {
    this.enabled = false;
    this.activeClass = this.getAttr("data-active-class");
    this.deactivate(this.menuItems());
    this.activeItem = null;
    window.removeEventListener("keydown", this.handleKeyDown);
  },
  destroyed() {
    this.reset();
  },
  mounted() {
    this.menuItemsContainer = document.querySelector(
      `[aria-labelledby="${this.el.id}"]`
    );
    this.reset();
    this.handleKeyDown = (e) => this.onKeyDown(e);
    this.el.addEventListener("keydown", (e) => {
      if (
        (e.key === "Enter" || e.key === " ") &&
        e.currentTarget.isSameNode(this.el)
      ) {
        this.enabled = true;
      }
    });
    this.el.addEventListener("click", (e) => {
      if (!e.currentTarget.isSameNode(this.el)) {
        return;
      }

      window.addEventListener("keydown", this.handleKeyDown);
      // disable if button clicked and click was not a keyboard event
      if (this.enabled) {
        window.requestAnimationFrame(() => this.activate(0));
      }
    });
    this.menuItemsContainer.addEventListener("phx:hide-start", () =>
      this.reset()
    );
  },
  activate(index, fallbackIndex) {
    let menuItems = this.menuItems();
    this.activeItem = menuItems[index] || menuItems[fallbackIndex];
    this.activeItem.classList.add(this.activeClass);
    this.activeItem.focus();
  },
  deactivate(items) {
    items.forEach((item) => item.classList.remove(this.activeClass));
  },
  menuItems() {
    return Array.from(
      this.menuItemsContainer.querySelectorAll("[role=menuitem]")
    );
  },
  onKeyDown(e) {
    if (e.key === "Escape") {
      document.body.click();
      this.el.focus();
      this.reset();
    } else if (e.key === "Enter" && !this.activeItem) {
      this.activate(0);
    } else if (e.key === "Enter") {
      this.activeItem.click();
    }
    if (e.key === "ArrowDown") {
      e.preventDefault();
      let menuItems = this.menuItems();
      this.deactivate(menuItems);
      this.activate(menuItems.indexOf(this.activeItem) + 1, 0);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      let menuItems = this.menuItems();
      this.deactivate(menuItems);
      this.activate(
        menuItems.indexOf(this.activeItem) - 1,
        menuItems.length - 1
      );
    } else if (e.key === "Tab") {
      e.preventDefault();
    }
  },
};

export default Menu;
