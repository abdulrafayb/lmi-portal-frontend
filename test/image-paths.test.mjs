import { test } from "node:test";
import assert from "node:assert/strict";
import { imagePreviewSource } from "../src/imagePaths.js";
test("portal previews common image formats with root paths and /public aliases", () => {
  for (const extension of [
    "jpg",
    "jpeg",
    "png",
    "webp",
    "gif",
    "avif",
    "svg",
    "bmp",
    "ico",
    "apng",
    "jfif",
    "JPG",
  ]) {
    assert.equal(
      imagePreviewSource(`/home/logo.${extension}`, "https://lmi.example"),
      `https://lmi.example/home/logo.${extension}`,
    );
    assert.equal(
      imagePreviewSource(
        `/public/home/logo.${extension}`,
        "https://lmi.example",
      ),
      `https://lmi.example/home/logo.${extension}`,
    );
  }
  assert.equal(
    imagePreviewSource(
      "https://cdn.example/logo.webp?v=2",
      "https://lmi.example",
    ),
    "https://cdn.example/logo.webp?v=2",
  );
  assert.equal(
    imagePreviewSource("/home/my logo.png", "https://lmi.example"),
    "https://lmi.example/home/my%20logo.png",
  );
});
test("portal previews reject unsafe sources without depending on extension", () => {
  for (const value of [
    "javascript:alert(1)",
    "data:image/svg+xml,bad",
    "//evil.example/logo.png",
    "file:///logo.png",
    "https://user:pass@cdn.example/logo.jpg",
    "relative.png",
    "/home/\\image.png",
  ])
    assert.equal(imagePreviewSource(value, "https://lmi.example"), "");
  assert.equal(imagePreviewSource("", "https://lmi.example"), "");
});
