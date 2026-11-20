import { imagePreviewSource } from "./imagePaths";
import { useEffect, useState } from "react";
import { useEditor, EditorContent } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import Image from "@tiptap/extension-image";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { getPosts, savePost, getPostHistory, WEBSITE } from "./api";
import ImageField from "./ImageField";
const types = { blog: "Blog", "case-study": "Case study", article: "Article" };
const routes = {
  blog: "blogs",
  "case-study": "case-studies",
  article: "articles",
};
const empty = () => ({
  kind: "blog",
  slug: "",
  title: "",
  excerpt: "",
  image: "",
  image_alt: "",
  author: "",
  author_role: "",
  tags: [],
  category: "",
  content: { type: "doc", content: [{ type: "paragraph" }] },
  seo_title: "",
  seo_description: "",
  status: "draft",
  published_at: new Date().toISOString(),
});
const editable = [
  "kind",
  "slug",
  "title",
  "excerpt",
  "image",
  "image_alt",
  "author",
  "author_role",
  "tags",
  "category",
  "content",
  "seo_title",
  "seo_description",
  "status",
  "published_at",
];
function TagInput({ value, onChange }) {
  const [input, setInput] = useState("");
  const [error, setError] = useState("");
  const add = () => {
    const additions = input
      .split(",")
      .map((t) => t.trim())
      .filter(Boolean);
    const next = [...value];
    for (const tag of additions) {
      if (tag.length > 50) {
        setError("Each tag can be up to 50 characters.");
        return;
      }
      if (!next.some((t) => t.toLowerCase() === tag.toLowerCase()))
        next.push(tag);
    }
    if (next.length > 20) {
      setError("Use up to 20 tags.");
      return;
    }
    onChange(next);
    setInput("");
    setError("");
  };
  return (
    <div className="field">
      <label htmlFor="post-tags">Tags</label>
      <div className="tag-entry">
        <input
          id="post-tags"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === ",") {
              e.preventDefault();
              add();
            }
          }}
          onBlur={() => {
            if (input.trim()) add();
          }}
          placeholder="Add a tag and press Enter"
        />
        <button type="button" className="secondary" onClick={add}>
          Add tags
        </button>
      </div>
      <small className="hint">
        Add multiple tags with Enter or separate them with commas. Up to 20
        tags.
      </small>
      <ul className="tag-pills" aria-label="Publication tags">
        {value.map((tag) => (
          <li key={tag}>
            {tag}
            <button
              type="button"
              className="secondary"
              aria-label={`Remove tag ${tag}`}
              onClick={() => onChange(value.filter((t) => t !== tag))}
            >
              ×
            </button>
          </li>
        ))}
      </ul>
      {error && (
        <p role="alert" className="error">
          {error}
        </p>
      )}
    </div>
  );
}
function RichEditor({ value, onChange, onBusy }) {
  const [image, setImage] = useState("");
  const [showImage, setShowImage] = useState(false);
  const editor = useEditor({
    extensions: [
      StarterKit.configure({
        heading: { levels: [2, 3, 4] },
        link: { openOnClick: false },
      }),
      Image.extend({
        renderHTML({ HTMLAttributes }) {
          return [
            "img",
            {
              ...HTMLAttributes,
              src: imagePreviewSource(HTMLAttributes.src, WEBSITE),
            },
          ];
        },
      }),
    ],
    content: value,
    onUpdate: ({ editor }) => onChange(editor.getJSON()),
    editorProps: {
      attributes: {
        "aria-label": "Post body",
        role: "textbox",
        "aria-multiline": "true",
      },
    },
  });
  if (!editor) return null;
  const tool = (label, action, active = false) => (
    <button
      type="button"
      className={active ? "active" : "secondary"}
      aria-pressed={active}
      onClick={action}
    >
      {label}
    </button>
  );
  return (
    <div className="rich-editor">
      <div className="rich-toolbar" role="toolbar" aria-label="Text formatting">
        {tool("Paragraph", () => editor.chain().focus().setParagraph().run())}
        {[2, 3, 4].map((level) => (
          <span key={level}>
            {tool(
              `H${level}`,
              () => editor.chain().focus().toggleHeading({ level }).run(),
              editor.isActive("heading", { level }),
            )}
          </span>
        ))}
        {tool(
          "Bold",
          () => editor.chain().focus().toggleBold().run(),
          editor.isActive("bold"),
        )}
        {tool(
          "Italic",
          () => editor.chain().focus().toggleItalic().run(),
          editor.isActive("italic"),
        )}
        {tool(
          "Underline",
          () => editor.chain().focus().toggleUnderline().run(),
          editor.isActive("underline"),
        )}
        {tool(
          "Strike",
          () => editor.chain().focus().toggleStrike().run(),
          editor.isActive("strike"),
        )}
        {tool("Bullets", () => editor.chain().focus().toggleBulletList().run())}
        {tool("Numbered list", () =>
          editor.chain().focus().toggleOrderedList().run(),
        )}
        {tool("Quote", () => editor.chain().focus().toggleBlockquote().run())}
        {tool("Code", () => editor.chain().focus().toggleCodeBlock().run())}
        {tool("Divider", () =>
          editor.chain().focus().setHorizontalRule().run(),
        )}
        {tool("Link", () => {
          const url = window.prompt(
            "Link URL (https://…, /path or mailto:…)",
            editor.getAttributes("link").href || "",
          );
          if (url === null) return;
          if (!url) editor.chain().focus().unsetLink().run();
          else if (/^(https?:\/\/|\/(?!\/)|mailto:|#)/i.test(url))
            editor.chain().focus().setLink({ href: url }).run();
          else window.alert("Use a website path, HTTPS URL or email link.");
        })}
        {tool("Remove link", () => editor.chain().focus().unsetLink().run())}
        {tool("Image", () => setShowImage((v) => !v))}
        {tool("Undo", () => editor.chain().focus().undo().run())}
        {tool("Redo", () => editor.chain().focus().redo().run())}
      </div>
      <EditorContent editor={editor} />
      {showImage && (
        <div className="array-item">
          <ImageField
            value={image}
            onChange={setImage}
            onBusy={onBusy}
            label="Body image"
          />
          <button
            type="button"
            disabled={!image}
            onClick={() => {
              editor
                .chain()
                .focus()
                .setImage({
                  src: image,
                  alt: window.prompt("Image description", "") || "",
                })
                .run();
              setImage("");
              setShowImage(false);
            }}
          >
            Insert image
          </button>
        </div>
      )}
    </div>
  );
}
function Editor({ post, onDirty, onSaved }) {
  const [data, setData] = useState(() =>
    post ? Object.fromEntries(editable.map((k) => [k, post[k]])) : empty(),
  );
  const [baseline, setBaseline] = useState(() => JSON.stringify(data));
  const [id, setId] = useState(post?.id);
  const [revision, setRevision] = useState(post?.revision || 0);
  const [busy, setBusy] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const dirty = JSON.stringify(data) !== baseline;
  useEffect(() => {
    onDirty(dirty);
    return () => onDirty(false);
  }, [dirty, onDirty]);
  const history = useQuery({
    queryKey: ["post-history", id, revision],
    queryFn: () => getPostHistory(id),
    enabled: !!id,
  });
  const field = (key, label, required = false, multiline = false) => (
    <div className="field">
      <label htmlFor={`post-${key}`}>{label}</label>
      {multiline ? (
        <textarea
          id={`post-${key}`}
          required={required}
          pattern={key === "slug" ? "[a-z0-9]+(-[a-z0-9]+)*" : undefined}
          maxLength={
            key === "slug"
              ? 120
              : key === "title"
                ? 200
                : key === "category"
                  ? 80
                  : undefined
          }
          value={data[key] ?? ""}
          onChange={(e) => change(key, e.target.value)}
        />
      ) : (
        <input
          id={`post-${key}`}
          required={required}
          pattern={key === "slug" ? "[a-z0-9]+(-[a-z0-9]+)*" : undefined}
          maxLength={
            key === "slug"
              ? 120
              : key === "title"
                ? 200
                : key === "category"
                  ? 80
                  : undefined
          }
          value={data[key] ?? ""}
          onChange={(e) => {
            change(key, e.target.value);
            if (
              key === "title" &&
              !id &&
              (!data.slug ||
                data.slug ===
                  data.title
                    .toLowerCase()
                    .normalize("NFKD")
                    .replace(/[^a-z0-9]+/g, "-")
                    .replace(/^-|-$/g, ""))
            )
              setData((d) => ({
                ...d,
                slug: e.target.value
                  .toLowerCase()
                  .normalize("NFKD")
                  .replace(/[^a-z0-9]+/g, "-")
                  .replace(/^-|-$/g, ""),
              }));
          }}
        />
      )}
    </div>
  );
  const change = (k, v) => setData((d) => ({ ...d, [k]: v }));
  return (
    <form
      onSubmit={async (e) => {
        e.preventDefault();
        setBusy(true);
        setError("");
        setMessage("");
        try {
          const result = await savePost(data, id, revision);
          setId(result.id);
          setRevision(result.revision);
          setBaseline(JSON.stringify(data));
          setMessage(
            "Saved to database. Use Publish at the top when all changes are ready.",
          );
          onSaved();
        } catch (err) {
          setError(err.message);
        } finally {
          setBusy(false);
        }
      }}
    >
      <h2>{id ? "Edit publication" : "New publication"}</h2>
      <p className="hint">
        {id ? `Revision ${revision}` : "Start a draft"} · /{routes[data.kind]}/
        {data.slug || "your-slug"}
      </p>
      <fieldset disabled={busy || uploading}>
        <label htmlFor="post-kind">Type</label>
        <select
          id="post-kind"
          value={data.kind}
          onChange={(e) => change("kind", e.target.value)}
        >
          {Object.entries(types).map(([v, l]) => (
            <option key={v} value={v}>
              {l}
            </option>
          ))}
        </select>
        {field("title", "Title", true)}
        {field("slug", "URL slug", true)}
        <small className="hint">
          Lowercase words separated by hyphens. Changing a published slug
          changes its URL.
        </small>
        {field("excerpt", "Summary / card excerpt", false, true)}
        <ImageField
          value={data.image}
          onChange={(v) => change("image", v)}
          label="Featured image"
          onBusy={setUploading}
        />
        {field("image_alt", "Image description")}
        {field("author", "Author")}
        {field("author_role", "Author role")}
        {field("category", "Category (optional)")}
        <small className="hint">
          Use one category to group related posts, such as Road Transportation
          or HSSE. Tags can describe multiple topics.
        </small>
        <TagInput value={data.tags || []} onChange={(v) => change("tags", v)} />
        <label htmlFor="post-date">Publication date</label>
        <input
          id="post-date"
          type="date"
          required
          max={new Date().toISOString().slice(0, 10)}
          value={data.published_at.slice(0, 10)}
          onChange={(e) => {
            if (e.target.value)
              change("published_at", e.target.value + "T00:00:00.000Z");
          }}
        />
        <p>Body</p>
        <RichEditor
          value={data.content}
          onChange={(v) => change("content", v)}
          onBusy={setUploading}
        />
        <details>
          <summary>Search engine settings</summary>
          {field("seo_title", "SEO title (optional)")}
          {field("seo_description", "SEO description (optional)", false, true)}
        </details>
        <label htmlFor="post-status">Publication status</label>
        <select
          id="post-status"
          value={data.status}
          onChange={(e) => change("status", e.target.value)}
        >
          <option value="draft">Draft (hidden)</option>
          <option value="published">Published</option>
        </select>
        <p className="hint">
          Draft keeps this item hidden; Published includes it in the next
          website build. Save here, then use Publish at the top to update the
          website.
        </p>
      </fieldset>
      {error && (
        <p role="alert" className="error">
          {error}
        </p>
      )}
      {message && (
        <p role="status" className="success">
          {message}
        </p>
      )}
      <div className="editor-actions">
        <span>{dirty ? "Unsaved changes" : "Saved"}</span>
        {id && data.status === "published" && (
          <a
            href={`${WEBSITE}/${routes[data.kind]}/${data.slug}`}
            target="_blank"
            rel="noreferrer"
          >
            View on website
          </a>
        )}
        <button disabled={busy || uploading || (!dirty && !!id)}>
          {busy ? "Saving…" : "Save"}
        </button>
      </div>
      {id && (
        <details>
          <summary>Revision history</summary>
          {history.error && <p role="alert">{history.error.message}</p>}
          {history.data?.map((h) => (
            <div key={h.id} className="history-card">
              <strong>Revision {h.revision}</strong> · {h.actor} ·{" "}
              {new Date(h.at).toLocaleString()}
              <details>
                <summary>Changes</summary>
                <pre>{JSON.stringify(h.changes, null, 2)}</pre>
              </details>
            </div>
          ))}
        </details>
      )}
    </form>
  );
}
export default function Publications({ onDirty }) {
  const cache = useQueryClient();
  const posts = useQuery({ queryKey: ["posts"], queryFn: getPosts });
  const [selected, setSelected] = useState(null);
  const [serial, setSerial] = useState(0);
  const [dirty, setDirty] = useState(false);
  const select = (p) => {
    if (dirty && !window.confirm("Discard unsaved publication changes?"))
      return;
    setSelected(p);
    setSerial((s) => s + 1);
    setDirty(false);
  };
  // Keep the callback stable so editor dirty tracking does not rerender in a loop.
  const [dirtyCallback] = useState(() => (v) => {
    setDirty(v);
    onDirty(v);
  });
  return (
    <>
      <h1>Publications</h1>
      <p>Create blogs, case studies and articles.</p>
      <button type="button" onClick={() => select(null)}>
        New publication
      </button>
      {posts.error && (
        <p className="error" role="alert">
          {posts.error.message}
        </p>
      )}
      <div className="posts-layout">
        <div className="post-list">
          {posts.isPending && <p>Loading…</p>}
          {posts.data?.map((p) => (
            <button
              type="button"
              className="secondary"
              key={p.id}
              onClick={() => select(p)}
            >
              <strong>{p.title}</strong>
              <small>
                {types[p.kind]} · {p.status}
              </small>
            </button>
          ))}
        </div>
        <Editor
          key={serial}
          post={selected}
          onDirty={dirtyCallback}
          onSaved={() => cache.invalidateQueries({ queryKey: ["posts"] })}
        />
      </div>
    </>
  );
}
