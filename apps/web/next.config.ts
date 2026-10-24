import type { NextConfig } from "next";
import path from "node:path";

const nextConfig: NextConfig = {
  // Self-hosted on a VPS behind Caddy — standalone output bundles a minimal
  // Node server (apps/web/.next/standalone) that runs under systemd.
  output: "standalone",
  // Trace from the monorepo root so workspace files are bundled correctly.
  // `next` runs with cwd = apps/web (pnpm --filter), so ../../ is the root.
  outputFileTracingRoot: path.join(process.cwd(), "../../"),
};

export default nextConfig;
