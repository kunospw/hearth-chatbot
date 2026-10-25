import { describe, expect, it } from "vitest";
import { argbToCss, hexToArgb, rgbToArgb } from "./color";

describe("color", () => {
  it("round-trips hex -> argb -> css", () => {
    const argb = hexToArgb("#9A3349");
    expect(argb).toBe(rgbToArgb(0x9a, 0x33, 0x49));
    expect(argbToCss(argb)).toBe("rgb(154 51 73)");
  });

  it("keeps full-opacity colours opaque and renders alpha otherwise", () => {
    expect(argbToCss(rgbToArgb(0, 0, 0, 0xff))).toBe("rgb(0 0 0)");
    expect(argbToCss(rgbToArgb(255, 255, 255, 0x80))).toBe("rgb(255 255 255 / 0.502)");
  });

  it("parses 8-digit hex with alpha", () => {
    expect(argbToCss(hexToArgb("#80FFFFFF"))).toBe("rgb(255 255 255 / 0.502)");
  });
});
