const TrixContentPostHook = {
  mounted() {
    this.init_links();
    this.setup_photo_viewer();
  },

  updated() {
    this.init_links();
    this.setup_photo_viewer();
  },

  setup_photo_viewer() {
    var postId = null;
    // Get the post's id from the element ID
    postId = this.el.getAttribute("id").split("post-body-")[1];

    // Check if this post has image placeholders that need decryption
    const hasImages =
      this.el.querySelector(".grid") &&
      this.el.querySelector(".grid").children.length > 0;

    if (hasImages && postId) {
      // Set up event listener for the "View photos" button
      window.addEventListener(`mosslet:show-post-photos-${postId}`, (event) => {
        if (event && event.detail.post_id === postId) {
          const userId = event.detail.user_id;
          this.load_and_decrypt_images(postId, userId);
        }
      });
    } else {
    }
  },

  load_and_decrypt_images(postId, userId) {
    // First, request the encrypted image URLs from the server
    this.pushEvent(
      "get_post_image_urls",
      { post_id: postId },
      (reply, _ref) => {
        if (
          reply.response === "success" &&
          reply.image_urls &&
          reply.image_urls.length > 0
        ) {
          // Replace placeholders with spinners
          this.show_loading_state();

          // Now decrypt the images through the server-side decrypt process

          this.decrypt_images(reply.image_urls, postId, userId);
        } else {
          console.error("Failed to get image URLs for post", postId, reply);
          this.show_error_state();
        }
      }
    );
  },

  show_loading_state() {
    // Replace placeholder grid with loading spinners
    const placeholderGrid = this.el.querySelector(".grid");
    if (placeholderGrid) {
      const imageCount = placeholderGrid.children.length;
      placeholderGrid.innerHTML = "";

      for (let i = 0; i < imageCount; i++) {
        const spinner = this.createSpinner();
        placeholderGrid.appendChild(spinner);
      }
    }
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
            reply.can_download || false // Pass download permission from server
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
      container.innerHTML = "";
      container.classList.remove(
        "grid-cols-1",
        "sm:grid-cols-2",
        "lg:grid-cols-3"
      );
      container.classList.add(
        "grid-cols-1",
        "sm:grid-cols-2",
        "lg:grid-cols-3"
      );

      decryptedBinaries.forEach((imageBinary, index) => {
        const imageContainer = document.createElement("div");
        imageContainer.classList.add(
          "relative",
          "group",
          "overflow-hidden",
          "rounded-lg",
          "cursor-pointer" // Always allow viewing
        );

        const link = document.createElement("a");
        link.href = imageBinary;
        link.classList.add("cursor-pointer"); // Always allow viewing

        // Add click handler to open modal
        link.addEventListener("click", (e) => {
          e.preventDefault();
          // Always allow modal viewing, regardless of download permission
          try {
            this.pushEvent("show_timeline_images", {
              post_id: postId,
              image_index: index,
              images: decryptedBinaries,
            });
          } catch (error) {
            console.warn(
              "Failed to open image modal - LiveView not connected:",
              error
            );
          }
        });

        // Enhanced right-click protection based on download permission
        link.addEventListener("contextmenu", (e) => {
          e.preventDefault();
        });

        const img = document.createElement("img");
        img.src = imageBinary;
        img.alt = `Photo ${index + 1}`;
        img.classList.add(
          "w-full",
          "aspect-square",
          "object-cover",
          "transition-all",
          "duration-200",
          "group-hover:scale-105"
        );

        // Add hover overlay for better UX with proper pointer events
        const overlay = document.createElement("div");
        overlay.classList.add(
          "absolute",
          "inset-0",
          "bg-black/0",
          "group-hover:bg-black/20",
          "transition-all",
          "duration-200",
          "flex",
          "items-center",
          "justify-center",
          "pointer-events-none" // Critical: prevent overlay from intercepting clicks
        );

        const expandIcon = document.createElement("div");
        expandIcon.classList.add("pointer-events-none"); // Also disable pointer events on icon
        expandIcon.innerHTML = `
          <svg class="w-8 h-8 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7"></path>
          </svg>
        `;

        overlay.appendChild(expandIcon);

        link.appendChild(img);
        imageContainer.appendChild(link);
        imageContainer.appendChild(overlay);
        container.appendChild(imageContainer);
      });

      // Hide the "View photos" button after successful load
      const photoButton = document.querySelector(
        `#post-${postId}-show-photos-${userId}`
      );
      if (photoButton) {
        photoButton.style.display = "none";
      }
    }
  },

  show_error_state() {
    const container = this.el.querySelector(".grid");
    if (container) {
      container.innerHTML = `
        <div class="col-span-full text-center py-8">
          <div class="text-red-500 dark:text-red-400">
            <svg class="h-8 w-8 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
            </svg>
            <p class="text-sm">Unable to load photos</p>
          </div>
        </div>
      `;
    }
  },

  init_links() {
    // Get all <a> tags
    var links = this.el.querySelectorAll("a");

    links.forEach((link) => {
      this.transform_link(link);
    });
  },

  init_images(checkLinks, postId, userId) {
    // Check to first see if there are any images present in the post
    if (checkLinks && checkLinks.length) {
      this.originalLinks = [];
      this.newLinks = [];
      this.newPresignedUrls = [];
      this.oldPresignedUrls = [];

      // the time in milliseconds that the presigned_urls expire
      // we set this slightly before the urls actual expiration
      // this is in milliseconds (whereas tigris expires in is seconds)
      const URL_EXPIRES_IN = 590_000;

      var imagePromises = [];
      var updatePromises = [];
      var dbPromises = [];
      var replaceLinkPromises = [];
      var photoButton = null;
      var timestampElement = null;
      var postUpdatedAt = null;
      var imageCounter = 0;

      // Set an initial count of all images
      imageCounter = checkLinks.length;

      // First update promise is to check if the urls are expired
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
          // Loop through the links and check if the innerHTML is NOT empty
          // we use image_links and not the checkLinks because we want to
          // update the <a> that wraps the <img> as well as the <img>
          this.el.querySelectorAll("a").forEach((link) => {
            // This link has an innerHTML which will contain the image
            if (link.children.length > 0 && postId) {
              if (link.querySelector("img")) {
                // Store the original link in the list
                this.originalLinks.push(link);

                // Create a spinner for the link
                let spinner = this.createSpinner();

                // Insert the spinner before the link
                link.parentNode.insertBefore(spinner, link);
                this.spinners.push(spinner);

                // Remove the old link element from the document
                link.classList.add("hidden");

                // Start the presigned_url regeneration
                // we should send count of items and send back a full list of the urls.
                // so we don't make mulitple trips to the server
                if (imageCounter > 0) {
                  // add the old presigned url to a list
                  this.oldPresignedUrls.push(
                    link.querySelector("img").getAttribute("src")
                  );

                  // Decrement the imageCounter
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
                    // Update the link and image elements with the new URLs
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
                // Update the postBody with the new URLs
                let replaceLink = new Promise((resolve, reject) => {
                  var newLink = null;

                  this.originalLinks.forEach((originalLink, index) => {
                    newLink = originalLink;
                    newLink.setAttribute("href", this.newPresignedUrls[index]);
                    newLink
                      .querySelector("img")
                      .setAttribute("src", this.newPresignedUrls[index]);

                    // Add the newLink to a list
                    this.newLinks.push(newLink);
                  });
                  resolve();
                });
                replaceLinkPromises.push(replaceLink);

                Promise.all(replaceLinkPromises)
                  .then(() => {
                    // Set the update counter to the length of originalLinks
                    var updateLinkCounter = this.originalLinks.length;

                    this.originalLinks.forEach((link, index) => {
                      // This link has an innerHTML which will contain the image

                      // Set the proper attributes based on the index
                      link.setAttribute("href", this.newLinks[index]);
                      link
                        .querySelector("img")
                        .setAttribute("src", this.newLinks[index]);

                      // Remove the old link element from the document
                      // We currently don't allow image downloads from Posts
                      link.classList.add("cursor-not-allowed");
                      link.classList.remove("hidden");

                      updateLinkCounter--;
                    });

                    if (updateLinkCounter === 0) {
                      this.spinners.forEach((spinner) => {
                        this.removeSpinner(spinner);
                      });
                      // Send the updated body to update the post on the server
                      // this.el is the post's body content
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
                    // hide show photos button
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

                    // Post not updated correctly, reinsert the spinners
                    this.el.querySelectorAll("a").forEach((link) => {
                      // This link has an innerHTML which will contain the image
                      if (link.children.length > 0 && postId) {
                        if (link.querySelector("img")) {
                          // reset the original links list
                          // and store the original link back in the list
                          this.originalLinks = [];
                          this.originalLinks.push(link);
                          let spinner = this.createSpinner();

                          // Insert the spinner before the link
                          link.parentNode.insertBefore(spinner, link);
                          this.spinners.push(spinner);

                          // Remove the old link element from the document
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
          // images don't need updating, just decrypt

          // hide show photos button
          photoButton = document.querySelector(
            `#post-${postId}-show-photos-${userId}`
          );
          photoButton.style.display = "none";

          // replace images with spinners while decrypting
          this.el.querySelectorAll("a").forEach((link) => {
            // This link has an innerHTML which will contain the image
            if (link.children.length > 0 && postId) {
              if (link.querySelector("img")) {
                // Store the original link in the list
                this.originalLinks.push(link);

                // Create a spinner for the link
                let spinner = this.createSpinner();

                // Insert the spinner before the link
                link.parentNode.insertBefore(spinner, link);
                this.spinners.push(spinner);

                // Remove the old link element from the document
                link.classList.add("hidden");
              }
            }
          });

          // build a list of src's (the checkLinks are the image elements)
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
                    // This link has an innerHTML which will contain the image

                    // Set the proper attributes based on the index
                    link.setAttribute("href", decryptedBinaries[index]);

                    link
                      .querySelector("img")
                      .setAttribute("src", decryptedBinaries[index]);

                    // Remove the old link element from the document
                    // We currently don't allow image downloads from Posts
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

      // Get the post's id (leave this independent of our postBody variable)
      postId = this.el.getAttribute("id").split("post-body-")[1];

      // replace images with spinners while decrypting
      this.el.querySelectorAll("a").forEach((link) => {
        // This link has an innerHTML which will contain the image
        if (link.children.length > 0 && postId) {
          if (link.querySelector("img")) {
            // Store the original link in the list
            this.originalLinks.push(link);

            // Create a spinner for the link
            let spinner = this.createPlaceholderImage();

            // Insert the spinner before the link
            link.parentNode.insertBefore(spinner, link);
            this.spinners.push(spinner);

            // Remove the old link element from the document
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
    // link will have inner html (presumably an image)
    if (link.children.length > 0) {
      link.setAttribute("target", "_blank");
      link.setAttribute("rel", "noopener noreferrer");

      // Prevent image downloads currently
      link.addEventListener("click", function (event) {
        event.preventDefault();
      });

      // Prevent image downloads currently
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
    // Adjust the timezone offset
    postUpdatedAtDate.setMinutes(
      postUpdatedAtDate.getMinutes() - postUpdatedAtDate.getTimezoneOffset()
    );
    var expirationDate = new Date(
      postUpdatedAtDate.getTime() + urlExpiresIn * 1_000 // convert to seconds
    );
    var currentDate = new Date();
    return currentDate > expirationDate;
  },
};

// Possible way to prevent default link behavior
// on users that are not allowed to download a memory
//
// link.addEventListener("click", function(event) {
//  event.preventDefault();
//  console.log("ImageHook link clicked");
// });

export default TrixContentPostHook;
