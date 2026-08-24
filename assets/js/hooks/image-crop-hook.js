const ImageCropHook = {
  mounted() {
    this.ref = this.el.dataset.ref;
    this.container = this.el;
    this.image = this.el.querySelector(`#crop-image-${this.ref}`);
    this.overlay = this.el.querySelector(`#crop-overlay-${this.ref}`);
    this.square = this.el.dataset.aspect === "square";

    if (!this.image || !this.overlay) return;

    this.isDragging = false;
    this.isResizing = false;
    this.resizeHandle = null;
    this.startX = 0;
    this.startY = 0;
    this.cropBox = null;

    const savedCrop = JSON.parse(this.el.dataset.crop || "{}");

    this.image.onload = () => {
      this.initCropUI(savedCrop);
    };

    if (this.image.complete) {
      this.initCropUI(savedCrop);
    }

    const saveBtn = document.getElementById(`save-crop-${this.ref}`);
    if (saveBtn) {
      saveBtn.addEventListener("click", () => this.saveCrop());
    }
  },

  // The image is rendered with `object-contain`, so the painted photo may be
  // letterboxed inside the <img> element. All crop math must use the painted
  // rect (element box + letterbox offset), otherwise fractions drift and the
  // server crop doesn't match what the user selected.
  imageRect() {
    const rect = this.image.getBoundingClientRect();
    const containerRect = this.container.getBoundingClientRect();
    const naturalWidth = this.image.naturalWidth || rect.width;
    const naturalHeight = this.image.naturalHeight || rect.height;

    const scale = Math.min(rect.width / naturalWidth, rect.height / naturalHeight);
    const width = naturalWidth * scale;
    const height = naturalHeight * scale;

    return {
      left: rect.left - containerRect.left + (rect.width - width) / 2,
      top: rect.top - containerRect.top + (rect.height - height) / 2,
      width,
      height,
    };
  },

  initCropUI(savedCrop) {
    this.overlay.innerHTML = "";

    this.cropBox = document.createElement("div");
    this.cropBox.className = "crop-box";
    this.cropBox.style.cssText = `
      position: absolute;
      border: 2px dashed #0ea5e9;
      background: transparent;
      cursor: move;
      box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.5);
      pointer-events: auto;
      touch-action: none;
    `;

    const handles = ["nw", "ne", "sw", "se"];
    handles.forEach((pos) => {
      const handle = document.createElement("div");
      handle.className = `crop-handle crop-handle-${pos}`;
      handle.dataset.handle = pos;
      handle.style.cssText = `
        position: absolute;
        width: 12px;
        height: 12px;
        background: #0ea5e9;
        border: 2px solid white;
        border-radius: 2px;
        pointer-events: auto;
        ${pos.includes("n") ? "top: -6px;" : "bottom: -6px;"}
        ${pos.includes("w") ? "left: -6px;" : "right: -6px;"}
        cursor: ${pos}-resize;
      `;
      this.cropBox.appendChild(handle);
    });

    this.overlay.style.pointerEvents = "auto";
    this.overlay.appendChild(this.cropBox);

    const img = this.imageRect();

    if (savedCrop && savedCrop.x !== undefined && savedCrop.width > 0) {
      this.setBox(
        img.left + savedCrop.x * img.width,
        img.top + savedCrop.y * img.height,
        savedCrop.width * img.width,
        savedCrop.height * img.height
      );
    } else {
      // Default to a centered selection covering as much of the image as
      // possible (largest centered square for avatars, full image otherwise).
      let width = img.width;
      let height = img.height;

      if (this.square) {
        const side = Math.min(img.width, img.height);
        width = side;
        height = side;
      }

      this.setBox(
        img.left + (img.width - width) / 2,
        img.top + (img.height - height) / 2,
        width,
        height
      );
    }

    this.bindEvents();
  },

  setBox(left, top, width, height) {
    this.cropBox.style.left = `${left}px`;
    this.cropBox.style.top = `${top}px`;
    this.cropBox.style.width = `${width}px`;
    this.cropBox.style.height = `${height}px`;
  },

  bindEvents() {
    this.cropBox.addEventListener("mousedown", (e) => this.startDrag(e));
    this.cropBox.addEventListener("touchstart", (e) => this.startDrag(e), { passive: false });

    this.cropBox.querySelectorAll(".crop-handle").forEach((handle) => {
      handle.addEventListener("mousedown", (e) => this.startResize(e, handle.dataset.handle));
      handle.addEventListener("touchstart", (e) => this.startResize(e, handle.dataset.handle), {
        passive: false,
      });
    });

    document.addEventListener("mousemove", (e) => this.onMove(e));
    document.addEventListener("touchmove", (e) => this.onMove(e), { passive: false });
    document.addEventListener("mouseup", () => this.endDrag());
    document.addEventListener("touchend", () => this.endDrag());
  },

  getEventCoords(e) {
    if (e.touches && e.touches.length > 0) {
      return { x: e.touches[0].clientX, y: e.touches[0].clientY };
    }
    return { x: e.clientX, y: e.clientY };
  },

  startDrag(e) {
    if (e.target.classList.contains("crop-handle")) return;
    e.preventDefault();

    this.isDragging = true;
    const coords = this.getEventCoords(e);
    this.startX = coords.x - this.cropBox.offsetLeft;
    this.startY = coords.y - this.cropBox.offsetTop;
  },

  startResize(e, handle) {
    e.preventDefault();
    e.stopPropagation();

    this.isResizing = true;
    this.resizeHandle = handle;
    const coords = this.getEventCoords(e);
    this.startX = coords.x;
    this.startY = coords.y;
    this.startWidth = this.cropBox.offsetWidth;
    this.startHeight = this.cropBox.offsetHeight;
    this.startLeft = this.cropBox.offsetLeft;
    this.startTop = this.cropBox.offsetTop;
  },

  onMove(e) {
    if (!this.isDragging && !this.isResizing) return;
    e.preventDefault();

    const coords = this.getEventCoords(e);
    const img = this.imageRect();
    const minSize = 40;

    if (this.isDragging) {
      let newLeft = coords.x - this.startX;
      let newTop = coords.y - this.startY;

      newLeft = Math.max(img.left, Math.min(newLeft, img.left + img.width - this.cropBox.offsetWidth));
      newTop = Math.max(img.top, Math.min(newTop, img.top + img.height - this.cropBox.offsetHeight));

      this.cropBox.style.left = `${newLeft}px`;
      this.cropBox.style.top = `${newTop}px`;
    }

    if (this.isResizing) {
      const deltaX = coords.x - this.startX;
      const deltaY = coords.y - this.startY;

      let newWidth = this.startWidth;
      let newHeight = this.startHeight;
      let newLeft = this.startLeft;
      let newTop = this.startTop;

      if (this.square) {
        // Keep a 1:1 ratio; the dominant delta drives the size.
        const delta = Math.abs(deltaX) > Math.abs(deltaY) ? deltaX : deltaY;
        let side = this.startWidth;

        if (this.resizeHandle.includes("e") || this.resizeHandle.includes("s")) {
          side = this.startWidth + delta;
        }
        if (this.resizeHandle.includes("w") || this.resizeHandle.includes("n")) {
          side = this.startWidth - delta;
        }

        side = Math.max(minSize, side);
        side = Math.min(side, img.width, img.height);

        newWidth = side;
        newHeight = side;

        if (this.resizeHandle.includes("w")) newLeft = this.startLeft + (this.startWidth - side);
        if (this.resizeHandle.includes("n")) newTop = this.startTop + (this.startHeight - side);
      } else {
        if (this.resizeHandle.includes("e")) {
          newWidth = Math.max(minSize, this.startWidth + deltaX);
        }
        if (this.resizeHandle.includes("w")) {
          newWidth = Math.max(minSize, this.startWidth - deltaX);
          newLeft = this.startLeft + (this.startWidth - newWidth);
        }
        if (this.resizeHandle.includes("s")) {
          newHeight = Math.max(minSize, this.startHeight + deltaY);
        }
        if (this.resizeHandle.includes("n")) {
          newHeight = Math.max(minSize, this.startHeight - deltaY);
          newTop = this.startTop + (this.startHeight - newHeight);
        }
      }

      newLeft = Math.max(img.left, newLeft);
      newTop = Math.max(img.top, newTop);
      newWidth = Math.min(newWidth, img.left + img.width - newLeft);
      newHeight = Math.min(newHeight, img.top + img.height - newTop);

      if (this.square) {
        const side = Math.min(newWidth, newHeight);
        newWidth = side;
        newHeight = side;
      }

      this.setBox(newLeft, newTop, newWidth, newHeight);
    }
  },

  endDrag() {
    this.isDragging = false;
    this.isResizing = false;
    this.resizeHandle = null;
  },

  saveCrop() {
    const img = this.imageRect();

    if (img.width === 0 || img.height === 0) {
      this.pushEvent("save_image_crop", { ref: this.ref, crop: {} });
      return;
    }

    const x = (this.cropBox.offsetLeft - img.left) / img.width;
    const y = (this.cropBox.offsetTop - img.top) / img.height;
    const width = this.cropBox.offsetWidth / img.width;
    const height = this.cropBox.offsetHeight / img.height;

    const isFullImage = x <= 0.01 && y <= 0.01 && width >= 0.99 && height >= 0.99;

    const crop = isFullImage
      ? {}
      : {
          x: Math.max(0, Math.min(1, x)),
          y: Math.max(0, Math.min(1, y)),
          width: Math.max(0, Math.min(1 - Math.max(0, x), width)),
          height: Math.max(0, Math.min(1 - Math.max(0, y), height)),
        };

    this.pushEvent("save_image_crop", { ref: this.ref, crop: crop });
  },

  destroyed() {
    document.removeEventListener("mousemove", this.onMove);
    document.removeEventListener("touchmove", this.onMove);
    document.removeEventListener("mouseup", this.endDrag);
    document.removeEventListener("touchend", this.endDrag);
  },
};

export default ImageCropHook;
