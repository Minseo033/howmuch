# HowMuch token audit — 2026-08-25

| Severity | Category | Finding |
|---|---|---|
| High | Semantics | `AppColors`에 원시 색상과 역할 색상이 섞여 있고 다수 화면이 원시 `Color(...)`를 직접 사용한다. 이번 패스에서 공통 surface/text/accent 역할을 추가했다. |
| High | Coverage | 색상 외 간격, 반경, 터치 크기, 그림자, 모션, 레이어에 공통 계약이 없었다. `app_tokens.dart`에 재사용되는 최소 제품 토큰을 추가했다. |
| Medium | Arbitrary values | `lib/`에 직접 선언된 색상 663개, 숫자 반경 380개, 글자 크기 674개가 있어 일괄 교체는 별도 점진적 마이그레이션이 필요하다. |
| Medium | Typography | 일부 공통 위젯이 프로젝트에 포함되지 않은 `Inter`를 우선 지정해 한글 폴백에 의존했다. 공통 하단 내비게이션을 Noto Sans KR 계약에 맞췄다. |
| Medium | Motion | 웹과 관리자에 `prefers-reduced-motion` 대응이 없었다. 두 웹 진입점에 동작 감소 규칙을 추가했다. |
| Low | Dark mode | 운영 제품은 명시적 라이트 테마만 제공한다. 이번 범위에서는 미완성 다크 모드를 추가하지 않고 추후 별도 제품 결정으로 남긴다. |

## Three-layer status

- Primitive: 색상, 간격, 반경, 크기, 그림자, 모션, 레이어의 최소 공통 값이 존재한다.
- Semantic: surface, text, accent 역할을 `AppColors`에 추가했다.
- Component: 공통 하단 내비게이션과 앱 테마가 semantic/primitive 토큰을 사용한다. 기능 전용 값은 해당 기능에 유지한다.

## Migration rule

새 공통 컴포넌트는 원시 색상과 임의 반경을 추가하기 전에 기존 토큰을 사용한다. 기존 1,000개 이상의 직접 값은 화면을 수정할 때 회귀 테스트와 함께 점진적으로 치환하며, 일괄 기계 변환하지 않는다.
