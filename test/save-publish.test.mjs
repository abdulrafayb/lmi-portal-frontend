import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
// Exercise the production API with a fake Supabase transport, without browser/Vite setup.
const source = (
  await readFile(new URL("../src/api.js", import.meta.url), "utf8")
)
  .replace(/^import .*?;\n/, "")
  .replaceAll("import.meta.env", "env")
  .replaceAll("export ", "");
const createApi = new Function(
  "createClient",
  "env",
  "window",
  source + "\nreturn {saveSection,savePost,requestWebsiteBuild};",
);
test("saving multiple sections and posts never requests a pipeline; explicit Publish requests one", async () => {
  const calls = [];
  let builds = 0;
  let fail = false;
  const api = createApi(
    () => ({
      rpc: async (name, params) => {
        calls.push({ name, params });
        return { data: { revision: params.p_expected_revision + 1 } };
      },
      functions: {
        invoke: async () => {
          builds++;
          return {
            data: { requested: true },
            error: fail ? new Error("Offline") : null,
          };
        },
      },
    }),
    {
      VITE_SUPABASE_URL: "https://test.example",
      VITE_SUPABASE_PUBLISHABLE_KEY: "test",
    },
    { sessionStorage: {} },
  );
  assert.equal(
    (await api.saveSection("home", "sectionOne", { heading: "First" }, true, 2))
      .revision,
    3,
  );
  await api.saveSection("home", "sectionTwo", { heading: "Second" }, true, 3);
  await api.savePost({ status: "published", title: "Test" }, "post-id", 4);
  assert.equal(builds, 0);
  assert.equal(calls.length, 3);
  assert.equal(calls[0].params.p_expected_revision, 2);
  assert.equal(calls[2].name, "cms_save_post");
  await api.requestWebsiteBuild();
  assert.equal(builds, 1);
  assert.equal(calls.length, 3);
  fail = true;
  await assert.rejects(api.requestWebsiteBuild(), /Content is saved/);
  assert.equal(calls.length, 3);
  assert.equal(builds, 2);
});
