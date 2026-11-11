import { StrictMode, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  QueryClient,
  QueryClientProvider,
  useQuery,
  useMutation,
  useQueryClient,
} from "@tanstack/react-query";
import { motion, useReducedMotion } from "framer-motion";
import {
  supabase,
  signIn,
  signOut,
  getAdmin,
  getPages,
  getPage,
  publishSection,
  getHistory,
} from "./api";
import Fields, { label } from "./Fields";
import "./styles.css";
const client = new QueryClient({
  defaultOptions: { queries: { retry: false, refetchOnWindowFocus: false } },
});
function Message({ error }) {
  return error ? (
    <p role="alert" className="error">
      {error.message}
    </p>
  ) : null;
}
function Loading() {
  const reduced = useReducedMotion();
  return (
    <div role="status" className="loading">
      <motion.span
        animate={reduced ? {} : { opacity: [0.3, 1, 0.3] }}
        transition={{ repeat: Infinity, duration: 1 }}
      >
        Loading…
      </motion.span>
    </div>
  );
}
function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const login = useMutation({
    mutationFn: () => signIn(email, password),
    onSuccess: () => setPassword(""),
  });
  return (
    <main className="login-shell">
      <form
        className="login-card"
        onSubmit={(e) => {
          e.preventDefault();
          login.mutate();
        }}
      >
        <span className="eyebrow">LMI · CONTENT PORTAL</span>
        <h1>Admin sign in</h1>
        <p>Manage your website content, one section at a time.</p>
        <label htmlFor="email">Admin email</label>
        <input
          id="email"
          type="email"
          autoComplete="username"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <label htmlFor="password">Password</label>
        <input
          id="password"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
        <Message error={login.error} />
        <button disabled={login.isPending} type="submit">
          {login.isPending ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </main>
  );
}
function SectionEditor({
  entry,
  template,
  pageId,
  sectionKey,
  onDirty,
  onPublished,
}) {
  const cache = useQueryClient();
  const [data, setData] = useState(() => structuredClone(entry.data));
  const [enabled, setEnabled] = useState(entry.enabled);
  const [published, setPublished] = useState("");
  const [revision, setRevision] = useState(entry.revision);
  const dirty =
    JSON.stringify(data) !== JSON.stringify(entry.data) ||
    enabled !== entry.enabled;
  useEffect(() => {
    onDirty(dirty);
    return () => onDirty(false);
  }, [dirty, onDirty]);
  const publish = useMutation({
    mutationFn: () =>
      publishSection(pageId, sectionKey, data, enabled, revision),
    onSuccess: async (result) => {
      setRevision(result.revision);
      onPublished("Section published successfully.");
      setPublished(
        result.unchanged
          ? "No changes to publish."
          : "Section published successfully.",
      );
      await cache.invalidateQueries({ queryKey: ["admin-page", pageId] });
      await cache.invalidateQueries({ queryKey: ["history"] });
    },
  });
  function cancel() {
    setData(structuredClone(entry.data));
    setEnabled(entry.enabled);
    setRevision(entry.revision);
    publish.reset();
    setPublished("");
  }
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        setPublished("");
        publish.mutate();
      }}
    >
      <div className="editor-heading">
        <div>
          <span className="eyebrow">{label(sectionKey)}</span>
          <h2>
            {template.heading
              ? Array.isArray(template.heading)
                ? template.heading.join(" ")
                : template.heading
              : label(sectionKey)}
          </h2>
          <p className="hint">
            Revision {revision} · Layout and section order are fixed.
          </p>
        </div>
        <label className="checkbox visibility">
          <input
            type="checkbox"
            checked={enabled}
            disabled={publish.isPending}
            onChange={(e) => setEnabled(e.target.checked)}
          />
          Show section
        </label>
      </div>
      <fieldset disabled={publish.isPending} className="content-fields">
        <Fields
          template={template}
          value={data}
          onChange={(next) => {
            setData(next);
            setPublished("");
          }}
          name="Section content"
        />
      </fieldset>
      <Message error={publish.error} />
      {published && (
        <p className="success" role="status">
          {published}
        </p>
      )}
      <div className="editor-actions">
        <span className="hint">
          {dirty ? "Unpublished changes" : "All changes published"}
        </span>
        <button
          type="button"
          className="secondary"
          onClick={cancel}
          disabled={publish.isPending || !dirty}
        >
          Cancel
        </button>
        <button type="submit" disabled={publish.isPending || !dirty}>
          {publish.isPending ? "Publishing…" : "Publish"}
        </button>
      </div>
    </form>
  );
}
function History({ pages }) {
  const [page, setPage] = useState(1);
  const [pageId, setPageId] = useState("");
  const result = useQuery({
    queryKey: ["history", page, pageId],
    queryFn: ({ signal }) => getHistory(page, pageId, signal),
  });
  return (
    <>
      <span className="eyebrow">AUDIT LOG</span>
      <h1>Publication history</h1>
      <p>
        Each successful publication records the administrator, section, and
        changed values.
      </p>
      <label htmlFor="history-filter">Filter by page</label>
      <select
        id="history-filter"
        value={pageId}
        onChange={(e) => {
          setPageId(e.target.value);
          setPage(1);
        }}
      >
        <option value="">All pages</option>
        {pages.map((p) => (
          <option key={p.id} value={p.id}>
            {p.title}
          </option>
        ))}
      </select>
      <Message error={result.error} />
      {result.isPending ? (
        <Loading />
      ) : (
        <>
          <p className="hint">{result.data?.total ?? 0} publications</p>
          {result.data?.items.map((event) => (
            <article className="history-card" key={event._id}>
              <div className="history-heading">
                <h2>
                  {pages.find((p) => p.id === event.pageId)?.title ??
                    event.pageId}{" "}
                  · {label(event.section)}
                </h2>
                <span className="badge">Revision {event.revision}</span>
              </div>
              <p className="hint">
                {new Date(event.at).toLocaleString()} · {event.actor}
              </p>
              <details>
                <summary>{event.changes.length} changed fields</summary>
                <div className="table-scroll">
                  <table>
                    <thead>
                      <tr>
                        <th>Field</th>
                        <th>Before</th>
                        <th>After</th>
                      </tr>
                    </thead>
                    <tbody>
                      {event.changes.map((change, i) => (
                        <tr key={i}>
                          <th>{change.field}</th>
                          <td>
                            <pre>{JSON.stringify(change.before, null, 2)}</pre>
                          </td>
                          <td>
                            <pre>{JSON.stringify(change.after, null, 2)}</pre>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </details>
            </article>
          ))}
          {!result.data?.items.length && !result.error && (
            <p>No publications yet.</p>
          )}
          <div className="pagination">
            <button
              className="secondary"
              disabled={page === 1}
              onClick={() => setPage((p) => p - 1)}
            >
              Previous
            </button>
            <span>Page {page}</span>
            <button
              className="secondary"
              disabled={page * 20 >= (result.data?.total ?? 0)}
              onClick={() => setPage((p) => p + 1)}
            >
              Next
            </button>
          </div>
        </>
      )}
    </>
  );
}
function Dashboard() {
  const [view, setView] = useState("content");
  const [pageId, setPageId] = useState("home");
  const [sectionKey, setSectionKey] = useState("");
  const [dirty, setDirty] = useState(false);
  const [notice, setNotice] = useState("");
  const me = useQuery({
    queryKey: ["me"],
    queryFn: () => getAdmin(),
  });
  const pages = useQuery({
    queryKey: ["admin-pages"],
    queryFn: ({ signal }) => getPages(signal),
    enabled: me.isSuccess,
  });
  const page = useQuery({
    queryKey: ["admin-page", pageId],
    queryFn: ({ signal }) => getPage(pageId, signal),
    enabled: me.isSuccess && view === "content",
  });
  useEffect(() => {
    const handler = (e) => {
      if (dirty) {
        e.preventDefault();
        e.returnValue = "";
      }
    };
    window.addEventListener("beforeunload", handler);
    return () => window.removeEventListener("beforeunload", handler);
  }, [dirty]);
  const leave = () => !dirty || window.confirm("Discard unpublished changes?");
  const sectionKeys = (
    pages.data?.find((item) => item.id === pageId)?.sections ??
    Object.keys(page.data?.template ?? {})
  ).filter((item) => page.data?.template[item]);
  const key =
    sectionKey && page.data?.template[sectionKey] ? sectionKey : sectionKeys[0];
  async function logout() {
    if (!leave()) return;
    try {
      await signOut();
    } catch (error) {
      window.alert(error.message);
    }
  }
  return (
    <div className="dashboard">
      <aside>
        <div className="brand">
          LMI<span>CONTENT PORTAL</span>
        </div>
        <nav aria-label="Portal">
          <button
            className={view === "content" ? "nav-button active" : "nav-button"}
            onClick={() => {
              if (leave()) {
                setView("content");
                setDirty(false);
              }
            }}
          >
            Website content
          </button>
          <button
            className={view === "history" ? "nav-button active" : "nav-button"}
            onClick={() => {
              if (leave()) {
                setView("history");
                setDirty(false);
              }
            }}
          >
            History
          </button>
        </nav>
        <div className="admin-account">
          <span>Signed in as admin</span>
          <button className="secondary" onClick={logout}>
            Sign out
          </button>
        </div>
      </aside>
      <main className="workspace">
        <header>
          <span className="eyebrow">LOGISTICS MANAGEMENT INTERNATIONAL</span>
          <span className="badge">Administrator</span>
        </header>
        <Message error={me.error ?? pages.error} />
        {me.isError || pages.isError ? null : pages.isPending ? (
          <Loading />
        ) : view === "history" ? (
          <History pages={pages.data ?? []} />
        ) : (
          <>
            <h1>Website content</h1>
            {notice && (
              <p className="success" role="status">
                {notice}
              </p>
            )}
            <p>
              Edit existing content or hide a section. Publish applies to the
              selected section only.
            </p>
            <div className="selectors">
              <div>
                <label htmlFor="page-select">Page</label>
                <select
                  id="page-select"
                  value={pageId}
                  onChange={(e) => {
                    if (leave()) {
                      setPageId(e.target.value);
                      setSectionKey("");
                      setDirty(false);
                    }
                  }}
                >
                  {pages.data?.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.title} · {p.route}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label htmlFor="section-select">Section</label>
                <select
                  id="section-select"
                  value={key ?? ""}
                  onChange={(e) => {
                    if (leave()) {
                      setSectionKey(e.target.value);
                      setDirty(false);
                    }
                  }}
                >
                  {sectionKeys.map((k) => (
                    <option key={k} value={k}>
                      {label(k)}
                      {page.data?.sections[k]?.enabled === false
                        ? " · Hidden"
                        : ""}
                    </option>
                  ))}
                </select>
              </div>
            </div>
            <Message error={page.error} />
            {page.isPending ? (
              <Loading />
            ) : page.data && key ? (
              <SectionEditor
                key={`${pageId}:${key}:${page.data.sections[key]?.revision}`}
                pageId={pageId}
                sectionKey={key}
                entry={
                  page.data.sections[key] ?? {
                    data: {},
                    enabled: false,
                    revision: 0,
                  }
                }
                template={page.data.template[key]}
                onDirty={setDirty}
                onPublished={setNotice}
              />
            ) : null}
          </>
        )}
      </main>
    </div>
  );
}
function App() {
  const [session, setSession] = useState(undefined);
  useEffect(() => {
    if (!supabase) {
      setSession(null);
      return;
    }
    let active = true;
    supabase.auth.getSession().then(({ data, error }) => {
      if (active) setSession(error ? null : data.session);
    });
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, next) => {
      if (event === "SIGNED_OUT") client.clear();
      if (active) setSession(next);
    });
    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);
  if (session === undefined) return <Loading />;
  return session ? <Dashboard key={session.user.id} /> : <Login />;
}
createRoot(document.getElementById("root")).render(
  <StrictMode>
    <QueryClientProvider client={client}>
      <App />
    </QueryClientProvider>
  </StrictMode>,
);
