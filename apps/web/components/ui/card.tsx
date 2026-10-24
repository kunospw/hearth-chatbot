import type { HTMLAttributes } from "react";

export function Card({ className = "", ...rest }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={`bg-surface border border-outline rounded-card ${className}`}
      {...rest}
    />
  );
}
