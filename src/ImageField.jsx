import { useId, useState } from "react";
import { uploadImage, WEBSITE } from "./api";
import { imagePreviewSource } from "./imagePaths";
export default function ImageField({
  value = "",
  onChange,
  label = "Image",
  onBusy = () => {},
}) {
  const id = useId();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [failed, setFailed] = useState("");
  const src = imagePreviewSource(value, WEBSITE);
  return (
    <div className="field">
      <label htmlFor={id}>{label}</label>
      <input
        id={id}
        value={value ?? ""}
        onChange={(e) => onChange(e.target.value)}
        disabled={busy}
        placeholder="/home/photo.webp or https://…"
      />
      <label className="hint" htmlFor={id + "-upload"}>
        Or upload an image (JPG, PNG, WebP, GIF, AVIF · up to 10 MB)
      </label>
      <input
        id={id + "-upload"}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif,image/avif"
        disabled={busy}
        onChange={async (e) => {
          const file = e.target.files?.[0];
          if (!file) return;
          setBusy(true);
          onBusy(true);
          setError("");
          try {
            onChange(await uploadImage(file));
          } catch (err) {
            setError(err.message);
          } finally {
            setBusy(false);
            onBusy(false);
            e.target.value = "";
          }
        }}
      />
      {busy && <p role="status">Uploading…</p>}
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {src && failed !== src && (
        <img
          className="image-preview"
          src={src}
          alt="Image preview"
          onError={() => setFailed(src)}
        />
      )}
      <small className="hint">
        Use an exact deployed public-folder path or HTTPS URL, or upload to the
        media library. Save/publish to use your image.
      </small>
    </div>
  );
}
