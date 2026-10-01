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

test('report deletion warning distinguishes public new stores from information reports', () => {
  const modal = html.match(/<dialog[^>]+id="deleteReportModal"[\s\S]*?<\/dialog>/)?.[0];
  assert.ok(modal, 'actual report deletion dialog must exist');
  assert.match(modal, /승인·공개된 신규 매장 제보는 지도에서도 제거됩니다/);
  assert.match(modal, /대상 매장 원본과 승인된 수정 기록은 유지됩니다/);
  assert.match(modal, /삭제한 제보와 첨부 사진은 복구할 수 없습니다/);
  assert.doesNotMatch(modal, /승인된 제보는 지도에서도 즉시 제거/);
});

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
      fmtPrice, reportCard, receiptCard, inquiryOriginal, resolutionSummary,
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

test('actual admin price renderer preserves alternatives and ranges', () => {
  const { admin } = harness(async () => ({ ok: true, status: 200, json: async () => [] }));
  assert.equal(admin.fmtPrice('3,000 / 3,500'), '3,000 / 3,500원');
  assert.equal(admin.fmtPrice('3000~3500원'), '3,000 ~ 3,500원');
  assert.equal(admin.fmtPrice('0'), '0원 · 무료 여부 확인 필요');
  assert.equal(admin.fmtPrice('<script>'), '&lt;script&gt;');
});

test('actual report card includes type, original description, and explicit free flag', () => {
  const { admin } = harness(async () => ({ ok: true, status: 200, json: async () => [] }));
  const card = admin.reportCard({id:'info',status:'PENDING',reportType:'STORE_INFO',changeType:'other',description:'<img> 검토해주세요',menu1:'무료 서비스',price1:'0',free1:true});
  assert.match(card, /매장 정보 신고/);
  assert.match(card, /other/);
  assert.match(card, /&lt;img&gt; 검토해주세요/);
  assert.match(card, /무료/);
});

test('processed receipt renderer never offers a deleted original link', () => {
  const { admin } = harness(async () => ({ ok: true, status: 200, json: async () => [] }));
  const card = admin.receiptCard({id:'receipt',status:'REJECTED',imageCleanupStatus:'DELETED',imageUrls:['https://res.cloudinary.com/example/image/upload/receipt.jpg']});
  assert.match(card, /심사 후 원본 삭제/);
  assert.doesNotMatch(card, /data-open-image/);
  const unknown = admin.receiptCard({status:'APPROVED',imageCleanupStatus:'SYNC_PENDING',imageUrls:[]});
  assert.match(unknown, /확인 필요/);
});

test('inquiry modal renders escaped full original and safe attachment', () => {
  const { admin } = harness(async () => ({ ok: true, status: 200, json: async () => [] }));
  const original = admin.inquiryOriginal({content:'긴 원문\n<script>전체 내용</script>',imageUrls:['javascript:alert(1)']});
  assert.match(original, /긴 원문\n&lt;script&gt;전체 내용&lt;\/script&gt;/);
  assert.doesNotMatch(original, /javascript:/);
});

test('actual approval confirmation states before, after, and reason', () => {
  const { admin } = harness(async () => ({ ok: true, status: 200, json: async () => [] }));
  const text = admin.resolutionSummary('테스트 매장', 'PRICE', {menu2:'칼국수',price2:'5000',free2:false}, {menuSlot:2,menu:'무료 칼국수',price:'0',free:true}, '사업자가 무료 제공 확인');
  assert.match(text, /칼국수 5,000원/);
  assert.match(text, /→ 무료 칼국수 무료/);
  assert.match(text, /사업자가 무료 제공 확인/);
  assert.match(admin.resolutionSummary('테스트', 'NO_CHANGE', {}, {}, '변경 근거 없음'), /매장 정보 수정 없음/);
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
