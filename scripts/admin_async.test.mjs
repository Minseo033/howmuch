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
// Let every pending microtask and promise continuation in the admin script run.
const flush = () => new Promise((resolve) => setImmediate(resolve));

test('report deletion warning distinguishes public new stores from information reports', () => {
  const modal = html.match(/<dialog[^>]+id="deleteReportModal"[\s\S]*?<\/dialog>/)?.[0];
  assert.ok(modal, 'actual report deletion dialog must exist');
  assert.match(modal, /승인·공개된 신규 매장 제보는 지도에서도 제거됩니다/);
  assert.match(modal, /대상 매장 원본과 승인된 수정 기록은 유지됩니다/);
  assert.match(modal, /삭제한 제보와 첨부 사진은 복구할 수 없습니다/);
  assert.doesNotMatch(modal, /승인된 제보는 지도에서도 즉시 제거/);
});

function harness(fetchImpl, { crypto } = {}) {
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
      animate: () => ({ cancel() {} }),
    });
    return elements.get(id);
  };
  const context = vm.createContext({
    fetch: fetchImpl, AbortController, console,
    ...(crypto ? { crypto } : {}),
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
    const original = { renderReportsView, renderReviewsView, renderNoticesView };
    const rendered = [];
    renderReportsView = () => rendered.push('reports');
    renderReviewsView = () => rendered.push('reviews');
    renderNoticesView = () => rendered.push('notices');
    globalThis.admin = { api, switchView, loadReports, handleError, rendered, original,
      reportCounts,
      fmtPrice, reportCard, receiptCard, inquiryOriginal, resolutionSummary,
      openUserActivity, openDeleteReportModal, doDeleteReport,
      doSendNotification, doPublishNotice, doApprove,
      openReportResolution, approveReportResolution,
      renderResolutionFields, renderDashboard, renderCommentsView, doDeleteComment,
      openRejectModal, doReject, openAnswerInquiryModal, doAnswerInquiry,
      selectNotificationTarget,
      setReports: (reports) => { allReports = reports; },
      setReviews: (reviews) => { allReviews = reviews; },
      setComments: (comments) => { allComments = comments; },
      setDeleteComment: (id) => { deleteCommentId = id; },
      setInquiries: (inquiries) => { allInquiries = inquiries; },
      setUsers: (members) => { users = members; },
      setOverview: (value) => { overview = value; },
      setView: (view) => { currentView = view; },
      invalidateAdminSession,
      newSession() {
        adminSessionGeneration += 1;
        sessionStorage.setItem(KEY_STORAGE, JSON.stringify({ key: 'new-key', savedAt: Date.now() }));
      },
      state: () => ({ allReports, reportsLoaded, currentView, adminSessionGeneration, allComments }),
    };
  `;
  vm.runInContext(source.replace(/\n  boot\(\);\n\}\)\(\);\s*$/, `\n${exports}\n})();`), context);
  assert.ok(context.admin, 'test harness must export the actual admin script');
  return { admin: context.admin, timers, storage, elements, el: getElement };
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
  assert.match(card, /유형: 기타/);
  assert.doesNotMatch(card, /other/);
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

test('logout and session expiry clear the administrator key typed into the login field', () => {
  const { el, timers, storage } = harness(() => new Promise(() => {}));
  el('keyInput').value = '  typed-secret  ';
  el('loginBtn').onclick();
  assert.equal(el('keyInput').value, '', 'a submitted key must not stay in the hidden login field');
  assert.equal(JSON.parse(storage.get('hm_admin_key')).key, 'typed-secret');

  el('keyInput').value = 'autofilled-secret';
  el('logoutBtn').onclick();
  assert.equal(el('keyInput').value, '', 'logout must not leave a one-click re-login');
  assert.equal(storage.has('hm_admin_key'), false);

  el('keyInput').value = 'second-secret';
  el('loginBtn').onclick();
  el('keyInput').value = 'left-behind';
  const expiry = [...timers.values()].find((timer) => timer.ms > 29 * 60 * 1000);
  assert.ok(expiry, 'the 30-minute session expiry must be scheduled');
  expiry.callback();
  assert.equal(el('keyInput').value, '', 'expiry must clear the login field too');
  assert.match(el('loginError').textContent, /만료/);
});

test('location correction blocks coordinates outside Korea and warns before a distant move', async () => {
  let calls = 0;
  const { admin, el } = harness(async () => { calls += 1; return { ok: true, status: 200, json: async () => ({}) }; });
  const cityHall = { storeId: 's1', address: '서울 중구 세종대로 110', latitude: 37.5663, longitude: 126.9779, correctionRevision: 0 };
  const report = { id: 'loc', status: 'PENDING', reportType: 'STORE_INFO', changeType: 'location_wrong',
    storeName: '테스트 식당', storeId: 's1', currentStore: cityHall };
  admin.setReports([report]);
  admin.openReportResolution(report);
  assert.equal(el('reportResolutionKind').value, 'LOCATION');
  el('reportResolutionReason').value = '현장 확인';
  el('resolutionAddress').value = '서울 중구 세종대로 110';
  el('resolutionLatitude').value = '126.9779';
  el('resolutionLongitude').value = '37.5663';
  await admin.approveReportResolution();
  assert.match(el('reportResolutionError').textContent, /국내 범위\(위도 33~39, 경도 124~132\)/);
  assert.equal(el('confirmActionModal').open, false, 'swapped coordinates must be fixed before confirmation');

  el('resolutionLatitude').value = '35.1796';
  el('resolutionLongitude').value = '129.0756';
  const pending = admin.approveReportResolution();
  assert.equal(el('confirmActionModal').open, true);
  assert.match(el('confirmActionHeading').textContent, /먼 위치/);
  assert.match(el('confirmActionMessage').textContent, /주의: 현재 좌표에서 약 3\d\d\.\dkm 떨어진 곳입니다/);
  el('confirmActionCancel').onclick();
  await pending;
  assert.equal(calls, 0, 'neither the invalid nor the cancelled correction may reach the server');

  const nearby = admin.resolutionSummary('테스트 식당', 'LOCATION', cityHall,
    { address: '서울 중구 세종대로 110-1', latitude: 37.5670, longitude: 126.9785 }, '입구 위치 보정');
  assert.doesNotMatch(nearby, /주의/);
});

function notificationHarness(responder) {
  const bodies = [];
  let uuid = 0;
  const setup = harness((url, options) => {
    if (url.endsWith('/api/admin/notifications') || url.endsWith('/api/admin/notices')) {
      bodies.push({ url, body: JSON.parse(options.body) });
      return responder(options);
    }
    return Promise.resolve({ ok: true, status: 200, json: async () => ({ notifications: 9 }) });
  }, { crypto: { randomUUID: () => `00000000-0000-4000-8000-${String(++uuid).padStart(12, '0')}` } });
  setup.el('notifTargetPicker').hidden = true;
  const confirmAndWait = async (action) => {
    const pending = action();
    setup.el('confirmActionAccept').onclick();
    await flush();
    return pending;
  };
  const sendNotification = (title, body) => {
    setup.el('notifTitle').value = title;
    setup.el('notifBody').value = body;
    return confirmAndWait(() => setup.admin.doSendNotification());
  };
  const publishNotice = (title, body) => {
    setup.el('noticeTitle').value = title;
    setup.el('noticeBody').value = body;
    return confirmAndWait(() => setup.admin.doPublishNotice());
  };
  return { ...setup, bodies, sendNotification, publishNotice };
}

const timeoutUntilAbort = (options) => new Promise((_resolve, reject) => options.signal.addEventListener(
  'abort', () => reject(new DOMException('aborted', 'AbortError')), { once: true }));

test('timed-out broadcast keeps one request ID for the same draft and never asks for a blind retry', async () => {
  let mode = 'timeout';
  const { bodies, timers, el, storage, sendNotification } = notificationHarness((options) => (mode === 'timeout'
    ? timeoutUntilAbort(options)
    : Promise.resolve({ ok: true, status: 200, json: async () => (mode === 'skipped'
      ? { sent: 0, skipped: 3, broadcast: true }
      : { sent: 2, skipped: 1, broadcast: true }) })));

  const first = sendNotification('점검 안내', '오늘 밤 점검합니다');
  await flush();
  const deadline = [...timers.values()].find((timer) => timer.ms === 45000);
  assert.ok(deadline, 'the send must be covered by the 45-second deadline');
  deadline.callback();
  await first;
  const firstId = bodies[0].body.requestId;
  assert.match(firstId, /^[A-Za-z0-9_-]{8,64}$/);
  assert.equal(bodies[0].body.audience, 'ALL');
  assert.match(el('toast').textContent, /중복 발송되지 않아요/);
  assert.doesNotMatch(el('toast').textContent, /잠시 후 다시 시도/);
  assert.match(storage.get('hm_admin_send_drafts'), new RegExp(firstId), 'the draft ID must survive a page reload');

  mode = 'skipped';
  await sendNotification('점검 안내', '오늘 밤 점검합니다');
  assert.equal(bodies[1].body.requestId, firstId, 'resending the same draft must reuse its request ID');
  assert.equal(el('toast').textContent, '이미 모두 발송된 요청이라 다시 보내지 않았어요');

  mode = 'partial';
  await sendNotification('점검 안내', '오늘 밤 점검합니다');
  assert.notEqual(bodies[2].body.requestId, firstId, 'a confirmed send closes the draft');
  assert.equal(el('toast').textContent, '이미 받은 1명은 건너뛰고 새로 2명에게 보냈어요');

  mode = 'timeout';
  const edited = sendNotification('점검 안내', '내일 밤 점검합니다');
  await flush();
  [...timers.values()].find((timer) => timer.ms === 45000).callback();
  await edited;
  assert.notEqual(bodies[3].body.requestId, bodies[2].body.requestId, 'changed content needs a new request ID');
  el('logoutBtn').onclick();
  assert.equal(storage.has('hm_admin_send_drafts'), false, 'logout must drop unsent drafts');
});

test('timed-out notice reuses its request ID and explains that resending is safe', async () => {
  let mode = 'timeout';
  const { bodies, timers, el, publishNotice } = notificationHarness((options) => (mode === 'timeout'
    ? timeoutUntilAbort(options)
    : Promise.resolve({ ok: true, status: 200, json: async () => ({ sent: 0, skipped: 4, broadcast: true }) })));
  const first = publishNotice('서비스 안내', '새 기능이 추가됐어요');
  await flush();
  [...timers.values()].find((timer) => timer.ms === 45000).callback();
  await first;
  assert.match(el('toast').textContent, /공지 등록 결과를 확인하지 못했어요/);
  mode = 'done';
  await publishNotice('서비스 안내', '새 기능이 추가됐어요');
  assert.equal(bodies[1].url.endsWith('/api/admin/notices'), true);
  assert.equal(bodies[1].body.requestId, bodies[0].body.requestId);
  assert.equal(el('toast').textContent, '이미 모두 등록된 공지라 다시 등록하지 않았어요');
});

test('statistics refresh failure after a sent notification keeps the success visible', async () => {
  const { admin, el } = harness(async (url) => (url.endsWith('/community/stats')
    ? { ok: false, status: 500, json: async () => ({ message: '통계 조회 실패' }) }
    : { ok: true, status: 200, json: async () => ({ sent: 3, skipped: 0, broadcast: true }) }));
  el('notifTargetPicker').hidden = true;
  el('notifTitle').value = '안내';
  el('notifBody').value = '내용';
  const pending = admin.doSendNotification();
  el('confirmActionAccept').onclick();
  await pending;
  assert.match(el('toast').textContent, /일반 알림 발송 완료 — 3명에게 전송됨/);
  assert.match(el('toast').textContent, /새로고침/);
  assert.doesNotMatch(el('toast').textContent, /통계 조회 실패/);
});

test('pending reports older than the latest list window stay reviewable with a cap note', async () => {
  const latest = Array.from({ length: 500 }, (_, i) => ({ id: `new-${i}`, status: 'APPROVED', storeName: `매장 ${i}` }));
  latest[0] = { id: 'new-0', status: 'PENDING', storeName: '최근 대기' };
  const waiting = [{ ...latest[0] }, { id: 'old-pending', status: 'PENDING', storeName: '오래된 대기' }];
  const requested = [];
  const { admin, el } = harness(async (url) => {
    requested.push(url);
    return { ok: true, status: 200, json: async () => (url.includes('status=PENDING') ? waiting : latest) };
  });
  await admin.switchView('reports');
  assert.ok(requested.some((url) => url.endsWith('/api/admin/reports?status=PENDING')));
  assert.deepEqual([...admin.state().allReports.filter((r) => r.status === 'PENDING').map((r) => r.id)], ['new-0', 'old-pending']);
  assert.equal(admin.state().allReports.length, 501);
  admin.original.renderReportsView();
  assert.equal(el('pendingPill').textContent, '2');
  assert.match(el('content').innerHTML, /오래된 대기/);
  assert.match(el('content').innerHTML, /최신 500건과 그보다 오래된 대기 제보만 불러왔습니다/);

  const crowded = Array.from({ length: 500 }, (_, i) => ({ id: `p-${i}`, status: 'PENDING' }));
  const full = harness(async () => ({ ok: true, status: 200, json: async () => crowded }));
  await full.admin.switchView('reports');
  full.admin.original.renderReportsView();
  assert.equal(full.el('pendingPill').textContent, '500+');
  assert.match(full.el('content').innerHTML, /대기 제보도 최신 500건까지만 불러왔습니다/);
});

test('stale price change report explains the real conflict instead of asking to review again', async () => {
  const { admin, el } = harness(async () => ({ ok: false, status: 409,
    json: async () => ({ message: '제보 후 매장 정보가 변경되었습니다. 새 정보를 확인한 뒤 다시 검토해주세요.' }) }));
  const report = { id: 'price', status: 'PENDING', changeType: 'rise', storeId: 's1', storeName: '김밥집',
    menu1: '김치찌개', price1: '9000', baseRevision: 1,
    currentStore: { storeId: 's1', menu2: '김치찌개', price2: '8000', free2: false, correctionRevision: 2 } };
  const card = admin.reportCard(report);
  assert.match(card, /현재 등록 가격: 김치찌개 8,000원/);
  assert.match(card, /다른 수정이 먼저 승인되어 그대로 승인할 수 없습니다/);
  assert.doesNotMatch(admin.reportCard({ ...report, baseRevision: 2 }), /그대로 승인할 수 없습니다/);

  admin.setReports([report]);
  const button = { disabled: false };
  const pending = admin.doApprove('price', button);
  el('confirmActionAccept').onclick();
  await pending;
  assert.match(el('toast').textContent, /다른 수정이 먼저 승인/);
  assert.match(el('toast').textContent, /정보 신고로 검토/);
  assert.doesNotMatch(el('toast').textContent, /다시 검토해주세요/);
  assert.equal(button.disabled, false);
});

test('receipt OCR failures are labelled separately from real amount mismatches', () => {
  const { admin } = harness(async () => ({ ok: true, status: 200, json: async () => [] }));
  const base = { id: 'receipt', status: 'PENDING', storeName: '식당', price: '8000', imageUrls: [] };
  const providerError = admin.receiptCard({ ...base, ocrStatus: 'OCR_PROVIDER_ERROR', ocrProviderAvailable: false, ocrScore: 0, ocrPriceMatch: false });
  assert.match(providerError, /OCR 실패\(인식 서비스 오류\)/);
  assert.doesNotMatch(providerError, /금액 불일치/);
  const notRun = admin.receiptCard(base);
  assert.match(notRun, /OCR 미실행/);
  assert.doesNotMatch(notRun, /금액 불일치/);
  const noText = admin.receiptCard({ ...base, ocrStatus: 'MANUAL_REVIEW_DATE_MISSING', ocrProviderAvailable: true,
    ocrDetectedTextLength: 0, ocrScore: 0, ocrPriceMatch: false });
  assert.match(noText, /글자를 읽지 못함/);
  assert.doesNotMatch(noText, /금액 불일치/);
  const noAmount = admin.receiptCard({ ...base, ocrStatus: 'MANUAL_REVIEW', ocrProviderAvailable: true,
    ocrDetectedTextLength: 120, ocrDetectedPrice: 0, ocrScore: 50, ocrPriceMatch: false, ocrStoreMatch: true });
  assert.match(noAmount, /금액 인식 실패/);
  const mismatch = admin.receiptCard({ ...base, ocrStatus: 'MANUAL_REVIEW', ocrProviderAvailable: true,
    ocrDetectedTextLength: 120, ocrDetectedPrice: 9500, ocrScore: 50, ocrPriceMatch: false });
  assert.match(mismatch, /금액 불일치\(인식 9,500원\)/);
  assert.match(admin.receiptCard({ ...base, ocrStatus: 'OCR_NOT_CONFIGURED', ocrProviderAvailable: false }), /OCR 키 미설정/);
});

test('review moderation rows show the author UID next to the client supplied name', () => {
  const { admin, el } = harness(async () => ({ ok: true, status: 200, json: async () => [] }));
  admin.setReviews([{ id: 'review', storeName: '식당', authorName: '운영자', authorUid: 'kakao_1234567890', stars: 5, content: '좋아요' }]);
  admin.setView('reviews');
  admin.original.renderReviewsView();
  const html = el('content').innerHTML;
  assert.match(html, /운영자/);
  assert.match(html, /kakao_12…/);
  assert.match(html, /title="kakao_1234567890"/);
});

test('price correction defaults to the current menu slot named in the report and shows the server same-value refusal', async () => {
  const sameValue = "현재 메뉴·가격과 같습니다. 바뀐 내용이 없으면 '변경 없음'으로 처리해주세요.";
  const { admin, el } = harness(async () => ({ ok: false, status: 400, json: async () => ({ message: sameValue }) }));
  const report = { id: 'info-price', status: 'PENDING', reportType: 'STORE_INFO', changeType: 'price_mismatch',
    storeName: '국수집', storeId: 's1', menu1: '칼국수', price1: '7000',
    currentStore: { storeId: 's1', menu1: '김밥', price1: '4000', menu2: '칼국수', price2: '6500', correctionRevision: 0 } };
  admin.setReports([report]);
  admin.openReportResolution(report);
  assert.equal(el('reportResolutionKind').value, 'PRICE');
  assert.equal(el('resolutionMenuSlot').value, '2');
  assert.match(el('reportResolutionFields').innerHTML, /<option value="2" selected>/);
  assert.match(el('reportResolutionFields').innerHTML, /변경 전: 칼국수 6,500원/);

  const unmatched = { ...report, id: 'info-new', menu1: '수제비' };
  admin.setReports([unmatched]);
  admin.openReportResolution(unmatched);
  assert.equal(el('resolutionMenuSlot').value, '1', 'an unknown menu keeps the previous first-slot default');

  admin.setReports([report]);
  admin.openReportResolution(report);
  el('resolutionMenu').value = '칼국수';
  el('resolutionPrice').value = '6500';
  el('resolutionFree').checked = false;
  el('reportResolutionReason').value = '현장 가격 확인';
  const pending = admin.approveReportResolution();
  el('confirmActionAccept').onclick();
  await pending;
  assert.equal(el('reportResolutionError').textContent, sameValue);
  assert.equal(el('toast').textContent, sameValue);
});

test('QA 2026-10-07 #13 #14: NO_CHANGE is counted apart from approvals and codes read as Korean labels', () => {
  const { admin, el } = harness(async () => ({ ok: true, status: 200, json: async () => [] }));
  const noChange = { id: 'nc', status: 'APPROVED', reportType: 'STORE_INFO', changeType: 'other',
    resolution: 'NO_CHANGE', reviewReason: '현재 정보가 맞음', storeName: '학식당' };
  const price = { id: 'p', status: 'APPROVED', changeType: 'rise', resolution: 'PRICE', storeName: '국밥집' };
  const pendingInfo = { id: 'i', status: 'PENDING', reportType: 'STORE_INFO', changeType: 'location_wrong', storeName: '분식집' };
  const unknown = { id: 'u', status: 'REJECTED', changeType: 'mystery_code', storeName: '카페' };
  admin.setReports([noChange, price, pendingInfo, unknown]);
  const counts = admin.reportCounts();
  assert.equal(counts.APPROVED, 1);
  assert.equal(counts.NO_CHANGE, 1);

  const card = admin.reportCard(noChange);
  assert.match(card, /<span class="badge NO_CHANGE">수정 없음<\/span>/);
  assert.match(card, /유형: 기타/);
  assert.match(card, /확정 처리: 수정 없음 · 검토 사유: 현재 정보가 맞음/);
  assert.doesNotMatch(card, /NO_CHANGE<|other|>승인</);
  assert.match(admin.reportCard(price), /유형: 가격 인상/);
  assert.match(admin.reportCard(price), /확정 처리: 메뉴·가격 수정/);
  assert.match(admin.reportCard(pendingInfo), />검토하기</);
  assert.match(admin.reportCard(pendingInfo), /유형: 위치 정보가 틀려요/);
  assert.doesNotMatch(admin.reportCard(pendingInfo), />승인</);
  assert.match(admin.reportCard(unknown), /유형: mystery_code/, 'unknown codes stay visible');

  admin.setView('reports');
  admin.original.renderReportsView();
  assert.match(el('content').innerHTML, /data-status="APPROVED">승인<span class="count">1<\/span>/);
  assert.match(el('content').innerHTML, /data-status="NO_CHANGE">수정 없음<span class="count">1<\/span>/);

  admin.setOverview({ users: 7, userStores: { total: 15, pending: 1, approved: 5, noChange: 1, rejected: 2, legacy: 7 } });
  admin.setView('dashboard');
  admin.renderDashboard();
  assert.match(el('content').innerHTML, /승인 4 · 수정 없음 1 · 반려 2/);
});

test('QA 2026-10-07 #13: the information report dialog does not call a NO_CHANGE decision an approval', async () => {
  const { admin, el } = harness(async () => ({ ok: true, status: 200, json: async () => [] }));
  const report = { id: 'info', status: 'PENDING', reportType: 'STORE_INFO', changeType: 'other', storeName: '학식당',
    storeId: 's1', currentStore: { storeId: 's1', menu1: '한식', price1: '6500', correctionRevision: 0 } };
  admin.setReports([report]);
  admin.openReportResolution(report);
  assert.equal(el('reportResolutionKind').value, 'NO_CHANGE');
  assert.equal(el('reportResolutionConfirm').textContent, '수정 없음으로 처리');
  assert.match(el('reportResolutionOriginal').textContent, /유형: 기타/);
  el('reportResolutionKind').value = 'PRICE';
  admin.renderResolutionFields();
  assert.equal(el('reportResolutionConfirm').textContent, '변경 확인 후 승인');

  el('reportResolutionKind').value = 'NO_CHANGE';
  admin.renderResolutionFields();
  el('reportResolutionReason').value = '현재 정보가 맞음';
  const pending = admin.approveReportResolution();
  assert.equal(el('confirmActionHeading').textContent, '수정 없음 처리 확인');
  assert.match(el('confirmActionMessage').textContent, /매장 정보 수정 없음/);
  assert.match(el('confirmActionMessage').textContent, /수정 없음으로 처리할까요\?$/);
  el('confirmActionAccept').onclick();
  await pending;
  assert.equal(el('toast').textContent, '수정 없음으로 처리 완료');
});

test('QA 2026-10-07 #47: saving an empty reject reason or answer explains what is missing', async () => {
  let calls = 0;
  const { admin, el } = harness(async () => { calls += 1; return { ok: true, status: 200, json: async () => ({}) }; });
  admin.openRejectModal('r1', '학식당');
  assert.equal(el('rejectReasonError').hidden, true);
  el('rejectReason').value = '   ';
  await admin.doReject();
  assert.equal(el('rejectReasonError').hidden, false);
  assert.match(el('rejectReasonError').textContent, /반려 사유를 입력해주세요/);
  el('rejectReason').oninput();
  assert.equal(el('rejectReasonError').hidden, true, 'typing clears the message');

  admin.setInquiries([{ id: 'q1', title: '문의', content: '내용' }]);
  admin.openAnswerInquiryModal('q1');
  el('answerInquiryText').value = '';
  await admin.doAnswerInquiry();
  assert.equal(el('answerInquiryError').hidden, false);
  assert.match(el('answerInquiryError').textContent, /답변 내용을 입력해주세요/);
  admin.openAnswerInquiryModal('q1');
  assert.equal(el('answerInquiryError').hidden, true, 'reopening starts without the old message');
  assert.equal(calls, 0);
});
