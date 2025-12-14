const TrixContentPostHook = {
  mounted() {
    this.eventListeners = [];
    this.isModalOpening = false;
    this.init_links();
    this.setup_photo_viewer();
  },

  updated() {
    this.init_links();
    this.reset_photo_viewer_state();
    this.setup_photo_viewer();
  },

  reset_photo_viewer_state() {
    const postId = this.el.getAttribute("id").split("post-body-")[1];
    if (!postId) return;

    const photoButton = document.querySelector(
      `[id^="post-${postId}-show-photos-"]`
    );
    if (photoButton) {
      photoButton.style.display = "";
    }

    const loadingIndicator = document.querySelector(
      `#post-${postId}-loading-indicator`
    );
    if (loadingIndicator) {
      loadingIndicator.style.display = "none";
    }

    this.el.classList.remove("photos-loading");
    this.isModalOpening = false;
  },

  destroyed() {
    this.eventListeners.forEach(({ event, handler }) => {
      window.removeEventListener(event, handler);
    });
    this.eventListeners = [];
    this.isModalOpening = false;
  },

  setup_photo_viewer() {
    const postId = this.el.getAttribute("id").split("post-body-")[1];

    const hasImages =
      this.el.querySelector(".grid") &&
      this.el.querySelector(".grid").children.length > 0;

    if (hasImages && postId) {
      const eventName = `mosslet:show-post-photos-${postId}`;
      const handler = (event) => {
        if (event && event.detail.post_id === postId) {
          const userId = event.detail.user_id;
          this.load_and_decrypt_images(postId, userId);
        }
      };

      window.addEventListener(eventName, handler);
      this.eventListeners.push({ event: eventName, handler });
    }
  },

  load_and_decrypt_images(postId, userId) {
    this.pushEvent(
      "get_post_image_urls",
      { post_id: postId },
      (reply, _ref) => {
        if (
          reply.response === "success" &&
          reply.image_urls &&
          reply.image_urls.length > 0
        ) {
          this.show_loading_state();
          this.decrypt_images(reply.image_urls, postId, userId);
        } else {
          console.error("Failed to get image URLs for post", postId, reply);
          this.show_error_state();
        }
      }
    );
  },

  show_loading_state() {
    const placeholderGrid = this.el.querySelector(".grid");
    if (placeholderGrid) {
      this.el.classList.add("photos-loading");

      const gridClass =
        this.el.dataset.gridClass || "grid-cols-6 sm:grid-cols-8";
      const imageCount =
        parseInt(this.el.dataset.imageCount) || placeholderGrid.children.length;

      placeholderGrid.className = `grid ${gridClass} gap-1.5`;
      placeholderGrid.innerHTML = "";

      for (let i = 0; i < imageCount; i++) {
        const skeleton = this.createLoadingSkeleton(i, imageCount);
        placeholderGrid.appendChild(skeleton);
      }
    }
  },

  createLoadingSkeleton(index, total) {
    const container = document.createElement("div");
    container.className =
      "relative overflow-hidden rounded-md bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-800";
    container.style.animationDelay = `${index * 50}ms`;
    container.style.opacity = "0";
    container.style.animation = "fadeInUp 0.3s ease-out forwards";
    container.style.animationDelay = `${index * 50}ms`;

    container.innerHTML = `
      <div class="aspect-square flex items-center justify-center relative">
        <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent skeleton-shimmer"></div>
        <div class="relative flex flex-col items-center gap-1">
          <div class="w-6 h-6 rounded-full border-2 border-emerald-500/30 border-t-emerald-500 animate-spin"></div>
        </div>
      </div>
      <div class="absolute bottom-1 right-1 px-1 py-0.5 rounded text-[10px] bg-black/40 text-white font-medium backdrop-blur-sm">
        ${index + 1}/${total}
      </div>
    `;

    return container;
  },

  decrypt_images(imageUrls, postId, userId) {
    this.pushEvent(
      "decrypt_post_images",
      { sources: imageUrls, post_id: postId },
      (reply, _ref) => {
        if (
          reply.response === "success" &&
          reply.decrypted_binaries &&
          reply.decrypted_binaries.length > 0
        ) {
          this.display_decrypted_images(
            reply.decrypted_binaries,
            postId,
            userId,
            reply.can_download || false
          );
        } else {
          this.show_error_state();
        }
      }
    );
  },

  display_decrypted_images(
    decryptedBinaries,
    postId,
    userId,
    canDownload = false
  ) {
    const container = this.el.querySelector(".grid");
    if (container) {
      this.el.classList.remove("photos-loading");

      const imageCount = decryptedBinaries.length;
      let gridClass = "grid-cols-6 sm:grid-cols-8";

      if (imageCount === 1) {
        gridClass = "grid-cols-6";
      } else if (imageCount === 2) {
        gridClass = "grid-cols-6";
      } else if (imageCount <= 4) {
        gridClass = "grid-cols-6";
      } else if (imageCount <= 6) {
        gridClass = "grid-cols-6 sm:grid-cols-8";
      } else {
        gridClass = "grid-cols-6 sm:grid-cols-8 lg:grid-cols-10";
      }

      container.innerHTML = "";
      container.className = `grid ${gridClass} gap-1.5`;

      decryptedBinaries.forEach((imageBinary, index) => {
        const imageContainer = document.createElement("div");
        imageContainer.className =
          "relative group overflow-hidden rounded-md cursor-pointer transform transition-all duration-300 hover:scale-[1.02] hover:shadow-lg hover:shadow-emerald-500/10";
        imageContainer.style.opacity = "0";
        imageContainer.style.animation = "fadeInScale 0.4s ease-out forwards";
        imageContainer.style.animationDelay = `${index * 80}ms`;

        const link = document.createElement("a");
        link.href = imageBinary;
        link.className = "block relative";

        link.addEventListener("click", (e) => {
          e.preventDefault();

          if (this.isModalOpening) return;
          this.isModalOpening = true;

          this.showImageClickLoading(imageContainer);

          try {
            this.pushEvent(
              "show_timeline_images",
              {
                post_id: postId,
                image_index: index,
                images: decryptedBinaries,
              },
              () => {
                this.hideImageClickLoading(imageContainer);
                this.isModalOpening = false;
              }
            );

            setTimeout(() => {
              this.hideImageClickLoading(imageContainer);
              this.isModalOpening = false;
            }, 3000);
          } catch (error) {
            console.warn("Failed to open image modal:", error);
            this.hideImageClickLoading(imageContainer);
            this.isModalOpening = false;
          }
        });

        link.addEventListener("contextmenu", (e) => {
          e.preventDefault();
        });

        const img = document.createElement("img");
        img.src = imageBinary;
        img.alt = `Photo ${index + 1}`;
        img.className =
          "w-full aspect-square object-cover transition-transform duration-500 group-hover:scale-110";
        img.style.opacity = "0";
        img.onload = () => {
          img.style.transition = "opacity 0.3s ease-out";
          img.style.opacity = "1";
        };

        const overlay = document.createElement("div");
        overlay.className =
          "absolute inset-0 bg-gradient-to-t from-black/60 via-black/0 to-black/0 opacity-0 group-hover:opacity-100 transition-all duration-300 pointer-events-none flex items-end justify-center pb-4";

        overlay.innerHTML = `
          <div class="flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/20 backdrop-blur-sm transform translate-y-2 group-hover:translate-y-0 transition-transform duration-300">
            <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7"></path>
            </svg>
            <span class="text-white text-xs font-medium">View</span>
          </div>
        `;

        const loadingOverlay = document.createElement("div");
        loadingOverlay.className =
          "image-click-loading absolute inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center opacity-0 pointer-events-none transition-opacity duration-200 z-10";
        loadingOverlay.innerHTML = `
          <div class="w-8 h-8 rounded-full border-2 border-white/30 border-t-white animate-spin"></div>
        `;

        if (decryptedBinaries.length > 1) {
          const counter = document.createElement("div");
          counter.className =
            "absolute top-2 right-2 px-2 py-0.5 rounded-md bg-black/40 text-white text-xs font-medium backdrop-blur-sm opacity-0 group-hover:opacity-100 transition-opacity duration-300";
          counter.textContent = `${index + 1}/${decryptedBinaries.length}`;
          imageContainer.appendChild(counter);
        }

        link.appendChild(img);
        imageContainer.appendChild(link);
        imageContainer.appendChild(overlay);
        imageContainer.appendChild(loadingOverlay);
        container.appendChild(imageContainer);
      });

      const photoButton = document.querySelector(
        `#post-${postId}-show-photos-${userId}`
      );
      if (photoButton) {
        photoButton.style.display = "none";
      }

      const loadingIndicator = document.querySelector(
        `#post-${postId}-loading-indicator`
      );
      if (loadingIndicator) {
        loadingIndicator.style.display = "none";
      }
    }
  },

  showImageClickLoading(imageContainer) {
    const loadingOverlay = imageContainer.querySelector(".image-click-loading");
    if (loadingOverlay) {
      loadingOverlay.style.opacity = "1";
      loadingOverlay.style.pointerEvents = "auto";
    }
  },

  hideImageClickLoading(imageContainer) {
    const loadingOverlay = imageContainer.querySelector(".image-click-loading");
    if (loadingOverlay) {
      loadingOverlay.style.opacity = "0";
      loadingOverlay.style.pointerEvents = "none";
    }
  },

  show_error_state() {
    const container = this.el.querySelector(".grid");
    if (container) {
      this.el.classList.remove("photos-loading");

      const loadingIndicator = document.querySelector(
        `#${this.el.id.replace("post-body-", "post-")}-loading-indicator`
      );
      if (loadingIndicator) {
        loadingIndicator.style.display = "none";
      }

      container.innerHTML = `
        <div class="col-span-full text-center py-8 animate-fade-in">
          <div class="inline-flex flex-col items-center gap-3 px-6 py-5 rounded-xl bg-red-50/50 dark:bg-red-900/10 border border-red-200/50 dark:border-red-800/30">
            <div class="w-12 h-12 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center">
              <svg class="h-6 w-6 text-red-500 dark:text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
            </div>
            <div class="text-center">
              <p class="text-sm font-medium text-red-700 dark:text-red-300">Unable to load photos</p>
              <p class="text-xs text-red-500/80 dark:text-red-400/60 mt-1">Please try again later</p>
            </div>
          </div>
        </div>
      `;
    }
  },

  init_links() {
    var links = this.el.querySelectorAll("a");
    links.forEach((link) => {
      this.transform_link(link);
    });
  },

  init_images(checkLinks, postId, userId) {
    if (checkLinks && checkLinks.length) {
      this.originalLinks = [];
      this.newLinks = [];
      this.newPresignedUrls = [];
      this.oldPresignedUrls = [];

      const URL_EXPIRES_IN = 590_000;

      var imagePromises = [];
      var updatePromises = [];
      var dbPromises = [];
      var replaceLinkPromises = [];
      var photoButton = null;
      var timestampElement = null;
      var postUpdatedAt = null;
      var imageCounter = 0;

      imageCounter = checkLinks.length;

      let updatePromise = new Promise((resolve, reject) => {
        timestampElement = document.querySelector(
          `#timestamp-${postId}-updated time`
        );
        postUpdatedAt = timestampElement.getAttribute("datetime");

        if (postUpdatedAt && this.isUrlExpired(postUpdatedAt, URL_EXPIRES_IN)) {
          resolve();
        } else {
          reject();
        }
      });
      updatePromises.push(updatePromise);

      Promise.all(updatePromises)
        .then(() => {
          this.el.querySelectorAll("a").forEach((link) => {
            if (link.children.length > 0 && postId) {
              if (link.querySelector("img")) {
                this.originalLinks.push(link);

                let spinner = this.createSpinner();
                link.parentNode.insertBefore(spinner, link);
                this.spinners.push(spinner);
                link.classList.add("hidden");

                if (imageCounter > 0) {
                  this.oldPresignedUrls.push(
                    link.querySelector("img").getAttribute("src")
                  );
                  imageCounter--;
                }
              }
            }
          });

          if (
            imageCounter === 0 &&
            this.oldPresignedUrls.length === checkLinks.length
          ) {
            let imagePromise = new Promise((resolve, reject) => {
              this.pushEvent(
                "generate_signed_urls",
                { src_list: this.oldPresignedUrls },
                (reply, ref) => {
                  if (reply && reply.response === "success") {
                    reply.presigned_url_list.forEach((presigned_url) => {
                      this.newPresignedUrls.push(presigned_url);
                    });

                    if (
                      this.newPresignedUrls.length ===
                      this.oldPresignedUrls.length
                    ) {
                      resolve();
                    } else {
                      reject("New presigned urls list failed to build");
                    }
                  } else {
                    reject(
                      `Error presigning new urls for the image. Please contact support@mosslet.com: ${ref}.`
                    );
                  }
                }
              );
            });
            imagePromises.push(imagePromise);
          }

          Promise.all(imagePromises)
            .then(() => {
              if (
                imageCounter === 0 &&
                this.newPresignedUrls.length === this.oldPresignedUrls.length
              ) {
                let replaceLink = new Promise((resolve, reject) => {
                  var newLink = null;

                  this.originalLinks.forEach((originalLink, index) => {
                    newLink = originalLink;
                    newLink.setAttribute("href", this.newPresignedUrls[index]);
                    newLink
                      .querySelector("img")
                      .setAttribute("src", this.newPresignedUrls[index]);

                    this.newLinks.push(newLink);
                  });
                  resolve();
                });
                replaceLinkPromises.push(replaceLink);

                Promise.all(replaceLinkPromises)
                  .then(() => {
                    var updateLinkCounter = this.originalLinks.length;

                    this.originalLinks.forEach((link, index) => {
                      link.setAttribute("href", this.newLinks[index]);
                      link
                        .querySelector("img")
                        .setAttribute("src", this.newLinks[index]);

                      link.classList.add("cursor-not-allowed");
                      link.classList.remove("hidden");

                      updateLinkCounter--;
                    });

                    if (updateLinkCounter === 0) {
                      this.spinners.forEach((spinner) => {
                        this.removeSpinner(spinner);
                      });
                      this.pushEvent("update_post_body", {
                        body: this.el.innerHTML,
                        id: postId,
                      });
                    } else {
                      this.pushEvent("log_error", {
                        error:
                          "Error updating links (line 186 in trix-content-post-hook.js): updateLinkCounter is not equal to 0.",
                      });
                    }

                    let dbPromise = new Promise((resolve, reject) => {
                      this.handleEvent("update-post-body-complete", (data) => {
                        if (data.response === "success") {
                          resolve();
                        } else if (data.response === "failed") {
                          reject();
                        }
                      });
                    });
                    dbPromises.push(dbPromise);
                  })
                  .catch((error) => {
                    this.pushEvent("log_error", {
                      error:
                        "Error from replaceLinkPromises (line 166 in trix-content-post-hook.js).",
                      data: error,
                    });
                  });

                Promise.all(dbPromises)
                  .then(() => {
                    photoButton = document.querySelector(
                      `#post-${postId}-show-photos-${userId}`
                    );
                    photoButton.style.display = "none";
                  })
                  .catch((error) => {
                    this.pushEvent("log_error", {
                      error:
                        "Error from dbPromises (line 221 in trix-content-post-hook.js).",
                      data: error,
                    });

                    this.el.querySelectorAll("a").forEach((link) => {
                      if (link.children.length > 0 && postId) {
                        if (link.querySelector("img")) {
                          this.originalLinks = [];
                          this.originalLinks.push(link);
                          let spinner = this.createSpinner();

                          link.parentNode.insertBefore(spinner, link);
                          this.spinners.push(spinner);

                          link.remove();
                        }
                      }
                    });
                  });
              }
            })
            .catch((error) => {
              this.pushEvent("log_error", {
                error:
                  "Error from imagePromises (line 143 trix-content-post-hook.js).",
                data: error,
              });
            });
        })
        .catch((_error) => {
          photoButton = document.querySelector(
            `#post-${postId}-show-photos-${userId}`
          );
          photoButton.style.display = "none";

          this.el.querySelectorAll("a").forEach((link) => {
            if (link.children.length > 0 && postId) {
              if (link.querySelector("img")) {
                this.originalLinks.push(link);

                let spinner = this.createSpinner();

                link.parentNode.insertBefore(spinner, link);
                this.spinners.push(spinner);

                link.classList.add("hidden");
              }
            }
          });

          var imageSources = [];
          checkLinks.forEach((link) => {
            imageSources.push(link.getAttribute("src"));
          });

          if (imageSources.length === checkLinks.length) {
            this.pushEvent(
              "decrypt_post_images",
              { sources: imageSources, post_id: postId },
              (reply, _ref) => {
                if (
                  reply.response === "success" &&
                  reply.decrypted_binaries.length
                ) {
                  var updateLinkCounter = this.originalLinks.length;
                  var decryptedBinaries = reply.decrypted_binaries;
                  this.originalLinks.forEach((link, index) => {
                    link.setAttribute("href", decryptedBinaries[index]);

                    link
                      .querySelector("img")
                      .setAttribute("src", decryptedBinaries[index]);

                    link.classList.add("cursor-not-allowed");
                    link.classList.remove("hidden");

                    updateLinkCounter--;
                  });

                  if (updateLinkCounter === 0) {
                    this.spinners.forEach((spinner) => {
                      this.removeSpinner(spinner);
                    });
                  }
                } else {
                  this.pushEvent("log_error", {
                    error:
                      "Error from decrypting images (line 291 trix-content-post-hook.js).",
                    data: reply,
                  });
                }
              }
            );
          }
        });
    }
  },

  image_placeholder() {
    var checkLinks = this.el.querySelectorAll("img");

    if (checkLinks && checkLinks.length) {
      this.originalLinks = [];
      this.newLinks = [];
      this.spinners = [];

      const postId = this.el.getAttribute("id").split("post-body-")[1];

      this.el.querySelectorAll("a").forEach((link) => {
        if (link.children.length > 0 && postId) {
          if (link.querySelector("img")) {
            this.originalLinks.push(link);

            let spinner = this.createPlaceholderImage();

            link.parentNode.insertBefore(spinner, link);
            this.spinners.push(spinner);

            link.classList.add("hidden");
          }
        }
      });
    }
  },

  createPlaceholderImage() {
    const placeholderContainer = document.createElement("div");
    placeholderContainer.classList.add(
      "flex",
      "justify-center",
      "items-center",
      "h-64",
      "text-background-600",
      "dark:text-gray-400"
    );

    const placeholderSvg = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "svg"
    );
    placeholderSvg.setAttribute("fill", "none");
    placeholderSvg.setAttribute("viewBox", "0 0 24 24");
    placeholderSvg.setAttribute("stroke-width", "1.5");
    placeholderSvg.setAttribute("stroke", "currentColor");
    placeholderSvg.classList.add("size-6");

    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("stroke-linecap", "round");
    path.setAttribute("stroke-linejoin", "round");
    path.setAttribute(
      "d",
      "m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 0 0 1.5-1.5V6a1.5 1.5 0 0 0-1.5-1.5H3.75A1.5 1.5 0 0 0 2.25 6v12a1.5 1.5 0 0 0 1.5 1.5Zm10.5-11.25h.008v.008h-.008V8.25Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
    );

    placeholderSvg.appendChild(path);
    placeholderContainer.appendChild(placeholderSvg);

    return placeholderContainer;
  },

  createSpinner() {
    const spinner = document.createElement("div");
    spinner.classList.add("flex", "justify-center", "items-center", "h-64");

    const spinnerInner = document.createElement("div");
    spinnerInner.classList.add(
      "spinner",
      "border-4",
      "border-t-emerald-600",
      "dark:border-t-emerald-500",
      "rounded-full",
      "w-12",
      "h-12",
      "animate-spin"
    );

    spinner.appendChild(spinnerInner);
    return spinner;
  },

  removeSpinner(spinner) {
    if (spinner) {
      spinner.remove();
    }
  },

  transform_link(link) {
    if (link.children.length > 0) {
      link.setAttribute("target", "_blank");
      link.setAttribute("rel", "noopener noreferrer");

      link.addEventListener("click", function (event) {
        event.preventDefault();
      });

      link.addEventListener("contextmenu", function (event) {
        event.preventDefault();
      });
    } else {
      link.setAttribute("target", "_blank");
      link.setAttribute("rel", "noopener noreferrer");
    }
  },

  isUrlExpired(postUpdatedAt, urlExpiresIn) {
    var postUpdatedAtDate = new Date(postUpdatedAt);
    postUpdatedAtDate.setMinutes(
      postUpdatedAtDate.getMinutes() - postUpdatedAtDate.getTimezoneOffset()
    );
    var expirationDate = new Date(
      postUpdatedAtDate.getTime() + urlExpiresIn * 1_000
    );
    var currentDate = new Date();
    return currentDate > expirationDate;
  },
};

export default TrixContentPostHook;
