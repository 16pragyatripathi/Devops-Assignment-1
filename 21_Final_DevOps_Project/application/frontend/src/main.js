import "./style.css";

const FRONTEND_VERSION = "1.0.0";
const $ = (id) => document.getElementById(id);

async function api(path, options = {}) {
  const res = await fetch(path, { headers: { "Content-Type": "application/json" }, ...options });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.detail || `${res.status} ${res.statusText}`);
  }
  return res.status === 204 ? null : res.json();
}

function showError(msg) {
  $("error").textContent = msg;
  $("error").hidden = !msg;
}

async function refresh() {
  try {
    const category = $("filter").value;
    const [books, stats] = await Promise.all([
      api(`/api/books${category ? `?category=${category}` : ""}`),
      api("/api/books/stats"),
    ]);
    $("k-titles").textContent = stats.titles;
    $("k-total").textContent = stats.total_copies;
    $("k-available").textContent = stats.available_copies;
    $("k-issued").textContent = stats.issued_copies;
    $("books").innerHTML = books.length
      ? books.map((b) => `
        <tr>
          <td>${b.id}</td><td>${escapeHtml(b.title)}</td><td>${escapeHtml(b.author)}</td>
          <td><span class="tag ${b.category.toLowerCase()}">${b.category}</span></td>
          <td>${b.available_copies} / ${b.total_copies}</td>
          <td class="actions">
            <button data-act="issue" data-id="${b.id}" ${b.available_copies === 0 ? "disabled" : ""}>Issue</button>
            <button data-act="return" data-id="${b.id}" ${b.available_copies === b.total_copies ? "disabled" : ""}>Return</button>
            <button data-act="delete" data-id="${b.id}" class="danger">Delete</button>
          </td>
        </tr>`).join("")
      : `<tr><td colspan="6">No books yet - add one above.</td></tr>`;
    showError("");
  } catch (err) {
    showError(`Could not reach the API: ${err.message}`);
  }
}

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

$("add-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const data = Object.fromEntries(new FormData(e.target));
  data.total_copies = Number(data.total_copies);
  try {
    await api("/api/books", { method: "POST", body: JSON.stringify(data) });
    e.target.reset();
    refresh();
  } catch (err) {
    showError(err.message);
  }
});

$("books").addEventListener("click", async (e) => {
  const btn = e.target.closest("button[data-act]");
  if (!btn) return;
  const { act, id } = btn.dataset;
  try {
    if (act === "delete") await api(`/api/books/${id}`, { method: "DELETE" });
    else await api(`/api/books/${id}/${act}`, { method: "POST" });
    refresh();
  } catch (err) {
    showError(err.message);
  }
});

$("filter").addEventListener("change", refresh);

$("version").textContent = `frontend v${FRONTEND_VERSION}`;
api("/api/info")
  .then((info) => ($("backend-info").textContent = `backend: ${info.service} v${info.version} (pod ${info.hostname})`))
  .catch(() => ($("backend-info").textContent = "backend: unreachable"));

refresh();
