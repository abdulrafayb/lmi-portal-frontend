export const isHeading = (key) => /heading$/i.test(key);
export const headingText = (value) =>
  Array.isArray(value)
    ? value
        .filter((part) => typeof part === "string")
        .map((part) => part.trim())
        .filter(Boolean)
        .join(" ")
    : typeof value === "string"
      ? value
      : "";
// Keep the old database contract working until the SQL migration has run.
export const legacyHeadingValue = (text, template) =>
  template.map((_, index) => (index === 0 ? text : ""));
