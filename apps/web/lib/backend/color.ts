// Characters and universes store a tile/ink colour as a Flutter ARGB32 integer
// (0xAARRGGBB). These convert to/from CSS so the web renders the same swatches.

export function argbToCss(argb: number): string {
  const a = (argb >>> 24) & 0xff;
  const r = (argb >>> 16) & 0xff;
  const g = (argb >>> 8) & 0xff;
  const b = argb & 0xff;
  return a === 0xff
    ? `rgb(${r} ${g} ${b})`
    : `rgb(${r} ${g} ${b} / ${(a / 255).toFixed(3)})`;
}

export function rgbToArgb(r: number, g: number, b: number, a = 0xff): number {
  // >>> 0 keeps it an unsigned 32-bit int, matching Flutter's toARGB32().
  return (((a & 0xff) << 24) | ((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff)) >>> 0;
}

/** Parse "#rrggbb" / "#aarrggbb" into an ARGB32 int. */
export function hexToArgb(hex: string): number {
  const h = hex.replace(/^#/, "");
  if (h.length === 6) {
    return rgbToArgb(
      parseInt(h.slice(0, 2), 16),
      parseInt(h.slice(2, 4), 16),
      parseInt(h.slice(4, 6), 16),
    );
  }
  if (h.length === 8) {
    return (
      ((parseInt(h.slice(0, 2), 16) << 24) |
        (parseInt(h.slice(2, 4), 16) << 16) |
        (parseInt(h.slice(4, 6), 16) << 8) |
        parseInt(h.slice(6, 8), 16)) >>>
      0
    );
  }
  return 0xff000000;
}
