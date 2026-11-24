import type { Register, ThemeSetArgs } from "claude-code";

import { makeColors } from "./make-colors.js";
import pleno from "./palette.js";

type Hex = `#${string}`;
type Mode = {
  canvas: Hex;
  accent: Hex;
  sidebar: Hex;
  text: Hex;
  mutedForeground: Hex;
  messageSurface: Hex;
};

const dark: Mode = {
  ...pleno.colors,
  canvas: pleno.canvas,
  accent: pleno.accent,
} as Mode;
const light: Mode = pleno.variants.light as Mode;

// Desktop paints the sidebar from surface-0 and the chat column from the backdrop; other surfaces stay on the canvas.
const anchors = (m: Mode) => ({
  "surface-0": m.sidebar,
  "surface-1": m.canvas,
  "surface-2": m.canvas,
  "surface-3": m.canvas,
  "text-primary": m.text,
  "text-muted": m.mutedForeground,
});

const { theme, problems } = makeColors({
  label: pleno.name,
  roles: {
    accent: "#8f8f8f",
    danger: "#d14b4b",
    success: "#4fa36b",
    warning: "#c9952e",
    pro: "#8b6fc4",
  },
  light: { gray: { anchors: anchors(light) } },
  dark: { gray: { anchors: anchors(dark) } },
});

theme.inputs.light = {
  ...theme.inputs.light,
  "bg-user-message": light.messageSurface,
  "text-user-message": light.text,
};
theme.inputs.dark = {
  ...theme.inputs.dark,
  "bg-user-message": dark.messageSurface,
  "text-user-message": dark.text,
};

const LOOK: ThemeSetArgs = { colors: theme, backdrop: { color: "surface-1" } };

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
