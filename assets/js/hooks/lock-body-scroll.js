export default {
  mounted() {
    this.previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
  },
  destroyed() {
    document.body.style.overflow = this.previousOverflow || "";
  },
};
