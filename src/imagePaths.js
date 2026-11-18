// Keep paths extension-agnostic; the browser determines whether it can decode the image.
export function imagePreviewSource(value, website) {
  if (typeof value !== "string" || !value.trim()) return "";
  const path = value.trim().replace(/^\/public\//, "/");
  if (path.startsWith("//") || /[\u0000-\u001f\\]/.test(path)) return "";
  try {
    if (!/^https?:\/\//i.test(path) && !path.startsWith("/")) return "";
    const url = path.startsWith("/") ? new URL(path, website) : new URL(path);
    if (
      url.protocol !== "https:" &&
      !(
        url.protocol === "http:" &&
        ["localhost", "127.0.0.1"].includes(url.hostname)
      )
    )
      return "";
    if (url.username || url.password) return "";
    return url.href;
  } catch {
    return "";
  }
}
