const MAX_DIMENSION = 1280;
const JPEG_QUALITY = 0.85;

async function resizeImage(file) {
  if (!file.type.startsWith("image/")) {
    return file;
  }

  if (file.type === "image/heic" || file.type === "image/heif") {
    return file;
  }

  return new Promise((resolve) => {
    const img = new Image();
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d");

    img.onload = () => {
      let { width, height } = img;

      if (width <= MAX_DIMENSION && height <= MAX_DIMENSION) {
        URL.revokeObjectURL(img.src);
        resolve(file);
        return;
      }

      if (width > height) {
        if (width > MAX_DIMENSION) {
          height = Math.round((height * MAX_DIMENSION) / width);
          width = MAX_DIMENSION;
        }
      } else {
        if (height > MAX_DIMENSION) {
          width = Math.round((width * MAX_DIMENSION) / height);
          height = MAX_DIMENSION;
        }
      }

      canvas.width = width;
      canvas.height = height;
      ctx.drawImage(img, 0, 0, width, height);

      canvas.toBlob(
        (blob) => {
          URL.revokeObjectURL(img.src);
          if (blob) {
            const resizedFile = new File(
              [blob],
              file.name.replace(/\.[^.]+$/, ".jpg"),
              {
                type: "image/jpeg",
                lastModified: file.lastModified,
              }
            );
            resolve(resizedFile);
          } else {
            resolve(file);
          }
        },
        "image/jpeg",
        JPEG_QUALITY
      );
    };

    img.onerror = () => {
      URL.revokeObjectURL(img.src);
      resolve(file);
    };

    img.src = URL.createObjectURL(file);
  });
}

async function processFiles(files) {
  const processed = await Promise.all(Array.from(files).map(resizeImage));
  return processed;
}

const ImageResizeUploadHook = {
  mounted() {
    const input = this.el.querySelector('input[type="file"]');
    if (!input) return;

    this.input = input;
    this.uploadName = input.getAttribute("name").replace("[]", "");

    this.handleChange = async (e) => {
      if (!e.target.files || e.target.files.length === 0) return;
      if (!e.isTrusted) return;

      e.stopImmediatePropagation();
      e.preventDefault();

      const resizedFiles = await processFiles(e.target.files);

      this.upload(this.uploadName, resizedFiles);
    };

    this.handleDrop = async (e) => {
      if (!e.dataTransfer?.files || e.dataTransfer.files.length === 0) return;
      if (!e.isTrusted) return;

      e.stopImmediatePropagation();
      e.preventDefault();

      const resizedFiles = await processFiles(e.dataTransfer.files);

      this.upload(this.uploadName, resizedFiles);
    };

    input.addEventListener("change", this.handleChange, { capture: true });
    this.el.addEventListener("drop", this.handleDrop, { capture: true });
  },

  destroyed() {
    if (this.input && this.handleChange) {
      this.input.removeEventListener("change", this.handleChange, {
        capture: true,
      });
    }
    if (this.handleDrop) {
      this.el.removeEventListener("drop", this.handleDrop, { capture: true });
    }
  },
};

export default ImageResizeUploadHook;
