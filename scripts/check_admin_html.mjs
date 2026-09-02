import fs from 'node:fs';
import vm from 'node:vm';

const files = ['../web/admin.html', '../web/index.html'];
let parsed = 0;

for (const file of files) {
  const url = new URL(file, import.meta.url);
  const html = fs.readFileSync(url, 'utf8');
  if (file.endsWith('admin.html')) {
    const requiredNotificationPickerHooks = [
      'notifTargetSearch',
      'notifTargetResults',
      'selectedNotificationUid',
      '검색 결과에서 대상 회원을 선택해주세요',
    ];
    for (const hook of requiredNotificationPickerHooks) {
      if (!html.includes(hook)) {
        throw new Error(`${file}의 회원 검색 기반 알림 대상 선택 기능이 누락되었습니다: ${hook}`);
      }
    }
    if (/\b(?:window\.)?confirm\s*\(/.test(html)) {
      throw new Error(`${file}에서 브라우저 기본 confirm()을 사용하면 안 됩니다.`);
    }

    const accessibilityGuards = [
      ['<dialog class="modal-backdrop" id="rejectModal"', '관리자 작업 확인창을 네이티브 dialog로 제공해야 합니다.'],
      ['showModal()', '관리자 dialog는 showModal()로 열어 포커스를 가둬야 합니다.'],
      ['modalTriggers', '관리자 dialog를 닫은 뒤 실행 버튼으로 포커스를 복원해야 합니다.'],
      ['class="sr-only" for="keyInput"', '관리자 키 입력에는 접근 가능한 레이블이 필요합니다.'],
      ['prefers-reduced-motion: reduce', '토스트 애니메이션은 모션 축소 설정을 존중해야 합니다.'],
    ];
    for (const [guard, message] of accessibilityGuards) {
      if (!html.includes(guard)) throw new Error(`${file}: ${message}`);
    }
    if (/transition\s*:\s*all\b/i.test(html)) {
      throw new Error(`${file}에서 transition: all을 사용하면 안 됩니다.`);
    }
    if (/<div[^>]+class="modal-backdrop"/i.test(html)) {
      throw new Error(`${file}의 모달 배경은 div가 아닌 dialog여야 합니다.`);
    }

    const sessionSafetyGuards = [
      ['scheduleKeyExpiry', '관리자 키 만료 타이머가 필요합니다.'],
      ['clearAdminData', '세션 만료 시 민감한 관리자 데이터를 비워야 합니다.'],
      ['inFlightControllers.forEach((controller) => controller.abort())', '세션 만료 시 진행 중인 요청을 취소해야 합니다.'],
      ['API_TIMEOUT_MS', '관리자 API 요청에는 제한 시간이 필요합니다.'],
    ];
    for (const [guard, message] of sessionSafetyGuards) {
      if (!html.includes(guard)) throw new Error(`${file}: ${message}`);
    }

    const readEfficiencyGuards = [
      ['reportsLoaded', '빈 제보 목록도 조회 완료 상태로 기억해야 합니다.'],
      ['const overviewRequest = overview ?? api(\'/api/admin/overview\')', '로그인 검증에서 받은 대시보드 응답을 재사용해야 합니다.'],
      ['reportsLoaded = false;\n      await loadDashboard()', '대시보드 수동 새로고침은 제보 목록을 한 번만 요청해야 합니다.'],
    ];
    for (const [guard, message] of readEfficiencyGuards) {
      if (!html.includes(guard)) throw new Error(`${file}: ${message}`);
    }
    if (/async function refresh\(\)[\s\S]*?try\s*\{\s*allReports\s*=\s*await api/.test(html)) {
      throw new Error(`${file}: 새로고침 전에 제보 목록을 선조회하면 현재 화면 로드와 중복됩니다.`);
    }
  }
  const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
    .map((match) => match[1])
    .filter((source) => source.trim().length > 0);

  if (scripts.length === 0) {
    throw new Error(`${file}에 검사할 내부 스크립트가 없습니다.`);
  }

  for (const [index, source] of scripts.entries()) {
    new vm.Script(source, { filename: `${file}#script-${index + 1}` });
    parsed++;
  }
}

console.log(`web internal scripts parsed: ${parsed}`);
