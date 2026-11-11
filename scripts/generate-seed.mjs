import { readFileSync, writeFileSync } from "node:fs";
const catalog = JSON.parse(
  readFileSync(new URL("../supabase/catalog.json", import.meta.url)),
);
const quote = (v) => `'${String(v).replaceAll("'", "''")}'`;
let sql =
  "-- Initial website content. Safe to rerun: never overwrites publications.\nbegin;\n";
let position = 0;
for (const p of Object.values(catalog)) {
  sql += `insert into public.cms_pages(id,title,route,position) values(${quote(p.id)},${quote(p.title)},${quote(p.route)},${position++}) on conflict(id) do nothing;\n`;
  let sectionPosition = 0;
  for (const [key, data] of Object.entries(p.sections)) {
    const json = quote(JSON.stringify(data));
    sql += `insert into public.cms_sections(page_id,key,position,template,data) values(${quote(p.id)},${quote(key)},${sectionPosition++},${json}::jsonb,${json}::jsonb) on conflict(page_id,key) do nothing;\n`;
  }
}
sql += "commit;\n";
writeFileSync(new URL("../supabase/seed.sql", import.meta.url), sql);
console.log(`Generated ${position} pages of seed content.`);
