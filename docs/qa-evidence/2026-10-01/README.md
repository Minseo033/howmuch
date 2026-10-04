# QA 화면 근거

운영 QA의 주요 화면만 보관한다. 인증 비밀번호·토큰·개인 이메일·정확한 사용자 위치가 포함된 화면은 공유하지 않는다.

전체 실행·판정은 [출시 QA 보고서](../../RELEASE_QA_2026-10-01.md), 핸드오프는 [프로젝트 현황](../../PROJECT_STATUS.md) 5-144 참조. 아래는 중요 근거의 인덱스이며 한 장의 이미지로 전체 기능 통과를 증명하지 않는다.

## 우선 수정 근거

| 파일 | 내용/범위 |
|---|---|
| map-interaction-disappeared.png | 일반 화면의 빠른 마커 선택/배경 클릭/드래그 후 지도만 사라진 상태. 간헐 재현이며 단일 원인은 미확정 |
| map-resize-disappeared-393.png | 393×852 전환 후 지도 소실. 실기기 Safari 종료 증거가 아님 |
| recommendation-map-missing-after-resize.png | resize 오류 이후 추천 지도도 표시되지 않은 상태 |
| store-multi-price-concatenated.png | 숨터 상세 커피30,003,500원. 운영 원본3,000 / 3,500의 연결 오류 |
| store-search-price-3000.png | 동일 숨터 검색 목록3,000원. 상세와의 대조 |
| savings-last-month-wrong-detail.png | 지난 달 진입 후 이번 달 헤더/집계·여러 달 목록 불일치 |
| admin-info-report-missing-description.png | QA 기타 신고 카드에 유형/본문 검토 내용 누락 |
| receipt-original-error.png | 새 QA 영수증 원본 열기 실패. 독립 공개 URL HEAD/GET404도 확인 |
| 검색 지도0건 (원본 캡처 공유 제외) | 검색 목록2건에서 지도0건·범위 미이동. 후속 수정의 공개 근거는 reqa/05-search-map-fixed.jpg 참조 |
| kakao-walk-fallback.png | 도보 선택 후 카카오 웹 대체 길찾기에서 출발/수단 소실 |
| info-report-optional-required.png | 선택 라벨과 빈 값 필수 검증 불일치 |
| my-reviews-wrong-source.png | 정부 인증 매장의 내 리뷰 출처가 사용자 제보로 표시 |
| my-reports-search-placeholder.png | 내 제보 검색이 다음 단계 연결 안내만 표시 |
| report-zero-price-accepted.png | QA0원 제보 접수. 무료 서비스 정책 확인 대상이며 실제 매장 승인 안 함 |

지도 접근성 포인터 차단과 AI244.8km 김밥 추천은 실제 화면/AX/DOM 대조를 실행 기록에 남겼다. 공유 화면을 저장하지 않았다고 해당 동작을 실행하지 않은 것은 아니며, 자동 접근성 감사 결과로 표현하지 않는다.

## 정상 동작·QA 변경 근거

| 파일 | 내용/범위 |
|---|---|
| favorite-restored.png | 찜 해제/재추가 후 원래3곳 복원 |
| review-created.png | 명시적 QA 리뷰 저장·노출. 실제 방문 후기가 아님 |
| qa-review-cleanup-confirmation.png | 정확한 QA 리뷰1건 삭제 확인창. 최종 삭제는 취소/동의 대기 |
| receipt-rejected.png | 잘못된 QA 전용 증빙을 실제 방문으로 승인하지 않고 반려 |
| map-zoom-max.png | 기본 입력 상태 최대8km 줌아웃에서 지도 표시. 실기기 메모리/장시간 통과를 의미하지 않음 |
| map-selected-overlap-marker.png | 겹친 무한칼국수 선택 후 앞순서/강조(공공 매장 부분만 캡처) |
| map-selected-overlap-card.png | 선택한 무한칼국수 카드5,000원 |
| recommendation-carousel-map.png | 추천 카드 전환 시 매장/지도 동기화 |
| notice-mobile-375.png | 실제375×812 공지 전문·하단 버튼. 전체 모바일 QA 증거가 아님 |
| notification-full-content.png | 공지 알림의 두 문단 전체 표시 |
| own-notification-received.png | 본인에게만 보낸 QA 알림 실시간 수신 |
| own-notification-full.png | 해당 QA 알림 전문 두 문단 |
| qa-comment-reply-created.png | 본인 게시물의 QA 댓글/답글 저장 |
| inquiry-answer-linked.png | QA 문의에 대한 관리자 답변·사용자 표시 연결 |
| settings-restored.png | QA 후 원래 설정으로 복원 |
| privacy-delete-policy-text.png | 탈퇴/데이터 처리 정책 본문 |
| withdrawal-data-notice.png | 사용자 탈퇴 안내의 승인 제보 익명 보존 예외. 탈퇴 최종 미실행 |

## 캡처 크기 주의

`directions-mobile-375.png`는 이름과 달리 실제1424×654 캡처다. 모바일 통과의 근거로 사용하지 않는다. 기본 데스크톱 화면, DevTools의 에뮬레이션, 실제 모바일 기기를 서로 구분한다. 임시 device emulation은 QA 후 해제했다.

## 수정 후 실제 재QA 근거

최신 판정은 [수정 장부](../../RELEASE_REMEDIATION_2026-10-01.md)와 프로젝트현황5-145를 참조한다. 원본 정확한 사용자 위치가 보였던 임시 캡처2개는 공유 디렉터리에서 제외해 로컬 임시폴더에 보관했다. 개인 활동·타 문의 본문 또는 주변 지도/거리로 위치를 추정할 수 있는 재QA02/08/12/15/17은 로컬에만 보존하고 Git 게시에서 제외했다. 아래 JPEG는 해당 실제 화면 동작의 범위만 증명하며 캡처 배율 주의 항목은 시각적 PASS 근거로 쓰지 않는다.

| 파일 | 내용/범위 |
|---|---|
| reqa/02-savings-september.jpg (로컬 전용) | 9월 절약 상세의 기간/1500원1회/9월 방문 일치 |
| reqa/03-receipt-deleted-original.jpg | 심사 처리된 원본 삭제 상태·삭제 링크 미표시. 새 대기 원본 성공 증거가 아님 |
| reqa/04-inquiry-full-body.jpg | QA 문의 전문2문단·첨부 표시(이 QA 문의는 이후 동의 후 삭제) |
| reqa/05-search-map-fixed.jpg | 검색 숨터 결과·지도 범위·카드·복수 가격 재배포 후 일치 |
| reqa/06-no-change-approved.jpg | 재QA 신고 NO_CHANGE/사유 승인 실저장. 실제 가격/위치/폐업 수정 아님, 이후 신고 삭제 |
| reqa/07-review-source-fixed.jpg | 내 리뷰 실제 매장 출처, QA 리뷰는 이후 삭제 |
| reqa/08-ai-soup-verified.jpg (로컬 전용) | 국물 AI 질문의 반경 내 메뉴/가격/출처. 모든 질문 통과 증거 아님 |
| reqa/09-second-menu-price-history.jpg | 상세 두 번째 메뉴→고척칼국수 바지락칼국수9,000원 가격 이력 |
| reqa/11-qa-rejected-cleanup-candidates.jpg | 사용자 직전 동의를 받은 이번 QA 반려 제보2건. 과거 제보 정리 허용 아님 |
| reqa/12-qa-inquiry-cleaned.jpg (로컬 전용) | QA 문의 삭제 후 기존4건 보존·첨부1장 정리 표시 |
| reqa/13-qa-review-cleaned.jpg | QA 리뷰 삭제 후 기존3건 보존 |
| reqa/14-report-deletion-clarified.jpg | 운영 최신 삭제 확인 안내: 신규 공개 매장/정보 신고를 구분. 열기 후 취소하여 기존 제보 유지 |
| reqa/15-ai-meal-verified.jpg (로컬 전용) | 보완 후 현재 후보의1km·1만원 이하 식사3곳. 이전 브랜드 후보가 포함된 동일 현장 재현 증거는 아님 |
| reqa/16-short-height-before.jpg | 운영563b523의 실제393×213 전환에서 Invalid164와 빈 화면 재현. 정상 모바일/실기기 검사가 아님 |
| reqa/17-short-height-fixed.jpg (로컬 전용) | fb6fe67의 같은 크기 전환 후 캡처. 래스터 배율 불일치로 일부만 담겨 완성 UI 시각 PASS 증거로 사용하지 않음. 실제 지도/확대/AI 버튼·실측일치21회 검사 결과는 수정 장부 참조 |
