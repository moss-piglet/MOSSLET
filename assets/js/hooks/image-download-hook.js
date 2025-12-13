const ImageDownloadHook = {
  mounted() {
    this.downloadTimer = null;
    this.focusCheckInterval = null;
    this.boundHandleFocus = null;

    this.handleEvent("download-image", ({ data, filename, mime_type, url }) => {
      if (data && mime_type) {
        this.downloadFromBase64(data, filename, mime_type);
      } else if (url) {
        this.downloadFromUrl(url, filename);
      }
    });

    this.handleEvent("download-file", ({ url, filename }) => {
      this.downloadFromUrl(url, filename);
      this.setupDownloadCompletionListener();
    });
  },

  destroyed() {
    this.cleanupDownloadListeners();
  },

  cleanupDownloadListeners() {
    if (this.downloadTimer) {
      clearTimeout(this.downloadTimer);
      this.downloadTimer = null;
    }
    if (this.focusCheckInterval) {
      clearInterval(this.focusCheckInterval);
      this.focusCheckInterval = null;
    }
    if (this.boundHandleFocus) {
      window.removeEventListener("focus", this.boundHandleFocus);
      this.boundHandleFocus = null;
    }
  },

  setupDownloadCompletionListener() {
    this.cleanupDownloadListeners();

    const scrollPosition =
      window.pageYOffset || document.documentElement.scrollTop;

    const restoreScroll = () => {
      window.scrollTo(0, scrollPosition);
      this.pushEvent("restore-body-scroll", {
        scroll_position: scrollPosition,
      });
      this.cleanupDownloadListeners();
    };

    this.downloadTimer = setTimeout(() => {
      restoreScroll();
    }, 2000);

    this.boundHandleFocus = () => {
      restoreScroll();
    };
    window.addEventListener("focus", this.boundHandleFocus);

    this.focusCheckInterval = setInterval(() => {
      if (document.hasFocus()) {
        restoreScroll();
      }
    }, 500);

    setTimeout(() => {
      this.cleanupDownloadListeners();
    }, 10000);
  },

  downloadFromBase64(base64Data, filename, mimeType) {
    try {
      const byteCharacters = atob(base64Data);
      const byteNumbers = new Array(byteCharacters.length);

      for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
      }

      const byteArray = new Uint8Array(byteNumbers);
      const blob = new Blob([byteArray], { type: mimeType });

      const blobUrl = URL.createObjectURL(blob);
      this.downloadFromUrl(blobUrl, filename);

      setTimeout(() => {
        URL.revokeObjectURL(blobUrl);
      }, 1000);
    } catch (error) {
      console.error("ImageDownloadHook: Failed to download from base64", error);
    }
  },

  downloadFromUrl(url, filename) {
    if (!url || !filename) {
      return;
    }

    try {
      const link = document.createElement("a");
      link.href = url;
      link.download = filename;
      link.style.display = "none";
      link.setAttribute("aria-hidden", "true");

      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (error) {
      console.error("ImageDownloadHook: Failed to download image", error);
    }
  },
};

export default ImageDownloadHook;
