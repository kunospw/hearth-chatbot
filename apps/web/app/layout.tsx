import type { Metadata } from "next";
import { figtree, newsreader } from "./fonts";
import "./globals.css";

export const metadata: Metadata = {
  title: "Hearth",
  description: "AI character roleplay and creative writing.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="en"
      data-theme="dark"
      className={`${figtree.variable} ${newsreader.variable}`}
    >
      <body>{children}</body>
    </html>
  );
}
