import Alpine from "../../vendor/alpinejs";

import data from "../../vendor/@emoji-mart/data";
import { Picker } from "../../vendor/emoji-mart";

const TrixEditor = {
  mounted() {
    // Set initial emoji-picker instance
    this.pickerInstance = null;
    this.initializeTrixEditor();
  },

  initializeTrixEditor() {
    var element = document.querySelector("trix-editor");

    // Add support for hidden Trix editors (in modals)
    var hiddenTrixEditor =
      document.getElementById("ignore-trix-editor_edit") ||
      document.getElementById("ignore-trix-editor_new") ||
      document.getElementById("ignore-trix-editor_reply") ||
      document.getElementById("ignore-trix-editor_reply_edit");

    if (hiddenTrixEditor) {
      var element = hiddenTrixEditor.querySelector("trix-editor");
    }

    element.addEventListener("trix-action-invoke", function (event) {
      const { target, invokingElement, actionName } = event;

      if (actionName === "x-emoji") {
        // Add relative class to the parent of the trix-editor element for emoji-picker positioning
        element.parentElement.classList.add("relative");
        pickerElement = element.parentElement.querySelector(
          `[data-emoji=${element.toolbarElement.id}]`
        );

        if (!this.pickerInstance) {
          // Ensure Alpine is fully loaded before manipulating
          Alpine.nextTick(() => {
            this.pickerInstance = new Picker({
              data: data,
              parent: pickerElement,
              theme: localStorage.scheme,
              emojiButtonColors: ["oklch(69.6% 0.17 162.48)"],
              onEmojiSelect: (emoji) => {
                // We insert the emoji at the current cursor position
                var currentPosition = element.editor.getSelectedRange()[0];
                element.editor.setSelectedRange([
                  currentPosition,
                  currentPosition,
                ]);
                element.editor.insertString(emoji.native);

                // Dispatch a custom event to close the dropdown
                const closeDropdownEvent = new CustomEvent(
                  "close-emoji-dropdown",
                  {
                    bubbles: true,
                    detail: { toolbarId: element.toolbarElement.id },
                  }
                );
                element.dispatchEvent(closeDropdownEvent);
              },
            });
          });
        }
      }
    });

    // Add a global event listener to handle closing the dropdown
    document.addEventListener("close-emoji-dropdown", (event) => {
      const dropdown = document.querySelector(
        `[data-emoji="${event.detail.toolbarId}"]`
      );
      if (dropdown) {
        const alpineComponent = dropdown.closest("[x-data]");
        if (alpineComponent) {
          Alpine.store("dropdownOpen", false);
        }
      }
    });

    // create a variable to handle the "this" for liveview
    var liveObject = this;

    // List to track if uploads are in progress
    var uploadPromises = [];
    var removePromises = [];

    // List to track the keys for uploaded files for remove event
    var uploadedKeys = [];

    // Counter to track the number of active uploads
    var activeUploads = 0;

    // Store the file blob data in the attachment object for undo/redo
    var attachmentFileData = [];

    // Store the upload file status for tracking error messages
    var status = null;

    element.editor.element.addEventListener("trix-change", (e) => {
      this.el.dispatchEvent(new Event("input", { bubbles: true }));
    });

    // Handles behavior when inserting a file
    element.editor.element.addEventListener(
      "trix-attachment-add",
      function (event) {
        if (event.attachment && event.attachment.file) {
          var fileSizeInBytes = event.attachment.file.size; // Get the file size in bytes
          var fileSizeInMB = (fileSizeInBytes / (1024 * 1024)).toFixed(2); // Convert to MB
          var fileName = event.attachment.file.name; // Get the file name to use for any error msg
          if (fileSizeInMB < 8) {
            // We set the previewURL to the temp blob file
            // so we can preview image while still in the editor
            // because the image will be encrypted when uploaded
            const blob = event.attachment.file;
            const fileReader = new FileReader();
            fileReader.onload = () => {
              event.attachment.attachment.previewURL = fileReader.result;
              event.attachment.attachment.fileObjectURL = fileReader.result;
            };
            fileReader.readAsDataURL(blob);

            activeUploads++;
            liveObject.pushEvent("uploads_in_progress", {
              flag: true,
            });

            const uploadPromise = uploadFileAttachment(
              event.attachment,
              liveObject
            );
            uploadPromises.push(uploadPromise);

            // Check if all uploads have finished and send the "uploads_in_progress" event after a brief delay
            Promise.all(uploadPromises)
              .then(() => {
                activeUploads--;
                if (activeUploads === 0) {
                  liveObject.pushEvent("uploads_in_progress", {
                    flag: false,
                  });
                }
              })
              .catch((error) => {
                if (error === "Failed to add image URL" || error === "error") {
                  activeUploads--;
                  if (activeUploads === 0) {
                    liveObject.pushEvent("error_uploading", {
                      flag: false,
                      message: `Uh oh, there was an error uploading your file named ${fileName}. Please try again.`,
                    });
                  } else {
                    liveObject.pushEvent("error_uploading", {
                      flag: true,
                      message: `Uh oh, there was an error uploading your file named ${fileName}. Please try again.`,
                    });
                  }
                } else if (error === "nsfw") {
                  // We need to reset the status for future uploads
                  status = null;
                  activeUploads--;
                  if (activeUploads === 0) {
                    liveObject.pushEvent("nsfw", {
                      flag: false,
                      message: `Your file named ${fileName} is NSFW. This check was done privately. Please choose a different file as this one will not be uploaded.`,
                    });
                  } else {
                    liveObject.pushEvent("nsfw", {
                      flag: true,
                      message: `Your file named ${fileName} is NSFW. This check was done privately. Please choose a different file as this one will not be uploaded.`,
                    });
                  }
                }
              });
          } else {
            activeUploads--;
            if (activeUploads === 0) {
              // Let the server know the file is too large
              liveObject.pushEvent("file_too_large", {
                flag: false,
                message: `Your file named ${fileName} is too big. Files must be less than 8 MB. Please choose a smaller file.`,
              });
            } else {
              liveObject.pushEvent("file_too_large", {
                flag: true,
                message: `Your file named ${fileName} is too big. Files must be less than 8 MB. Please choose a smaller file.`,
              });
            }
          }
        } else if (event.attachment && event.attachment.file === null) {
          var correspondingAttachment = attachmentFileData.find(
            (attachment) => attachment.id === event.attachment.id
          );

          var fileSizeInBytes = attachment.file.size; // Get the file size in bytes
          var fileSizeInMB = (fileSizeInBytes / (1024 * 1024)).toFixed(2); // Convert to MB
          var fileName = attachment.file.name; // Get the file name to use for any error msg
          if (fileSizeInMB < 8) {
            if (correspondingAttachment) {
              event.attachment = correspondingAttachment;
              activeUploads++;

              liveObject.pushEvent("uploads_in_progress", {
                flag: true,
              });

              const uploadPromise = uploadFileAttachment(
                event.attachment,
                liveObject
              );
              uploadPromises.push(uploadPromise);

              // Check if all uploads have finished and send the "uploads_in_progress" event after a brief delay
              Promise.all(uploadPromises)
                .then(() => {
                  activeUploads--;
                  if (activeUploads === 0) {
                    liveObject.pushEvent("uploads_in_progress", {
                      flag: false,
                    });
                  }
                })
                .catch((error) => {
                  if (
                    error === "Failed to add image URL" ||
                    error === "error"
                  ) {
                    activeUploads--;
                    if (activeUploads === 0) {
                      liveObject.pushEvent("error_uploading", {
                        flag: false,
                        message: `Uh oh, there was an error uploading your file named ${fileName}. Please try again.`,
                      });
                    } else {
                      liveObject.pushEvent("error_uploading", {
                        flag: true,
                        message: `Uh oh, there was an error uploading your file named ${fileName}. Please try again.`,
                      });
                    }
                  } else if (error === "nsfw") {
                    // We need to reset the status for future uploads
                    status = null;
                    activeUploads--;

                    if (activeUploads === 0) {
                      liveObject.pushEvent("nsfw", {
                        flag: false,
                        message: `Your file named ${fileName} is NSFW. This check was done privately. Please choose a different file as this one will not be uploaded.`,
                      });
                    } else {
                      liveObject.pushEvent("nsfw", {
                        flag: true,
                        message: `Your file named ${fileName} is NSFW. This check was done privately. Please choose a different file as this one will not be uploaded.`,
                      });
                    }
                  }
                });
            } else {
              activeUploads--;
              if (activeUploads === 0) {
                liveObject.pushEvent("error_uploading", {
                  flag: false,
                  message:
                    "File could not be uploaded from undo/redo. Please remove and re-add the file using the paper clip button or by dragging-and-dropping into the text editor.",
                });
              } else {
                liveObject.pushEvent("error_uploading", {
                  flag: true,
                  message:
                    "File could not be uploaded from undo/redo. Please remove and re-add the file using the paper clip button or by dragging-and-dropping into the text editor.",
                });
              }
            }
          } else {
            activeUploads--;
            if (activeUploads === 0) {
              // Let the server know the file is too large
              liveObject.pushEvent("file_too_large", {
                flag: false,
                message: `Your file named ${fileName} is too big. Files must be less than 8 MB. Please choose a smaller file.`,
              });
            } else {
              liveObject.pushEvent("file_too_large", {
                flag: true,
                message: `Your file named ${fileName} is too big. Files must be less than 8 MB. Please choose a smaller file.`,
              });
            }
          }
        }
      }
    );

    // Handle behavior when deleting a file
    element.editor.element.addEventListener(
      "trix-attachment-remove",
      function (event) {
        // add the files being removed to the attachmentFileData array
        // this will be used to restore on undo/redo
        const existingAttachment = attachmentFileData.find(
          (attachment) => attachment.id === event.attachment.id
        );

        if (!existingAttachment) {
          attachmentFileData.push(event.attachment);
        }

        activeUploads++;

        liveObject.pushEvent("uploads_in_progress", {
          flag: true,
        });

        var removeUrlItem = null;

        removeUrlItem = uploadedKeys.find(
          (item) => item.id === event.attachment.id
        );

        if (removeUrlItem) {
          const removePromise = removeFileAttachment(
            removeUrlItem.urlKey,
            event.attachment.attachment.attributes.values.contentType
          );
          removePromises.push(removePromise);

          // Check if all uploads have finished and send the "uploads_in_progress" event
          Promise.all(removePromises)
            .then(() => {
              activeUploads--;
              if (activeUploads === 0) {
                liveObject.pushEvent("remove_files", {
                  flag: false,
                });
                liveObject.el.dispatchEvent(
                  new Event("input", { bubbles: true })
                ); // Trigger the "input" event
              }
            })
            .catch((url) => {
              activeUploads--;
              if (activeUploads === 0) {
                liveObject.pushEvent("error_removing", {
                  flag: false,
                  message:
                    "There was an error removing the file. We've been notified and will ensure it is removed from the cloud.",
                  url: url,
                });
              } else {
                liveObject.pushEvent("error_removing", {
                  flag: true,
                  message:
                    "There was an error removing the file. We've been notified and will ensure it is removed from the cloud.",
                  url: url,
                });
              }
            });
        } else {
          activeUploads--;
          if (activeUploads === 0) {
            // Nothing was uploaded due to file size or other error
            liveObject.pushEvent("remove_files", {
              flag: false,
            });
          } else {
            // Nothing was uploaded due to file size or other error
            liveObject.pushEvent("remove_files", {
              flag: true,
            });
          }
        }
      }
    );

    // Handle the request to upload a file attachment
    function uploadFileAttachment(attachment, liveObject) {
      return new Promise((resolve, reject) => {
        uploadFile(attachment, liveObject, setProgress, setAttributes);

        function setProgress(progress) {
          attachment.setUploadProgress(progress);
        }

        function setAttributes(attributes, status) {
          if (status === "error") {
            reject(status);
          } else if (status === "nsfw") {
            reject(status);
          } else {
            // Set the attributes for the attachment
            attachment.setAttributes(attributes);
            resolve(attachment);
          }
        }
      });
    }

    // Function to upload a file using XMLHttpRequest to POST to our trix-uploads controller route
    function uploadFile(
      attachment,
      liveObject,
      progressCallback,
      successCallback
    ) {
      liveObject.pushEvent("trix_key", { data: "trix_key" }, (reply, ref) => {
        if (reply.response === "success" && reply.trix_key) {
          var existingKeyItem = uploadedKeys.find(
            (item) => item.id === attachment.id
          );
          if (existingKeyItem) {
            var key = existingKeyItem.urlKey;
          } else {
            var key = createStorageKey();
          }

          // We'll store this upon successful upload to enable
          // redo/undo removing files from cloud
          var urlKey = getUrlKey(key);
          var formData = createFormData(attachment.file, key, reply.trix_key);
          const csrfToken = document
            .querySelector("meta[name='csrf-token']")
            .getAttribute("content");
          var xhr = new XMLHttpRequest();

          // Send a POST request to the route previously defined in `router.ex`
          xhr.open("POST", "/app/trix-uploads", true);
          xhr.setRequestHeader("X-CSRF-Token", csrfToken);

          xhr.upload.addEventListener("progress", function (event) {
            if (event.lengthComputable) {
              const progress = Math.round((event.loaded / event.total) * 100);
              progressCallback(progress);
            }
          });

          // Send the request to the server
          xhr.send(formData);

          // listen for the load event after the xhr.send request completes
          xhr.addEventListener("load", function (_event) {
            if (xhr.status >= 200 && xhr.status < 300) {
              // Retrieve the full path of the uploaded file from the server
              var url = xhr.responseText;

              // We keep the temp attributes with the unecrypted local image
              // to not break the image in the preview of the trix_editor.
              // This will be replaced once the image is posted.
              // Set the attributes for the attachment
              var attributes = {
                url: url,
                href: url,
              };

              liveObject.pushEvent(
                "add_image_urls",
                {
                  preview_url: key,
                  content_type: attachment.file.type,
                },
                (reply, ref) => {
                  if (reply && reply.response === "success") {
                    // Store the key and attachment id
                    // This way we can successfully remove the files
                    // from the cloud on undo/redo events.
                    var id = attachment.id;
                    var existingUrlItem = uploadedKeys.find(
                      (item) => item.id === attachment.id
                    );

                    if (existingUrlItem) {
                      uploadedKeys;
                    } else {
                      uploadedKeys.push({ id, urlKey });
                    }
                    status = "complete";
                    successCallback(attributes, status);
                  } else {
                    status = "error";
                    successCallback(attributes, status);
                  }
                }
              );
            } else if (xhr.status === 418) {
              //status = "nsfw";
              // 418 I'm a teapot (failed nsfw check)
              liveObject.pushEvent("nsfw", {
                flag: false,
                message: `Your file named ${attachment.file.name} is NSFW. This check was done privately. Please choose a different file as this one will not be uploaded.`,
              });
              successCallback(attributes, status);
            }
          });
        }
      });
    }

    // Handle the request to remove a file attachment
    function removeFileAttachment(url, contentType) {
      return new Promise((resolve, reject) => {
        var xhr = new XMLHttpRequest();
        var formData = new FormData();
        formData.append("key", url);
        formData.append("content_type", contentType); // Add content type to FormData
        const csrfToken = document
          .querySelector("meta[name='csrf-token']")
          .getAttribute("content");

        xhr.open("DELETE", "/app/trix-uploads", true);
        xhr.setRequestHeader("X-CSRF-Token", csrfToken);

        xhr.send(formData);

        liveObject.pushEvent(
          "remove_image_urls",
          {
            preview_url: url,
            content_type: contentType,
          },
          (reply, ref) => {
            if (reply && reply.response === "success") {
              resolve();
            } else {
              reject(url);
            }
          }
        );
      });
    }

    // Create a storage key for the attachment
    function createStorageKey() {
      var date = new Date();
      var day = date.toISOString().slice(0, 10);
      // Use a uuid instead of the file_name to ensure no strange characters getting re-encoded
      // and resulting in not being able to find the file
      var fileName = crypto.randomUUID();
      var name = date.getTime() + "-" + fileName;
      return ["tmp", day, name].join("/");
    }

    // Gets the urlKey for storing so we can
    // remove the item on the remove event
    function getUrlKey(key) {
      var urlKey = key.split("/").pop();
      return urlKey;
    }

    // Helper function to create FormData for file uploads
    function createFormData(file, storageKey, trixKey) {
      var data = new FormData();
      data.append("Content-Type", file.type);
      data.append("storage_key", storageKey); // Add key from createStorageKey
      data.append("file", file);
      data.append("trix_key", trixKey);
      return data;
    }
  },
};

export default TrixEditor;
