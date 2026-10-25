import { Overline } from "./overline";

// Labelled input / textarea used by forms.
export function Field({
  label,
  value,
  onChange,
  textarea,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  textarea?: boolean;
  placeholder?: string;
}) {
  const cls =
    "w-full bg-bg border border-outline rounded-field px-3 py-2.5 text-[15px] text-text placeholder:text-subtle outline-none focus:border-ink";
  return (
    <label className="flex flex-col gap-1.5">
      <Overline>{label}</Overline>
      {textarea ? (
        <textarea
          rows={3}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className={`${cls} resize-y min-h-20`}
        />
      ) : (
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className={`${cls} min-h-12`}
        />
      )}
    </label>
  );
}
