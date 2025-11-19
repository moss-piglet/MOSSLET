const PreviewUrlRefreshHook = {
  mounted() {
    this.checkAndRefreshPreviewUrl();
  },

  updated() {
    this.checkAndRefreshPreviewUrl();
  },

  checkAndRefreshPreviewUrl() {
    const postId = this.el.dataset.postId;
    const urlPreviewFetchedAt = this.el.dataset.urlPreviewFetchedAt;
    const imageHash = this.el.dataset.imageHash;

    if (!postId || !urlPreviewFetchedAt || !imageHash) {
      return;
    }

    if (this.isPreviewUrlExpired(urlPreviewFetchedAt)) {
      this.refreshPreviewUrl(postId, imageHash);
    }
  },

  isPreviewUrlExpired(fetchedAt) {
    const URL_EXPIRES_IN = 600000;
    const OFFSET = 200;

    const fetchedAtDate = new Date(fetchedAt);
    const expirationTime = new Date(
      fetchedAtDate.getTime() + URL_EXPIRES_IN * 1000
    );
    const offsetTime = new Date(expirationTime.getTime() - OFFSET * 1000);
    const now = new Date();

    return now >= offsetTime;
  },

  refreshPreviewUrl(postId, imageHash) {
    this.pushEvent(
      "regenerate_preview_url",
      { image_hash: imageHash, post_id: postId },
      (reply, _ref) => {
        if (reply.response === "success" && reply.presigned_url) {
          const img = this.el.querySelector("img");
          if (img) {
            img.src = reply.presigned_url;
          }
        } else {
          console.error(
            "Failed to regenerate preview URL for post:",
            postId,
            reply
          );
        }
      }
    );
  },
};

export default PreviewUrlRefreshHook;
