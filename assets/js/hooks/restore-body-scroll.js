// Handle body scroll restoration after modal form submission
export default {
  mounted() {
    this.handleEvent("restore-body-scroll", () => {
      document.body.classList.remove("overflow-hidden");
      document.body.style.overflow = "";
    });
  },
};
