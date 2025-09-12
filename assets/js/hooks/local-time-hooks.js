import { DateTime } from "../../vendor/luxon";

/*
  Will display a UTC timestamp in the user's browser's timezone

  You can pass in an optional options attribute with options JSON-encoded from:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat

  <time phx-hook="LocalTimeHook" id={id} class="invisible" data-options={Jason.encode!(options)}>
    <%= date %>
  </time>

  For a HEEX component, see local_time.ex
*/

export const LocalTimeHook = {
  mounted() {
    this.updated();
  },
  updated() {
    const format = this.el.dataset.format;
    const preset = this.el.dataset.preset;
    const locale = this.el.dataset.locale;
    const dtString = this.el.textContent.trim();
    // Parse as UTC and convert to local time (consistent with other local time hooks)
    const dt = DateTime.fromISO(dtString, { zone: "UTC" }).toLocal().setLocale(locale);

    let formatted;
    if (format) {
      if (format === "relative") {
        formatted = dt.toRelative();
      } else {
        formatted = dt.toFormat(format);
      }
    } else {
      formatted = dt.toLocaleString(DateTime[preset]);
    }

    this.el.textContent = formatted;
    this.el.classList.remove("opacity-0");
  },
};

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
