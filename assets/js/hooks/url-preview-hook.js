const URLPreviewHook = {
  mounted() {
    this.decryptAndDisplayImage();
  },

  updated() {
    this.decryptAndDisplayImage();
  },

  decryptAndDisplayImage() {
    const postId = this.el.dataset.postId;
    const imageHash = this.el.dataset.imageHash;
    const urlPreviewFetchedAt = this.el.dataset.urlPreviewFetchedAt;
    const img = this.el.querySelector("img");

    if (!imageHash || !urlPreviewFetchedAt || !img) {
      return;
    }

    const currentSrc = img.src;

    if (currentSrc && currentSrc.startsWith("data:image")) {
      return;
    }

    this.checkAndHandleImage(postId, imageHash, urlPreviewFetchedAt, img);
  },

  checkAndHandleImage(postId, imageHash, urlPreviewFetchedAt, img) {
    const URL_EXPIRES_IN = 600000;
    const OFFSET_SECONDS = 200;

    const fetchedAt = new Date(urlPreviewFetchedAt);
    const expirationTime = new Date(
      fetchedAt.getTime() + URL_EXPIRES_IN * 1000
    );
    const offsetTime = new Date(
      expirationTime.getTime() - OFFSET_SECONDS * 1000
    );
    const now = new Date();

    const presignedUrl = img.src;

    if (now > offsetTime) {
      this.regenerateAndDecryptPreviewUrl(imageHash, postId, img);
    } else {
      this.fetchAndDecryptImage(presignedUrl, postId, img);
    }
  },

  regenerateAndDecryptPreviewUrl(imageHash, postId, img) {
    this.showLoadingState(img);

    this.pushEvent(
      "regenerate_preview_url",
      { image_hash: imageHash, post_id: postId },
      (reply, _ref) => {
        if (reply.response === "success" && reply.presigned_url) {
          this.fetchAndDecryptImage(reply.presigned_url, postId, img);
        } else {
          console.error("Failed to regenerate preview URL for post", postId);
          this.showErrorState(img);
        }
      }
    );
  },

  fetchAndDecryptImage(presignedUrl, postId, img) {
    this.showLoadingState(img);

    this.pushEvent(
      "decrypt_url_preview_image",
      { presigned_url: presignedUrl, post_id: postId },
      (reply, _ref) => {
        if (reply.response === "success" && reply.decrypted_image) {
          img.src = reply.decrypted_image;
          this.hideLoadingState(img);
        } else {
          console.error(
            "Failed to decrypt preview image for post",
            postId,
            reply
          );
          this.showErrorState(img);
        }
      }
    );
  },

  showLoadingState(img) {
    const container = img.parentElement;
    if (container) {
      container.classList.add("animate-pulse");
      img.style.opacity = "0.5";
    }
  },

  hideLoadingState(img) {
    const container = img.parentElement;
    if (container) {
      container.classList.remove("animate-pulse");
      img.style.opacity = "1";
    }
  },

  showErrorState(img) {
    const container = img.parentElement;
    if (container) {
      container.style.display = "none";
    }
  },
};

export default URLPreviewHook;
