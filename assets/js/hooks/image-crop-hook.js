const ImageCropHook = {
  mounted() {
    this.ref = this.el.dataset.ref;
    this.container = this.el;
    this.image = this.el.querySelector(`#crop-image-${this.ref}`);
    this.overlay = this.el.querySelector(`#crop-overlay-${this.ref}`);
    
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
    `;
    
    const handles = ["nw", "ne", "sw", "se"];
    handles.forEach(pos => {
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
    
    const rect = this.image.getBoundingClientRect();
    const containerRect = this.container.getBoundingClientRect();
    
    const imgLeft = rect.left - containerRect.left;
    const imgTop = rect.top - containerRect.top;
    const imgWidth = rect.width;
    const imgHeight = rect.height;
    
    if (savedCrop && savedCrop.x !== undefined) {
      this.cropBox.style.left = `${imgLeft + savedCrop.x * imgWidth}px`;
      this.cropBox.style.top = `${imgTop + savedCrop.y * imgHeight}px`;
      this.cropBox.style.width = `${savedCrop.width * imgWidth}px`;
      this.cropBox.style.height = `${savedCrop.height * imgHeight}px`;
    } else {
      const padding = 20;
      this.cropBox.style.left = `${imgLeft + padding}px`;
      this.cropBox.style.top = `${imgTop + padding}px`;
      this.cropBox.style.width = `${imgWidth - padding * 2}px`;
      this.cropBox.style.height = `${imgHeight - padding * 2}px`;
    }
    
    this.bindEvents();
  },
  
  bindEvents() {
    this.cropBox.addEventListener("mousedown", (e) => this.startDrag(e));
    this.cropBox.addEventListener("touchstart", (e) => this.startDrag(e), { passive: false });
    
    this.cropBox.querySelectorAll(".crop-handle").forEach(handle => {
      handle.addEventListener("mousedown", (e) => this.startResize(e, handle.dataset.handle));
      handle.addEventListener("touchstart", (e) => this.startResize(e, handle.dataset.handle), { passive: false });
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
    const rect = this.image.getBoundingClientRect();
    const containerRect = this.container.getBoundingClientRect();
    
    const imgLeft = rect.left - containerRect.left;
    const imgTop = rect.top - containerRect.top;
    const imgWidth = rect.width;
    const imgHeight = rect.height;
    
    if (this.isDragging) {
      let newLeft = coords.x - this.startX;
      let newTop = coords.y - this.startY;
      
      newLeft = Math.max(imgLeft, Math.min(newLeft, imgLeft + imgWidth - this.cropBox.offsetWidth));
      newTop = Math.max(imgTop, Math.min(newTop, imgTop + imgHeight - this.cropBox.offsetHeight));
      
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
      
      if (this.resizeHandle.includes("e")) {
        newWidth = Math.max(40, this.startWidth + deltaX);
      }
      if (this.resizeHandle.includes("w")) {
        newWidth = Math.max(40, this.startWidth - deltaX);
        newLeft = this.startLeft + (this.startWidth - newWidth);
      }
      if (this.resizeHandle.includes("s")) {
        newHeight = Math.max(40, this.startHeight + deltaY);
      }
      if (this.resizeHandle.includes("n")) {
        newHeight = Math.max(40, this.startHeight - deltaY);
        newTop = this.startTop + (this.startHeight - newHeight);
      }
      
      newLeft = Math.max(imgLeft, newLeft);
      newTop = Math.max(imgTop, newTop);
      newWidth = Math.min(newWidth, imgLeft + imgWidth - newLeft);
      newHeight = Math.min(newHeight, imgTop + imgHeight - newTop);
      
      this.cropBox.style.left = `${newLeft}px`;
      this.cropBox.style.top = `${newTop}px`;
      this.cropBox.style.width = `${newWidth}px`;
      this.cropBox.style.height = `${newHeight}px`;
    }
  },
  
  endDrag() {
    this.isDragging = false;
    this.isResizing = false;
    this.resizeHandle = null;
  },
  
  saveCrop() {
    const rect = this.image.getBoundingClientRect();
    const containerRect = this.container.getBoundingClientRect();
    
    const imgLeft = rect.left - containerRect.left;
    const imgTop = rect.top - containerRect.top;
    const imgWidth = rect.width;
    const imgHeight = rect.height;
    
    const boxLeft = this.cropBox.offsetLeft;
    const boxTop = this.cropBox.offsetTop;
    const boxWidth = this.cropBox.offsetWidth;
    const boxHeight = this.cropBox.offsetHeight;
    
    const x = (boxLeft - imgLeft) / imgWidth;
    const y = (boxTop - imgTop) / imgHeight;
    const width = boxWidth / imgWidth;
    const height = boxHeight / imgHeight;
    
    const isFullImage = x <= 0.05 && y <= 0.05 && width >= 0.9 && height >= 0.9;
    
    const crop = isFullImage ? {} : {
      x: Math.max(0, Math.min(1, x)),
      y: Math.max(0, Math.min(1, y)),
      width: Math.max(0, Math.min(1, width)),
      height: Math.max(0, Math.min(1, height))
    };
    
    this.pushEvent("save_image_crop", { ref: this.ref, crop: crop });
  },
  
  destroyed() {
    document.removeEventListener("mousemove", this.onMove);
    document.removeEventListener("touchmove", this.onMove);
    document.removeEventListener("mouseup", this.endDrag);
    document.removeEventListener("touchend", this.endDrag);
  }
};

export default ImageCropHook;
