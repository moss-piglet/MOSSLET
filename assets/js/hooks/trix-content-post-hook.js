const TrixContentPostHook = {
  mounted() {
    this.init_links();
    this.init_images();
  },

  updated() {
    this.init_links();
    this.init_images();
  },

  init_links() {
    // Get all <a> tags
    var links = this.el.querySelectorAll("a");

    links.forEach((link) => {
      this.transform_link(link);
    });
  },

  init_images() {
    var checkLinks = this.el.querySelectorAll("img");

    // Check to first see if there are any images present in the post
    if (checkLinks && checkLinks.length) {
      this.originalLinks = [];
      this.newLinks = [];
      this.spinners = [];
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
      var postId = null;
      var timestampElement = null;
      var postUpdatedAt = null;
      var imageCounter = 0;

      // Set an initial count of all images
      imageCounter = checkLinks.length;

      // Get the post's id (leave this independent of our postBody variable)
      postId = this.el.getAttribute("id").split("post-body-")[1];

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
                  .then(() => {})
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
