import { type ButtonHTMLAttributes, forwardRef } from "react";

type Variant = "filled" | "ghost" | "text";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
}

const base =
  "inline-flex items-center justify-center gap-2 font-sans font-semibold text-[16px] rounded-button px-5 min-h-12 transition-colors disabled:opacity-50 disabled:pointer-events-none";

// Burgundy is a fill only; text/ghost use rose ink (SPEC).
const variants: Record<Variant, string> = {
  filled: "bg-primary text-on-primary hover:bg-primary-pressed",
  ghost: "border border-outline text-ink hover:bg-surface",
  text: "text-ink hover:bg-surface px-3!",
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = "filled", className = "", ...rest },
  ref,
) {
  return <button ref={ref} className={`${base} ${variants[variant]} ${className}`} {...rest} />;
});
