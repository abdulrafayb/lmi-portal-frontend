import IconPicker from "./IconPicker";
import {
  MAX_ITEMS,
  fixedCollection,
  itemTemplate,
  blankItem,
  templateStyles,
} from "./collections";
import { useState } from "react";
import ImageField from "./ImageField";
import { useId } from "react";
import { isHeading, headingText, legacyHeadingValue } from "./headings";
const fixed = new Set(["id", "icon", "variant", "type", "as", "number"]);
export const label = (value) =>
  value
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/^./, (c) => c.toUpperCase());
export default function Fields({
  template,
  value,
  onChange,
  name = "Content",
  fieldKey = "",
  onBusy,
}) {
  const id = useId();
  const [styleIndex, setStyleIndex] = useState(0);
  if (fixed.has(fieldKey)) return null;
  if (
    isHeading(fieldKey) &&
    Array.isArray(template) &&
    template.every((item) => item == null || typeof item === "string")
  ) {
    return (
      <Fields
        onBusy={onBusy}
        name={name}
        fieldKey={fieldKey}
        template=""
        value={headingText(value)}
        onChange={(text) => onChange(legacyHeadingValue(text, template))}
      />
    );
  }
  if (Array.isArray(template)) {
    const locked = fixedCollection(fieldKey);
    const items = Array.isArray(value) ? value : [];
    const variants = templateStyles(template);
    return (
      <fieldset>
        <legend>
          {name} <small>{items.length} items</small>
        </legend>
        {items.map((item, i) => (
          <div className="array-item" key={i}>
            <Fields
              onBusy={onBusy}
              name={`${name} ${i + 1}`}
              template={locked ? template[i] : itemTemplate(template, item)}
              value={item}
              onChange={(next) =>
                onChange(items.map((x, j) => (j === i ? next : x)))
              }
            />
            {!locked && (
              <button
                type="button"
                className="secondary"
                onClick={() => onChange(items.filter((_, j) => j !== i))}
                aria-label={`Remove ${name} ${i + 1}`}
              >
                Remove item
              </button>
            )}
          </div>
        ))}
        {!locked && template.length > 0 && (
          <div className="collection-controls">
            {typeof template[0] === "object" && variants.length > 1 && (
              <label>
                Template for new item
                <select
                  value={styleIndex}
                  onChange={(e) => setStyleIndex(Number(e.target.value))}
                >
                  {variants.map((t, i) => (
                    <option key={i} value={i}>
                      {t.icon || t.type || t.id || `Style ${i + 1}`}
                    </option>
                  ))}
                </select>
              </label>
            )}
            {typeof template[0] === "object" && variants.length > 1 && (
              <small className="hint">
                Applies only to the next item you add. Change an existing item's
                icon using its Icon field above.
              </small>
            )}
            <button
              type="button"
              className="secondary"
              disabled={items.length >= MAX_ITEMS}
              onClick={() =>
                onChange([
                  ...items,
                  blankItem(variants[styleIndex] ?? variants[0]),
                ])
              }
            >
              Add item to {name}
            </button>
            <small className="hint">
              Add or remove up to {MAX_ITEMS} items. Save this section, then
              Publish when all your changes are ready.
            </small>
          </div>
        )}
      </fieldset>
    );
  }
  if (template && typeof template === "object")
    return (
      <fieldset>
        <legend>{name}</legend>
        {typeof template.icon === "string" && (
          <IconPicker
            value={value?.iconOverride || ""}
            original={template.icon}
            onChange={(next) => onChange({ ...value, iconOverride: next })}
          />
        )}
        {Object.entries(template).map(([key, item]) => (
          <Fields
            key={key}
            onBusy={onBusy}
            name={label(key)}
            fieldKey={key}
            template={item}
            value={value?.[key]}
            onChange={(next) => onChange({ ...value, [key]: next })}
          />
        ))}
      </fieldset>
    );
  if (typeof template === "boolean")
    return (
      <label className="checkbox">
        <input
          type="checkbox"
          checked={value === true}
          onChange={(e) => onChange(e.target.checked)}
        />
        {name}
      </label>
    );
  const image = /^(image|src|imageUrl)$/i.test(fieldKey);
  const number = typeof template === "number";
  const text = value == null ? "" : String(value);
  const long =
    !image &&
    !/path|href|url/i.test(fieldKey) &&
    (text.length > 100 ||
      /description|paragraph|quote|answer|note/i.test(fieldKey));
  if (image)
    return (
      <ImageField
        value={text}
        onChange={onChange}
        label={name}
        onBusy={onBusy}
      />
    );
  return (
    <div className="field">
      <label htmlFor={id}>{name}</label>
      {long ? (
        <textarea
          id={id}
          rows={3}
          value={text}
          onChange={(e) => onChange(e.target.value)}
        />
      ) : (
        <input
          id={id}
          type={number ? "number" : "text"}
          value={text}
          onChange={(e) =>
            onChange(
              number
                ? e.target.value === ""
                  ? null
                  : Number(e.target.value)
                : e.target.value,
            )
          }
        />
      )}
      <small className="hint">
        {image
          ? "Use a deployed website path such as /home/logo.webp or /public/home/logo.jpg. JPG/JPEG, PNG, WebP, GIF, AVIF, SVG, BMP and other browser-supported formats work; use the exact filename and extension."
          : !number
            ? "Leave blank to omit this content."
            : null}
      </small>
    </div>
  );
}
