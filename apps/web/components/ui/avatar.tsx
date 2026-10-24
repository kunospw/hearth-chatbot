"use client";

import { useState } from "react";
import { argbToCss } from "@/lib/backend/color";
import type { Character } from "@/lib/domain/types";

// Tile + initial first; the image fades in over 150ms and the initial stays on
// error. Mirrors CharacterAvatar. SVG asset or network URL.

interface AvatarProps {
  tile: number;
  ink: number;
  initial: string;
  src?: string | null;
  size?: number;
  radius?: number;
  className?: string;
}

export function Avatar({
  tile,
  ink,
  initial,
  src,
  size = 48,
  radius = 12,
  className = "",
}: AvatarProps) {
  const [loaded, setLoaded] = useState(false);
  return (
    <div
      className={`relative shrink-0 overflow-hidden flex items-center justify-center ${className}`}
      style={{
        width: size,
        height: size,
        borderRadius: radius,
        background: argbToCss(tile),
        color: argbToCss(ink),
      }}
    >
      <span className="font-serif font-medium select-none" style={{ fontSize: size * 0.42 }}>
        {initial}
      </span>
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={src}
          alt=""
          onLoad={() => setLoaded(true)}
          className="absolute inset-0 h-full w-full object-cover transition-opacity duration-150"
          style={{ opacity: loaded ? 1 : 0 }}
        />
      ) : null}
    </div>
  );
}

export function CharacterAvatar({
  character,
  size = 48,
  radius = 12,
  className = "",
}: {
  character: Character;
  size?: number;
  radius?: number;
  className?: string;
}) {
  const initial = character.initial || character.first.slice(0, 1) || "?";
  return (
    <Avatar
      tile={character.tile}
      ink={character.ink}
      initial={initial}
      src={character.portraitUrl}
      size={size}
      radius={radius}
      className={className}
    />
  );
}
