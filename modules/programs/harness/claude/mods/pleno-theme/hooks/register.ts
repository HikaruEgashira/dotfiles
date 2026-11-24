import type { Register, ThemeSetArgs } from "claude-code";

import { makeColors } from "./make-colors.js";

const { theme, problems } = makeColors({
  label: "Pleno",
  roles: {
    accent: "#8f8f8f",
    danger: "#d14b4b",
    success: "#4fa36b",
    warning: "#c9952e",
    pro: "#8b6fc4",
  },
  light: {
    gray: {
      anchors: {
        "surface-0": "#f6f6f6",
        "surface-1": "#fcfcfc",
        "surface-2": "#ffffff",
        "text-primary": "#1a1a1a",
        "text-secondary": "#3d3d3d",
        "text-muted": "#6b6b6b",
      },
    },
  },
  dark: {
    gray: {
      anchors: {
        "surface-0": "#0f0f0f",
        "surface-1": "#161616",
        "surface-2": "#1c1c1c",
        "surface-3": "#202020",
        "text-primary": "#ededed",
        "text-secondary": "#c2c2c2",
        "text-muted": "#8f8f8f",
      },
    },
  },
});

theme.inputs.light = {
  ...theme.inputs.light,
  "bg-user-message": "#efefef",
  "text-user-message": "#1a1a1a",
};
theme.inputs.dark = {
  ...theme.inputs.dark,
  "bg-user-message": "#1c1c1c",
  "text-user-message": "#ededed",
};

const LOOK: ThemeSetArgs = { colors: theme };

export const register: Register = (on) => {
  on("session.start", async ($, e, next) => {
    const unpainted = problems.find((line) =>
      line.startsWith("Desktop won't paint"),
    );
    if (unpainted !== undefined) {
      $.ui.toast(unpainted);
    }
    const set = await $.theme.set(LOOK);
    if (!set.isDrawn) {
      $.ui.status(set.reason);
    }
    return next(e);
  });
};
