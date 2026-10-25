"use client";

import { useEffect } from "react";

// A simple sheet/dialog: bottom sheet on phones, centred card on wider screens.
export function Modal({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
}) {
  useEffect(() => {
    if (!open) return;
    const h = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      <button
        type="button"
        aria-label="Close"
        className="absolute inset-0"
        style={{ background: "var(--scrim)" }}
        onClick={onClose}
      />
      <div className="relative w-full sm:max-w-md bg-surface border border-outline rounded-t-sheet sm:rounded-sheet p-5 flex flex-col gap-4 max-h-[85vh] overflow-y-auto">
        {title ? <div className="t-title">{title}</div> : null}
        {children}
      </div>
    </div>
  );
}
