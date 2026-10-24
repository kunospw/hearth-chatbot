import type { Metadata } from "next";
import { AgeGate } from "@/components/age-gate";
import { figtree, newsreader } from "./fonts";
import { Providers } from "./providers";
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
      <body>
        <Providers>
          <AgeGate>{children}</AgeGate>
        </Providers>
      </body>
    </html>
  );
}
