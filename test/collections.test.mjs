import test from "node:test";
import assert from "node:assert/strict";
import {
  blankItem,
  itemTemplate,
  fixedCollection,
  MAX_ITEMS,
} from "../src/collections.js";
test("new cards keep supported structural values but start without copied content", () => {
  const card = {
    icon: "safety",
    number: "02",
    heading: "Safety",
    description: "Existing copy",
    image: "/old.png",
    items: ["Old point"],
  };
  assert.deepEqual(blankItem(card), {
    icon: "safety",
    number: "02",
    heading: "",
    description: "",
    image: "",
    items: [],
  });
  assert.equal(
    itemTemplate([{ icon: "truck", heading: "" }, card], {
      icon: "safety",
      heading: "Changed",
    }),
    card,
  );
  assert.equal(MAX_ITEMS, 50);
});
test("heading and main-button collections remain fixed; cards and bullets repeat", () => {
  for (const key of ["heading", "mainHeading", "actions", "fields"])
    assert(fixedCollection(key));
  for (const key of ["points", "cards", "locations", "features"])
    assert(!fixedCollection(key));
});

test("style choices distinguish icon structures rather than existing copy", async () => {
  const { templateStyles } = await import("../src/collections.js");
  assert.equal(
    templateStyles([
      { icon: "safety", heading: "One" },
      { icon: "safety", heading: "Two" },
      { icon: "truck", heading: "Three" },
    ]).length,
    2,
  );
});

test("an icon override does not change the item template identity", () => {
  const templates = [
    { icon: "legacy", text: "A" },
    { icon: "coverage", text: "B" },
  ];
  assert.equal(
    itemTemplate(templates, {
      icon: "coverage",
      iconOverride: "icon:truck",
      text: "Changed",
    }),
    templates[1],
  );
});
