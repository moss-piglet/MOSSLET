const TrixContentReplyHook = {
  mounted() {
    this.eventListeners = [];
    this.init_links();
    this.image_placeholder();

    var replyId = null;
    var userId = null;
    var checkLinks = this.el.querySelectorAll("img");
    if (checkLinks && checkLinks.length) {
      replyId = this.el.getAttribute("id").split("reply-body-")[1];

      const eventName = `mosslet:show-reply-photos-${replyId}`;
      const handler = (event) => {
        if (event && event.detail.reply_id === replyId) {
          userId = event.detail.user_id;
          this.init_images(checkLinks, replyId, userId);
        }
      };

      window.addEventListener(eventName, handler);
      this.eventListeners.push({ event: eventName, handler });
    }
  },

  updated() {
    this.init_links();
    this.image_placeholder();

    var replyId = null;
    var checkLinks = this.el.querySelectorAll("img");
    if (checkLinks && checkLinks.length) {
      replyId = this.el.getAttribute("id").split("reply-body-")[1];
    }
  },

  destroyed() {
    this.eventListeners.forEach(({ event, handler }) => {
      window.removeEventListener(event, handler);
    });
    this.eventListeners = [];
  },

  init_links() {
    var links = this.el.querySelectorAll("a");

    links.forEach((link) => {
      this.transform_link(link);
    });
  },

  init_images(checkLinks, replyId, userId) {
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
      var replyUpdatedAt = null;
      var imageCounter = 0;

      imageCounter = checkLinks.length;

      let updatePromise = new Promise((resolve, reject) => {
        timestampElement = document.querySelector(
          `#timestamp-${replyId}-updated time`
        );
        replyUpdatedAt = timestampElement.getAttribute("datetime");

        if (
          replyUpdatedAt &&
          this.isUrlExpired(replyUpdatedAt, URL_EXPIRES_IN)
        ) {
          resolve();
        } else {
          reject();
        }
      });
      updatePromises.push(updatePromise);

      Promise.all(updatePromises)
        .then(() => {
          this.el.querySelectorAll("a").forEach((link) => {
            if (link.children.length > 0 && replyId) {
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
                      this.pushEvent("update_reply_body", {
                        body: this.el.innerHTML,
                        id: replyId,
                      });
                    } else {
                      this.pushEvent("log_error", {
                        error:
                          "Error updating links (line 186 in trix-content-reply-hook.js): updateLinkCounter is not equal to 0.",
                      });
                    }

                    let dbPromise = new Promise((resolve, reject) => {
                      this.handleEvent("update-reply-body-complete", (data) => {
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
                        "Error from replaceLinkPromises (line 166 in trix-content-reply-hook.js).",
                      data: error,
                    });
                  });

                Promise.all(dbPromises)
                  .then(() => {
                    photoButton = document.querySelector(
                      `#reply-${replyId}-show-photos-${userId}`
                    );
                    photoButton.style.display = "none";
                  })
                  .catch((error) => {
                    this.pushEvent("log_error", {
                      error:
                        "Error from dbPromises (line 221 in trix-content-reply-hook.js).",
                      data: error,
                    });

                    this.el.querySelectorAll("a").forEach((link) => {
                      if (link.children.length > 0 && replyId) {
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
                  "Error from imagePromises (line 143 trix-content-reply-hook.js).",
                data: error,
              });
            });
        })
        .catch((_error) => {
          photoButton = document.querySelector(
            `#reply-${replyId}-show-photos-${userId}`
          );
          photoButton.style.display = "none";

          this.el.querySelectorAll("a").forEach((link) => {
            if (link.children.length > 0 && replyId) {
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
              "decrypt_reply_images",
              { sources: imageSources, reply_id: replyId },
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
                      "Error from decrypting images (line 291 trix-content-reply-hook.js).",
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

      const replyId = this.el.getAttribute("id").split("reply-body-")[1];

      this.el.querySelectorAll("a").forEach((link) => {
        if (link.children.length > 0 && replyId) {
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

  isUrlExpired(replyUpdatedAt, urlExpiresIn) {
    var replyUpdatedAtDate = new Date(replyUpdatedAt);
    replyUpdatedAtDate.setMinutes(
      replyUpdatedAtDate.getMinutes() - replyUpdatedAtDate.getTimezoneOffset()
    );
    var expirationDate = new Date(
      replyUpdatedAtDate.getTime() + urlExpiresIn * 1_000
    );
    var currentDate = new Date();
    return currentDate > expirationDate;
  },
};

export default TrixContentReplyHook;
