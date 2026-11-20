import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { getColors, saveColors } from "./api";
const names = {
  "brand-red": "Primary brand color",
  "brand-red-dark": "Primary hover color",
  "proof-accent": "Yellow / accent",
  "action-amber-hover": "Accent hover",
  surface: "White surface / light text",
  "proof-surface": "Cream background",
  "hero-heading": "Headings",
  "hero-copy": "Paragraphs",
  "brand-ink": "Footer background",
  "trust-border": "Card borders",
};
const mainKeys = Object.keys(names);
const label = (key) =>
  names[key] || key.replaceAll("-", " ").replace(/^./, (c) => c.toUpperCase());
function Editor({ entry, onDirty, onSaved }) {
  const [colors, setColors] = useState(entry.colors);
  const cache = useQueryClient();
  const dirty = JSON.stringify(colors) !== JSON.stringify(entry.colors);
  const valid = Object.values(colors).every((v) =>
    /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(v),
  );
  useEffect(() => {
    onDirty(dirty);
    return () => onDirty(false);
  }, [dirty, onDirty]);
  const save = useMutation({
    mutationFn: () => saveColors(colors, entry.revision),
    onSuccess: async (result) => {
      onSaved(
        result.unchanged
          ? "No changes to save."
          : "Colors saved. Use Publish at the top to apply them to the website.",
      );
      await cache.invalidateQueries({ queryKey: ["colors"] });
      await cache.invalidateQueries({ queryKey: ["history"] });
    },
  });
  const field = (key) => (
    <div className="palette-field" key={key}>
      <label htmlFor={"color-" + key}>{label(key)}</label>
      <div className="palette-input">
        <input
          aria-label={`${label(key)} picker`}
          type="color"
          value={
            /^#[0-9a-f]{6}/i.test(colors[key])
              ? colors[key].slice(0, 7)
              : "#000000"
          }
          onChange={(e) =>
            setColors((c) => ({
              ...c,
              [key]:
                e.target.value + (c[key].length === 9 ? c[key].slice(7) : ""),
            }))
          }
        />
        <input
          id={"color-" + key}
          value={colors[key]}
          maxLength={9}
          spellCheck={false}
          aria-invalid={!/^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(colors[key])}
          onChange={(e) => setColors((c) => ({ ...c, [key]: e.target.value }))}
        />
      </div>
      <small className="hint">{key}</small>
    </div>
  );
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        save.mutate();
      }}
    >
      <h1>Colors</h1>
      <p>
        Choose the shared website colors. Save your palette, then Publish once
        to apply all saved changes.
      </p>
      <p className="hint">
        Revision {entry.revision} · Use #RRGGBB or #RRGGBBAA for transparency.
        Photos and logo images keep their original colors.
      </p>
      <fieldset disabled={save.isPending}>
        <div className="palette-grid">
          {mainKeys.filter((k) => k in colors).map(field)}
        </div>
        <details>
          <summary>More website colors</summary>
          <div className="palette-grid">
            {Object.keys(colors)
              .filter((k) => !mainKeys.includes(k))
              .map(field)}
          </div>
        </details>
        <button
          type="button"
          className="secondary"
          onClick={() => setColors(structuredClone(entry.defaults))}
        >
          Restore default palette
        </button>
      </fieldset>
      {!valid && (
        <p className="error" role="alert">
          Enter valid six or eight digit hex colors before saving.
        </p>
      )}
      {save.error && (
        <p className="error" role="alert">
          {save.error.message}
        </p>
      )}
      <div className="editor-actions">
        <span className="hint">
          {dirty ? "Unsaved changes" : "All colors saved"}
        </span>
        <button
          type="button"
          className="secondary"
          disabled={!dirty || save.isPending}
          onClick={() => setColors(structuredClone(entry.colors))}
        >
          Cancel
        </button>
        <button disabled={!dirty || !valid || save.isPending}>
          {save.isPending ? "Saving…" : "Save"}
        </button>
      </div>
    </form>
  );
}
export default function Colors({ onDirty }) {
  const [message, setMessage] = useState("");
  const result = useQuery({ queryKey: ["colors"], queryFn: getColors });
  if (result.isPending) return <p role="status">Loading colors…</p>;
  if (result.error)
    return (
      <p className="error" role="alert">
        {result.error.message}
      </p>
    );
  return (
    <>
      {message && (
        <p className="success" role="status">
          {message}
        </p>
      )}
      <Editor
        key={result.data.revision}
        entry={result.data}
        onDirty={onDirty}
        onSaved={setMessage}
      />
    </>
  );
}
