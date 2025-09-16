// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const defaultTheme = require("tailwindcss/defaultTheme");
const plugin = require("tailwindcss/plugin");
const colors = require("tailwindcss/colors");
const fs = require("fs");
const path = require("path");

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/mosslet_web.ex",
    "../lib/mosslet_web/**/*.*ex",
    "../deps/live_select/lib/live_select/component.*ex",
    "../deps/petal_components/**/*.*ex",
  ],
  darkMode: "class",
  theme: {
    extend: {
      fontFamily: {
        sans: ["Nunito", defaultTheme.fontFamily.sans],
        display: ["Nunito", defaultTheme.fontFamily.sans],
      },
      animation: {
        blob: "blob 10s ease-in-out",
      },
      keyframes: {
        blob: {
          "0%": {
            transform: "translate(Opx, Opx) scale(1)",
          },
          "33%": {
            transform: "translate(30px, -50px) scale(1.2)",
          },

          "66%": {
            transform: "translate(-20px, 20px) scale(0.8)",
          },
          "100%": {
            transform: "tranlate(Opx, Opx) scale(1)",
          },
        },
      },
      colors: {
        brand: {
          50: "#eef7fe",
          100: "#ddf0fd",
          200: "#bbe0fb",
          300: "#98d1f9",
          400: "#76c1f7",
          500: "#54b2f5",
          600: "#438ec4",
          700: "#326b93",
          800: "#224762",
          900: "#112431",
        },
        // Design system liquid metal colors
        primary: colors.emerald,
        secondary: colors.amber,
        success: colors.emerald,
        danger: colors.rose,
        warning: colors.yellow,
        info: colors.cyan,
        // Background system for liquid metal effects
        background: {
          50: colors.slate[50],
          100: colors.slate[100],
          200: colors.slate[200],
          300: colors.slate[300],
          600: colors.slate[600],
          700: colors.slate[700],
          800: colors.slate[800],
          900: colors.slate[900],
        },
        transparent: "transparent",
        current: "currentColor",
        black: colors.black,
        white: colors.white,
        gray: colors.gray,
        emerald: colors.emerald,
        orange: colors.orange,
        indigo: colors.indigo,
        purple: colors.purple,
        pink: colors.pink,
        red: colors.red,
        rose: colors.rose,
        yellow: colors.yellow,
        zinc: colors.zinc,
      },
      rotate: {
        15: "15deg",
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    require("@tailwindcss/aspect-ratio"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) =>
      addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-click-loading", [
        ".phx-click-loading&",
        ".phx-click-loading &",
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-submit-loading", [
        ".phx-submit-loading&",
        ".phx-submit-loading &",
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-change-loading", [
        ".phx-change-loading&",
        ".phx-change-loading &",
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant("drag-item", [".drag-item&", ".drag-item &"])
    ),
    plugin(({ addVariant }) =>
      addVariant("drag-ghost", [".drag-ghost&", ".drag-ghost &"])
    ),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized");
      let values = {};
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"],
      ];
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
          let name = path.basename(file, ".svg") + suffix;
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) };
        });
      });
      matchComponents(
        {
          hero: ({ name, fullPath }) => {
            let content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\r?\n|\r/g, "");
            let size = theme("spacing.6");
            if (name.endsWith("-mini")) {
              size = theme("spacing.5");
            } else if (name.endsWith("-micro")) {
              size = theme("spacing.4");
            }
            return {
              [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
              "-webkit-mask": `var(--hero-${name})`,
              mask: `var(--hero-${name})`,
              "mask-repeat": "no-repeat",
              "background-color": "currentColor",
              "vertical-align": "middle",
              display: "inline-block",
              width: size,
              height: size,
            };
          },
        },
        { values }
      );
    }),
  ],
};
