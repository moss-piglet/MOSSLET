const PublicPostImagesHook = {
  mounted() {
    this.isLoading = false;
    this.loadImages();
  },

  updated() {
    if (!this.isLoading && this.el.dataset.loaded !== "true") {
      this.loadImages();
    }
  },

  loadImages() {
    const rawPostId = this.el.dataset.postId;
    const postId = rawPostId.replace("public-post-", "");
    const imageCount = parseInt(this.el.dataset.imageCount) || 0;

    if (!postId || imageCount === 0 || this.el.dataset.loaded === "true") {
      return;
    }

    this.isLoading = true;
    this.showLoadingState(imageCount);

    this.pushEvent(
      "get_post_image_urls",
      { post_id: postId },
      (reply, _ref) => {
        if (
          reply.response === "success" &&
          reply.image_urls &&
          reply.image_urls.length > 0
        ) {
          this.decryptImages(reply.image_urls, postId);
        } else {
          this.showErrorState();
          this.isLoading = false;
        }
      }
    );
  },

  decryptImages(imageUrls, postId) {
    this.pushEvent(
      "decrypt_post_images",
      { sources: imageUrls, post_id: postId },
      (reply, _ref) => {
        if (
          reply.response === "success" &&
          reply.decrypted_binaries &&
          reply.decrypted_binaries.length > 0
        ) {
          this.displayImages(reply.decrypted_binaries, postId);
          this.el.dataset.loaded = "true";
        } else {
          this.showErrorState();
        }
        this.isLoading = false;
      }
    );
  },

  showLoadingState(imageCount) {
    const container = this.el;
    container.innerHTML = "";

    const gridClass = this.getGridClass(imageCount);
    container.className = `relative rounded-xl overflow-hidden border border-slate-200/60 dark:border-slate-700/60 mt-3 ${gridClass} gap-1`;

    for (let i = 0; i < imageCount; i++) {
      const skeleton = this.createLoadingSkeleton(i, imageCount);
      container.appendChild(skeleton);
    }
  },

  getGridClass(count) {
    if (count === 1) return "";
    if (count === 2) return "grid grid-cols-4";
    if (count === 3) return "grid grid-cols-4 h-32 sm:h-40";
    return "grid grid-cols-4";
  },

  createLoadingSkeleton(index, total) {
    const container = document.createElement("div");
    let extraClass = "";

    if (total === 3 && index === 0) {
      extraClass = "col-span-2 row-span-2";
    }

    container.className = `relative overflow-hidden bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-800 ${extraClass}`;

    if (total === 1) {
      container.innerHTML = `
        <div class="w-full h-24 sm:h-32 flex items-center justify-center">
          <div class="w-6 h-6 rounded-full border-2 border-orange-500/30 border-t-orange-500 animate-spin"></div>
        </div>
      `;
    } else {
      container.innerHTML = `
        <div class="aspect-square flex items-center justify-center">
          <div class="w-5 h-5 rounded-full border-2 border-orange-500/30 border-t-orange-500 animate-spin"></div>
        </div>
      `;
    }

    return container;
  },

  displayImages(decryptedBinaries, postId) {
    const container = this.el;
    const imageCount = decryptedBinaries.length;

    container.innerHTML = "";
    container.className =
      "relative rounded-xl overflow-hidden border border-slate-200/60 dark:border-slate-700/60 mt-3";

    if (imageCount === 1) {
      container.appendChild(
        this.createSingleImage(decryptedBinaries[0], decryptedBinaries, 0)
      );
    } else if (imageCount === 2) {
      const grid = document.createElement("div");
      grid.className = "grid grid-cols-4 gap-1";
      decryptedBinaries.forEach((src, idx) => {
        grid.appendChild(this.createGridImage(src, decryptedBinaries, idx));
      });
      container.appendChild(grid);
    } else if (imageCount === 3) {
      const grid = document.createElement("div");
      grid.className = "grid grid-cols-4 gap-1 h-32 sm:h-40";

      grid.appendChild(
        this.createGridImage(
          decryptedBinaries[0],
          decryptedBinaries,
          0,
          "col-span-2 row-span-2"
        )
      );

      const rightColumn = document.createElement("div");
      rightColumn.className = "col-span-2 grid grid-rows-2 gap-1";
      rightColumn.appendChild(
        this.createGridImage(decryptedBinaries[1], decryptedBinaries, 1)
      );
      rightColumn.appendChild(
        this.createGridImage(decryptedBinaries[2], decryptedBinaries, 2)
      );
      grid.appendChild(rightColumn);

      container.appendChild(grid);
    } else {
      const grid = document.createElement("div");
      grid.className = "grid grid-cols-4 gap-1";

      decryptedBinaries.slice(0, 3).forEach((src, idx) => {
        grid.appendChild(this.createGridImage(src, decryptedBinaries, idx));
      });

      if (imageCount > 3) {
        const moreContainer = document.createElement("div");
        moreContainer.className = "relative cursor-pointer group/img";

        const img = document.createElement("img");
        img.src = decryptedBinaries[3];
        img.alt = "Post image";
        img.className =
          "aspect-square object-cover w-full h-full transition-transform duration-300 ease-out group-hover/img:scale-105";

        const overlay = document.createElement("div");
        overlay.className =
          "absolute inset-0 bg-black/50 flex items-center justify-center";
        overlay.innerHTML = `<span class="text-white text-lg font-semibold">+${imageCount - 3}</span>`;

        moreContainer.appendChild(img);
        moreContainer.appendChild(overlay);

        moreContainer.addEventListener("click", () => {
          this.openLightbox(decryptedBinaries, 3);
        });

        grid.appendChild(moreContainer);
      }

      container.appendChild(grid);
    }
  },

  createSingleImage(src, allImages, index) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "w-full cursor-pointer group/img";

    const img = document.createElement("img");
    img.src = src;
    img.alt = "Post image";
    img.className =
      "w-full max-h-48 sm:max-h-56 object-cover transition-transform duration-300 ease-out group-hover/img:scale-105";
    img.loading = "lazy";

    const overlay = document.createElement("div");
    overlay.className =
      "absolute inset-0 bg-black/0 group-hover/img:bg-black/10 transition-colors duration-300";

    button.appendChild(img);
    button.appendChild(overlay);

    button.addEventListener("click", () => {
      this.openLightbox(allImages, index);
    });

    return button;
  },

  createGridImage(src, allImages, index, extraClass = "") {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `relative cursor-pointer group/img ${extraClass}`;

    const img = document.createElement("img");
    img.src = src;
    img.alt = "Post image";
    img.className = `${extraClass.includes("row-span") ? "w-full h-full" : "aspect-square"} object-cover transition-transform duration-300 ease-out group-hover/img:scale-105`;
    img.loading = "lazy";

    const overlay = document.createElement("div");
    overlay.className =
      "absolute inset-0 bg-black/0 group-hover/img:bg-black/10 transition-colors duration-300";

    button.appendChild(img);
    button.appendChild(overlay);

    button.addEventListener("click", () => {
      this.openLightbox(allImages, index);
    });

    return button;
  },

  openLightbox(images, index) {
    const rawPostId = this.el.dataset.postId;
    const postId = rawPostId.replace("public-post-", "");
    this.pushEvent("show_public_timeline_images", {
      post_id: postId,
      image_index: index,
      images: images,
    });
  },

  showErrorState() {
    const container = this.el;
    container.innerHTML = `
      <div class="text-center py-8">
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
  },
};

export default PublicPostImagesHook;
