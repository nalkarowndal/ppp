# UI/UX 상세 설계와 디자인 시스템

**Version:** v0.2 / 2단계 기획. **구현 상태:** M1 임시 UI만 존재; 12개 화면은 아직 미완성.

## 경험 목표

- Character First: 캐릭터 상세는 일러스트와 스킬 정보 중심.
- Battle Clarity: 적, 스킬, 상태이상, HP 및 전투 속도는 직관적으로 전달.
- Progress Visibility: 강화 전후 차이와 부족 재화를 표시.
- Progressive Disclosure: 미개방 모드는 잠금/조건 안내.
- Consistency: Theme, 공통 컴포넌트, 시각 QA 기준을 재사용.

## 1. 디자인 토큰

| Semantic token | HEX | 용도 |
|---|---|---|
| background | #111827 | 전체 배경 |
| surface | #222D45 | 기본 패널 |
| surface_elevated | #303D59 | 강조 패널 |
| border | #526078 | 경계 |
| accent_gold | #D9BD85 | 주요 CTA/선택 |
| text_primary | #F5F0E5 | 본문 |
| text_secondary | #BCC6D9 | 보조 |
| magic | #8BA8FF | 마법·진행률 |
| success | #7ECCAA | 긍정 피드백 |
| danger | #F08F96 | 오류/실패 |
| affinity | #CF879B | 스토리·교류 |

간격: 4/8/12/16/24/32 (논리 UI px). 모서리: Button 10, Card 12, Modal 16. 주요 본문 15~16, 제목 22~24, 보조 13~14. 텍스트와 기능 아이콘은 고해상도, 전투 월드는 별도 저해상도 뷰포트. 배경·텍스트 조합은 WCAG 대비 테스트가 선행되어야 함.

## 2. 화면 계층 / 내비게이션

타이틀 → 메인 전투 → (전투 결과, 파티, 방치 보상, 스테이지, 던전). 하단: 전투·동료·탐험·거점·메뉴. 동료 → 목록 → 상세(정보·스킬·장비·승급). 거점 → 시설 → 교류. 하단 내비게이션은 보스 연출·전면 모달에서 임시 숨길 수 있다.

## 3. 12개 화면별 필수 구성

| ID | 이름 | 주요 영역 | 핵심 동작 | 기본/예외 상태 |
|---|---|---|---|---|
| UI-001 | 타이틀 | 로고·세계관·진입 | 시작·이어하기 | 첫 실행, 세이브 오류 |
| UI-002 | 메인 전투 | 상단 HUD·전장·스킬·방치·하단 메뉴 | 배속·AUTO·궁극기 | 대기/전투/승리/패배 |
| UI-003 | 전투 결과 | 승패·전투 기여·보상 | 다음·재도전 | 최초 보상/일반 보상 |
| UI-004 | 파티 편성 | 전열2/후열3·로스터·시너지 | 드래그/선택 교체·저장 | 빈 슬롯, 중복 선택 |
| UI-005 | 캐릭터 목록 | 필터·정렬·카드 | 검색·선택 | 보유 없음·잠금 |
| UI-006 | 캐릭터 상세 | 일러스트·능력치·탭·강화 | 성장·스킬·장비 | 재화 부족·최대레벨 |
| UI-007 | 방치 보상 | 적립 시간·보상 목록·CTA | 수령 | 최대 적립·정산 중 |
| UI-008 | 스테이지 | 지역·진행도·보상·보스 | 입장·보상 미리보기 | 잠금/클리어 |
| UI-009 | 던전 | 종류·난도·보상 | 도전 | 입장 제한 |
| UI-010 | 거점 | 월드·시설 선택·생산 | 업그레이드·수령 | 건설 전·생산 완료 |
| UI-011 | 교류 | 캐릭터·호감도·대화 | 선물·에피소드 | 잠금·보상 가능 |
| UI-012 | 설정 | 음량·프레임·접근성·저장 | 값 변경 | 저장 실패 |

## 4. 공통 컴포넌트

PrimaryButton, SecondaryButton, IconButton, CharacterCard, CurrencyDisplay, ProgressBar, ModalDialog, RewardItem, NavigationTab, SkillCard, NotificationBadge, Tooltip, Toast, LoadingOverlay, EmptyState.

각 컴포넌트는 기본·누름·포커스·비활성·로딩·오류 상태를 설계한다. 재화 처리 버튼은 처리 중 연속 클릭 방지. 저장하지 않은 파티 변경 시 이탈 확인. 자동전투 배속과 UI 모션 속도를 분리.

## 5. 화면 와이어프레임 (모바일 세로)

### 전투

```text
┌ 계정 Lv │ GOLD │ GEM ┐
├ CHAPTER 1 / STAGE 1 ┤
│                     │
│  Pixel World View   │
│  Allies VS Enemies  │
│                     │
├ HP / Skill / AUTO ×2┤
├ Offline reward CTA  ┤
└전투·동료·탐험·거점·메뉴┘
```

### 캐릭터 상세

```text
┌ 뒤로 │ 이름 │ 희귀도 ┐
│  Main Character Art │
├ HP · ATK · DEF · SPD ┤
├ 정보│스킬│장비│승급 ┤
│ 상세 성장 정보        │
└ 현재 비용 │ 강화 CTA┘
```

## 6. Godot 구현 규칙

- 루트 Control/Container + Theme 사용. 공통 버튼 및 카드 PackedScene 재사용.
- 픽셀 월드는 SubViewport에서 저해상도로 렌더링, 고해상도 UI는 별도의 Control/CanvasLayer에 렌더링하는 방안을 M4 전에 검증.
- 모바일 기준 360×800 논리 UI 좌표에서 출발하며, 안전 영역과 다양한 종횡비 확인.
- Godot pixel viewport 크기는 실제 전투 구역에 맞춰 결정하며 320×180 고정 전체화면으로 가정하지 않음.
- 장애 및 로딩 상태에서 잘못된 데이터/중복 터치 방지.
- 접근성: 주요 터치 대상은 Android 48dp 권고를 기준으로 실제 물리 크기 검수. 감소된 모션 설정 지원.

## 7. 구현/검수 단계

M1: 색상·단순 HUD·임시 화면; M5: 12개 화면과 공통 Theme 및 컴포넌트 통합. 검수: 한글 잘림, 대비, 다양한 화면비, 버튼 중복 처리, 데이터-UI 일치, 성능·메모리.

**Sources**: [Godot GUI Theme](https://docs.godotengine.org/en/4.7/tutorials/ui/gui_using_theme_editor.html), [Godot multiple resolutions](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html), [WCAG 2.2](https://www.w3.org/TR/WCAG22/).
