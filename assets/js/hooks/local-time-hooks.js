import { DateTime } from "../../vendor/luxon";

export const LocalTime = {
  mounted() {
    this.updated();
  },
  updated() {
    let dt = new Date(this.el.textContent);
    let options = {
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
      timeZoneName: "short",
    };
    this.el.textContent = `${dt.toLocaleString("en-US", options)}`;
    this.el.classList.remove("hidden");
  },
};

export const LocalTimeAgo = {
  mounted() {
    this.updated();
  },
  updated() {
    let dt = DateTime.fromISO(this.el.textContent, { zone: "UTC" }).toLocal();
    let options = {};
    this.el.textContent = `${dt.toRelative(options)}`;
    this.el.classList.remove("hidden");
  },
};

export const LocalTimeFull = {
  mounted() {
    this.updated();
  },
  updated() {
    let dt = DateTime.fromISO(this.el.textContent, { zone: "UTC" }).toLocal();
    this.el.textContent = `${dt.toLocaleString(DateTime.DATETIME_FULL)}`;
    this.el.classList.remove("hidden");
  },
};

export const LocalTimeMed = {
  mounted() {
    this.updated();
  },
  updated() {
    let dt = DateTime.fromISO(this.el.textContent, { zone: "UTC" }).toLocal();
    this.el.textContent = `${dt.toLocaleString(DateTime.DATE_MED)}`;
    this.el.classList.remove("hidden");
  },
};

export const LocalTimeNow = {
  mounted() {
    this.updated();
  },
  updated() {
    let dt = DateTime.local();
    this.el.textContent = `${dt.toLocaleString(DateTime.DATETIME_FULL)}`;
    this.el.classList.remove("hidden");
  },
};

export const LocalTimeNowMed = {
  mounted() {
    this.updated();
  },
  updated() {
    let dt = DateTime.local();
    this.el.textContent = `${dt.toLocaleString(DateTime.DATE_MED)}`;
    this.el.classList.remove("hidden");
  },
};
