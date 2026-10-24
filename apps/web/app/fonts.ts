import localFont from "next/font/local";

// Midnight Editorial type: Newsreader = story/display serif, Figtree = UI.
// Both are variable TTFs (bundled, not fetched at runtime), so we expose the
// full weight axis and both styles. Mirrors lib/core/theme/hearth_text.dart.

export const newsreader = localFont({
  src: [
    { path: "./fonts/Newsreader.ttf", weight: "200 800", style: "normal" },
    { path: "./fonts/Newsreader-Italic.ttf", weight: "200 800", style: "italic" },
  ],
  variable: "--font-newsreader",
  display: "swap",
});

export const figtree = localFont({
  src: [
    { path: "./fonts/Figtree.ttf", weight: "300 900", style: "normal" },
    { path: "./fonts/Figtree-Italic.ttf", weight: "300 900", style: "italic" },
  ],
  variable: "--font-figtree",
  display: "swap",
});
