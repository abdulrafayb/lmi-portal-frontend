import { imagePreviewSource } from "./imagePaths";
import { useId, useState } from "react";
import { isHeading, headingText, legacyHeadingValue } from "./headings";
import { WEBSITE } from "./api";
const fixed = new Set(["id", "icon", "variant", "type", "as", "number"]);
export const label = (value) =>
  value
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/^./, (c) => c.toUpperCase());
function ImagePreview({ value }) {
  const [failed, setFailed] = useState(false);
  const src = imagePreviewSource(value, WEBSITE);
  return src && !failed ? (
    <img
      className="image-preview"
      alt="Image preview"
      src={src}
      onError={() => setFailed(true)}
    />
  ) : (
    <span className="hint">
      {failed
        ? "This image could not be loaded from the website."
        : "No image selected."}
    </span>
  );
}
export default function Fields({
  template,
  value,
  onChange,
  name = "Content",
  fieldKey = "",
}) {
  const id = useId();
  if (fixed.has(fieldKey)) return null;
  if (
    isHeading(fieldKey) &&
    Array.isArray(template) &&
    template.every((item) => item == null || typeof item === "string")
  ) {
    return (
      <Fields
        name={name}
        fieldKey={fieldKey}
        template=""
        value={headingText(value)}
        onChange={(text) => onChange(legacyHeadingValue(text, template))}
      />
    );
  }
  if (Array.isArray(template))
    return (
      <fieldset>
        <legend>
          {name} <small>{template.length} fixed items</small>
        </legend>
        {template.map((item, i) => (
          <div className="array-item" key={i}>
            <Fields
              name={`${name} ${i + 1}`}
              template={item}
              value={value?.[i]}
              onChange={(next) => {
                const arr = Array.isArray(value)
                  ? [...value]
                  : template.map(() => null);
                arr[i] = next;
                onChange(arr);
              }}
            />
          </div>
        ))}
      </fieldset>
    );
  if (template && typeof template === "object")
    return (
      <fieldset>
        <legend>{name}</legend>
        {Object.entries(template).map(([key, item]) => (
          <Fields
            key={key}
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
      {image && <ImagePreview key={text} value={text} />}
    </div>
  );
}
