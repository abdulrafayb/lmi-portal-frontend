import { useId } from "react";
import options from "./icon-options.json";
import { cmsIcons } from "./icons";
export default function IconPicker({ value = "", onChange, original }) {
  const id = useId();
  const Preview = cmsIcons[value];
  return (
    <div className="field">
      <label htmlFor={id}>Icon</label>
      <div className="icon-picker">
        <select
          id={id}
          value={value || ""}
          onChange={(e) => onChange(e.target.value)}
        >
          <option value="">Default ({original})</option>
          {Object.entries(options).map(([key, name]) => (
            <option key={key} value={key}>
              {name}
            </option>
          ))}
        </select>
        {Preview && (
          <span
            className="icon-preview"
            aria-label={`Selected icon: ${options[value]}`}
          >
            <Preview size={28} aria-hidden="true" />
          </span>
        )}
      </div>
      <small className="hint">
        Choose an icon, or use Default to keep the section’s original icon.
        Save, then Publish to update the website.
      </small>
    </div>
  );
}
