import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const html = readFileSync(new URL('../web/admin.html', import.meta.url), 'utf8');
const source = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map((match) => match[1]).find((script) => script.includes('const API_BASE'));
const deferred = () => {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
};

function harness(fetchImpl) {
  const elements = new Map();
  const timers = new Map();
  const storage = new Map([['hm_admin_key', JSON.stringify({ key: 'test-key', savedAt: Date.now() })]]);
  let timerId = 0;
  const getElement = (id) => {
    if (!elements.has(id)) elements.set(id, {
      id, hidden: false, textContent: '', innerHTML: '', value: '', open: false,
      classList: { add() {}, remove() {}, toggle() {} },
      querySelectorAll: () => [], replaceChildren() {}, focus() {},
      setSelectionRange() {}, setAttribute() {}, removeAttribute() {},
      showModal() { this.open = true; }, close() { this.open = false; },
      querySelector: () => null,
      animate: () => ({}),
    });
    return elements.get(id);
  };
  const context = vm.createContext({
    fetch: fetchImpl, AbortController, console,
    setTimeout: (callback, ms) => { timers.set(++timerId, { callback, ms }); return timerId; },
    clearTimeout: (id) => timers.delete(id),
    sessionStorage: {
      getItem: (key) => storage.get(key) ?? null,
      setItem: (key, value) => storage.set(key, value),
      removeItem: (key) => storage.delete(key),
    },
    document: { getElementById: getElement, querySelectorAll: () => [], addEventListener() {} },
    window: { matchMedia: () => ({ matches: false }) },
    requestAnimationFrame: (callback) => callback(),
  });
  // Keep production request/state logic intact while observing which view it renders.
  const exports = `
    const rendered = [];
    renderReportsView = () => rendered.push('reports');
    renderReviewsView = () => rendered.push('reviews');
    renderNoticesView = () => rendered.push('notices');
    globalThis.admin = { api, switchView, loadReports, handleError, rendered,
      reportCounts,
      openUserActivity, openDeleteReportModal, doDeleteReport,
      setReports: (reports) => { allReports = reports; },
      invalidateAdminSession,
      newSession() {
        adminSessionGeneration += 1;
        sessionStorage.setItem(KEY_STORAGE, JSON.stringify({ key: 'new-key', savedAt: Date.now() }));
      },
      state: () => ({ allReports, reportsLoaded, currentView, adminSessionGeneration }),
    };
  `;
  vm.runInContext(source.replace(/\n  boot\(\);\n\}\)\(\);\s*$/, `\n${exports}\n})();`), context);
  assert.ok(context.admin, 'test harness must export the actual admin script');
  return { admin: context.admin, timers, storage, elements };
}

test('slow report response cannot replace a newly selected view or populate its cache', async () => {
  const reports = deferred();
  const { admin } = harness(async () => ({ ok: true, status: 200, json: () => reports.promise }));
  const pending = admin.switchView('reports');
  await admin.switchView('notices');
  reports.resolve([{ id: 'old-report' }]);
  await pending;
  assert.deepEqual([...admin.rendered], ['notices']);
  assert.equal(admin.state().reportsLoaded, false);
  assert.equal(admin.state().allReports.length, 0);
});

test('legacy report count closes the gap between status tabs and total', () => {
  const { admin } = harness(async () => ({ ok: true, status: 200, json: async () => [] }));
  admin.setReports([
    { status: 'PENDING' }, { status: 'APPROVED' }, { status: 'REJECTED' },
    { status: null }, {}, { status: '__proto__' },
  ]);
  const counts = admin.reportCounts();
  assert.equal(counts.LEGACY, 3);
  assert.equal(Object.values(counts).reduce((total, count) => total + count, 0), 6);
});

test('overlapping refreshes retain only the latest response', async () => {
  const first = deferred(), second = deferred();
  let calls = 0;
  const { admin } = harness(async () => ({ ok: true, status: 200,
    json: () => (++calls === 1 ? first.promise : second.promise) }));
  const a = admin.loadReports();
  const b = admin.loadReports();
  await Promise.resolve();
  second.resolve([{ id: 'new' }]);
  await b;
  first.resolve([{ id: 'old' }]);
  await a;
  assert.equal(admin.state().allReports[0].id, 'new');
  assert.equal(admin.rendered.length, 1);
});

test('request deadline and abort remain active while the response body is downloading', async () => {
  const body = deferred();
  const started = deferred();
  const { admin, timers } = harness(async (_url, options) => ({ ok: true, status: 200,
    json: () => {
      options.signal.addEventListener('abort', () => body.reject(
        new DOMException('aborted', 'AbortError')), { once: true });
      started.resolve();
      return body.promise;
    } }));
  const pending = admin.api('/slow-body');
  const rejected = assert.rejects(pending, (error) => error.code === 408);
  await started.promise;
  const deadline = [...timers.values()].find((timer) => timer.ms === 45000);
  assert.ok(deadline, 'deadline must survive receipt of headers');
  deadline.callback();
  await rejected;
  assert.equal(timers.size, 0);
});

test('old body arriving after logout cannot refill data or invalidate a new login', async () => {
  const body = deferred();
  const started = deferred();
  const { admin, storage } = harness(async () => ({ ok: true, status: 200,
    json: () => { started.resolve(); return body.promise; } }));
  const pending = admin.api('/old-session');
  await started.promise;
  admin.invalidateAdminSession();
  admin.newSession();
  body.resolve({ sensitive: 'old response' });
  await assert.rejects(pending, (error) => {
    assert.equal(error.code, 'STALE_REQUEST');
    admin.handleError(error);
    return true;
  });
  assert.equal(JSON.parse(storage.get('hm_admin_key')).key, 'new-key');
});

test('failed previous view response cannot overwrite current page with an error', async () => {
  const response = deferred();
  const { admin, elements } = harness(() => response.promise);
  const pending = admin.switchView('reports');
  await admin.switchView('notices');
  const currentHtml = elements.get('content').innerHTML;
  response.reject(new Error('old network error'));
  await pending;
  assert.equal(elements.get('content').innerHTML, currentHtml);
  assert.deepEqual([...admin.rendered], ['notices']);
});

test('switching user activity modals cannot show the previous user response', async () => {
  const first = deferred(), second = deferred();
  const { admin, elements } = harness(async (url) => ({ ok: true, status: 200,
    json: () => url.includes('/first/') ? first.promise : second.promise }));
  const a = admin.openUserActivity('first', 'First');
  const b = admin.openUserActivity('second', 'Second');
  second.resolve({ reports: 2 });
  await b;
  first.resolve({ reports: 99 });
  await a;
  assert.equal(elements.get('userModalName').textContent, 'Second');
  assert.ok(!elements.get('userModalActs').innerHTML.includes('99'));
  assert.match(elements.get('userModalSub').textContent, /second/);
});

test('pending delete updates its original row if another report modal is opened', async () => {
  const response = deferred();
  const { admin, elements } = harness(async (url) => {
    assert.ok(url.endsWith('/first'));
    return { ok: true, status: 200, json: () => response.promise };
  });
  admin.setReports([{ id: 'first' }, { id: 'second' }]);
  admin.openDeleteReportModal('first', 'First');
  const pending = admin.doDeleteReport();
  admin.openDeleteReportModal('second', 'Second');
  response.resolve({ deletedImages: 0 });
  await pending;
  assert.deepEqual(admin.state().allReports.map((item) => item.id), ['second']);
  assert.equal(elements.get('deleteReportModal').open, true);
});
