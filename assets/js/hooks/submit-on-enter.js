const SubmitOnEnter = {
  mounted() {
    this.isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      navigator.userAgent
    ) || (navigator.maxTouchPoints > 0 && window.innerWidth < 768);

    if (this.isMobile) return;

    this.handleKeydown = (e) => {
      if (e.key === "Enter" && !e.shiftKey && !e.ctrlKey && !e.altKey && !e.metaKey) {
        const value = this.el.value.trim();
        if (value) {
          e.preventDefault();
          const form = this.el.closest("form");
          if (form) {
            const formData = new FormData(form);
            const params = {};
            for (const [key, val] of formData.entries()) {
              const keys = key.match(/[^\[\]]+/g);
              if (keys.length === 1) {
                params[keys[0]] = val;
              } else {
                let obj = params;
                for (let i = 0; i < keys.length - 1; i++) {
                  obj[keys[i]] = obj[keys[i]] || {};
                  obj = obj[keys[i]];
                }
                obj[keys[keys.length - 1]] = val;
              }
            }

            this.el.value = "";
            this.el.dispatchEvent(new Event("input", { bubbles: true }));

            const target = form.getAttribute("phx-target");
            if (target) {
              this.pushEventTo(target, "save", params);
            } else {
              this.pushEvent("save", params);
            }
          }
        }
      }
    };

    this.el.addEventListener("keydown", this.handleKeydown);
  },

  destroyed() {
    if (this.handleKeydown) {
      this.el.removeEventListener("keydown", this.handleKeydown);
    }
  }
};

export default SubmitOnEnter;
