/*
 * Hook for handling image downloads and post-download UX.
 *
 * Listens for "download-image" events from the server and initiates
 * a download by creating a temporary anchor element with the download attribute.
 * Also handles post-download scroll restoration.
 */
const ImageDownloadHook = {
  mounted() {
    this.handleEvent("download-image", ({ data, filename, mime_type, url }) => {
      if (data && mime_type) {
        // Handle base64 data downloads
        this.downloadFromBase64(data, filename, mime_type);
      } else if (url) {
        // Handle URL downloads (fallback)
        this.downloadFromUrl(url, filename);
      } else {
        console.warn(
          "ImageDownloadHook: Missing data, url, or mime_type for download"
        );
      }
    });

    // Listen for download file events
    this.handleEvent("download-file", ({ url, filename }) => {
      this.downloadFromUrl(url, filename);
      // Restore scroll after download starts
      setTimeout(() => {
        this.pushEvent("restore-body-scroll", {});
      }, 500);
    });
  },

  setupDownloadCompletionListener() {
    // Store current scroll position
    const scrollPosition =
      window.pageYOffset || document.documentElement.scrollTop;

    // For downloads, we need to detect when the download actually completes
    // Method 1: Use a timer-based approach with focus detection
    let downloadTimer;
    let focusCheckInterval;

    const restoreScroll = () => {
      window.scrollTo(0, scrollPosition);
      this.pushEvent("restore-body-scroll", {
        scroll_position: scrollPosition,
      });

      if (downloadTimer) clearTimeout(downloadTimer);
      if (focusCheckInterval) clearInterval(focusCheckInterval);
    };

    // Method 1: Simple timer fallback (most reliable)
    downloadTimer = setTimeout(() => {
      restoreScroll();
    }, 2000); // Restore after 2 seconds

    // Method 2: Focus detection (for when user clicks back to tab)
    const handleFocus = () => {
      restoreScroll();
      window.removeEventListener("focus", handleFocus);
    };

    window.addEventListener("focus", handleFocus);

    // Method 3: Interval check for document focus
    focusCheckInterval = setInterval(() => {
      if (document.hasFocus()) {
        restoreScroll();
      }
    }, 500);

    // Cleanup after 10 seconds regardless
    setTimeout(() => {
      window.removeEventListener("focus", handleFocus);
      if (downloadTimer) clearTimeout(downloadTimer);
      if (focusCheckInterval) clearInterval(focusCheckInterval);
    }, 10000);
  },

  destroyed() {
    // Clean up any pending downloads or temporary elements if needed
  },

  downloadFromBase64(base64Data, filename, mimeType) {
    try {
      // Convert base64 to blob
      const byteCharacters = atob(base64Data);
      const byteNumbers = new Array(byteCharacters.length);

      for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
      }

      const byteArray = new Uint8Array(byteNumbers);
      const blob = new Blob([byteArray], { type: mimeType });

      // Create object URL and download
      const blobUrl = URL.createObjectURL(blob);
      this.downloadFromUrl(blobUrl, filename);

      // Clean up object URL after a short delay
      setTimeout(() => {
        URL.revokeObjectURL(blobUrl);
      }, 1000);
    } catch (error) {
      console.error("ImageDownloadHook: Failed to download from base64", error);
    }
  },

  downloadFromUrl(url, filename) {
    if (!url || !filename) {
      console.warn("ImageDownloadHook: Missing url or filename for download");
      return;
    }

    try {
      // Create a temporary anchor element to trigger download
      const link = document.createElement("a");
      link.href = url;
      link.download = filename;
      link.style.display = "none";
      link.setAttribute("aria-hidden", "true");

      // Add to DOM, click, and remove
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (error) {
      console.error("ImageDownloadHook: Failed to download image", error);
    }
  },
};

export default ImageDownloadHook;
