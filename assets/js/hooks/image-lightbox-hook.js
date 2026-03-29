const ImageLightbox = {
  mounted() {
    this.container = this.el;
    this.backdrop = this.el.querySelector("#conversation-image-lightbox-backdrop");
    this.img = this.el.querySelector("#conversation-image-lightbox-img");
    this.closeBtn = this.el.querySelector("#conversation-image-lightbox-close");
    this.downloadBtn = this.el.querySelector("#conversation-image-lightbox-download");
    this.originalParent = this.el.parentNode;
    this.originalNextSibling = this.el.nextSibling;

    this.el._lightboxHook = this;

    this.closeBtn.addEventListener("click", () => this.close());
    this.backdrop.addEventListener("click", () => this.close());

    this._keyHandler = (e) => {
      if (e.key === "Escape" && !this.container.classList.contains("hidden")) {
        this.close();
      }
    };
    window.addEventListener("keydown", this._keyHandler);
  },

  destroyed() {
    window.removeEventListener("keydown", this._keyHandler);
    if (this.el.parentNode === document.body) {
      document.body.removeChild(this.el);
    }
  },

  open(dataUrl) {
    const allowDownload = this.el.dataset.allowDownload === "true";

    document.body.appendChild(this.el);

    this.img.src = dataUrl;
    this.container.classList.remove("hidden");

    if (allowDownload) {
      this.downloadBtn.href = dataUrl;
      this.downloadBtn.classList.remove("hidden");
    } else {
      this.downloadBtn.classList.add("hidden");
    }

    requestAnimationFrame(() => {
      this.backdrop.classList.remove("opacity-0");
      this.backdrop.classList.add("opacity-100");
      this.img.classList.remove("scale-95", "opacity-0");
      this.img.classList.add("scale-100", "opacity-100");
    });
  },

  close() {
    this.backdrop.classList.remove("opacity-100");
    this.backdrop.classList.add("opacity-0");
    this.img.classList.remove("scale-100", "opacity-100");
    this.img.classList.add("scale-95", "opacity-0");

    setTimeout(() => {
      this.container.classList.add("hidden");
      this.img.src = "";
      this.downloadBtn.href = "#";
      if (this.originalNextSibling) {
        this.originalParent.insertBefore(this.el, this.originalNextSibling);
      } else {
        this.originalParent.appendChild(this.el);
      }
    }, 300);
  },
};

export default ImageLightbox;
