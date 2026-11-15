import { test } from "node:test";
import assert from "node:assert/strict";
import { headingText, legacyHeadingValue, isHeading } from "../src/headings.js";
test("one editor field joins old headings and preserves publishing until migration", () => {
  const template = ["First", "Second", "Third"];
  assert.equal(headingText(template), "First Second Third");
  assert.deepEqual(legacyHeadingValue("One heading", template), [
    "One heading",
    "",
    "",
  ]);
  assert.equal(
    headingText(legacyHeadingValue("One heading", template)),
    "One heading",
  );
  assert.equal(headingText("Already one heading"), "Already one heading");
  assert.equal(isHeading("heading"), true);
  assert.equal(isHeading("items"), false);
});
