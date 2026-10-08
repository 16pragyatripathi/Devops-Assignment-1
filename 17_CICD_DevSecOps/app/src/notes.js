// In-memory notice board used by the Session 17 demo API.
// All input is validated here, so the HTTP layer never trusts raw user data.

const MAX_TITLE = 80;
const MAX_BODY = 500;

function createStore() {
  const notes = [];
  let nextId = 1;

  function validate(input) {
    if (!input || typeof input !== 'object') throw new TypeError('note must be a JSON object');
    const { title, body } = input;
    if (typeof title !== 'string' || title.trim() === '') throw new TypeError('title is required');
    if (typeof body !== 'string') throw new TypeError('body must be a string');
    if (title.length > MAX_TITLE) throw new RangeError(`title is longer than ${MAX_TITLE} characters`);
    if (body.length > MAX_BODY) throw new RangeError(`body is longer than ${MAX_BODY} characters`);
    return { title: title.trim(), body };
  }

  return {
    list: () => notes.map((n) => ({ ...n })),
    get: (id) => notes.find((n) => n.id === id) || null,
    add(input) {
      const clean = validate(input);
      const note = { id: nextId++, ...clean, createdAt: new Date().toISOString() };
      notes.push(note);
      return { ...note };
    },
    remove(id) {
      const i = notes.findIndex((n) => n.id === id);
      if (i === -1) return false;
      notes.splice(i, 1);
      return true;
    },
  };
}

module.exports = { createStore, MAX_TITLE, MAX_BODY };
