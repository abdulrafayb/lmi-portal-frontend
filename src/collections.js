export const MAX_ITEMS = 50;
const fixed = new Set(["id", "icon", "variant", "type", "as", "number"]);
export const fixedCollection = (key) =>
  /heading$/i.test(key) || ["actions", "fields"].includes(key);
export function itemTemplate(templates, value) {
  return (
    templates.find((t) => {
      if (!t || typeof t !== "object" || Array.isArray(t))
        return typeof t === typeof value;
      return (
        value &&
        typeof value === "object" &&
        Object.keys(value).every(
          (k) =>
            Object.hasOwn(t, k) ||
            (k === "iconOverride" && typeof t.icon === "string"),
        ) &&
        [...fixed].every((k) => value[k] == null || t[k] === value[k])
      );
    }) ?? templates[0]
  );
}
export function blankItem(template, key = "") {
  if (fixed.has(key)) return template;
  if (Array.isArray(template))
    return fixedCollection(key) ? template.map((t) => blankItem(t)) : [];
  if (template && typeof template === "object")
    return Object.fromEntries(
      Object.entries(template).map(([k, v]) => [k, blankItem(v, k)]),
    );
  if (typeof template === "boolean") return template;
  if (typeof template === "number") return 0;
  return "";
}

function styleShape(value, key = "") {
  if (fixed.has(key)) return value;
  if (Array.isArray(value)) return value.map((item) => styleShape(item));
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, styleShape(v, k)]),
    );
  return typeof value;
}
export function templateStyles(templates) {
  const seen = new Set();
  return templates.filter((item) => {
    const signature = JSON.stringify(styleShape(item));
    if (seen.has(signature)) return false;
    seen.add(signature);
    return true;
  });
}
