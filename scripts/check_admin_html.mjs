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
