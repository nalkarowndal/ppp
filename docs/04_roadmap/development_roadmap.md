# Godot 개발 로드맵 / 마일스톤 승인 조건

**Version:** v1.0. 시작일 2026-11-09. MVP는 8 캐릭터 / 40 스테이지 / 2 보스 / 2 성장 던전 / 기본 거점 1개.

## 진행 현황

| Milestone | 목표 | 현 상태 |
|---|---|---|
| M0 | 기술 결정·GDD/QA 문서·Git 저장소 준비 | 문서·환경 기준 수립; Linux Godot 실행 CI 통과, Android 검증 필요 |
| M1 | 씬·로더·저장·임시 UI 기초 | 임시 씬·로더·UI·저장 구현, Linux CI와 360×800/900 렌더 검증 통과; Android 수동 QA 미통과(승인 보류) |
| M2 | 3인+보스 전투 코어·상태이상·자동 AI | M2-1 Draft PR #12, 별도 M2-2 직업/열/위협도·도발 정책 브랜치에서 Godot CI 검증; M2-3~5 미구현, M1 실기기 QA 보류 |
| M3 | 1~100 레벨·승급·장비·재화·8h 방치 | M3-1~5 로직·저장 및 M3-6 성장/장비/방치 UI Draft 구현; 물리 Windows GUI·Android ARM64 실기기 QA 및 최종 PR 병합 보류 |
| M4 | 10스테이지 수직슬라이스·보상·진행 저장 | 미시작 |
| M5 | 12개 UI 화면·공통 Theme·반응형 | 미시작; 임시 UI만 존재 |
| M6 | 8 캐릭터·40 스테이지·보스2·던전2·거점1 | 미시작 |
| M7 | 픽셀아트·VFX·일러스트·BGM·SFX | 미시작 |
| M8 | 전투/경제 시뮬레이션·자동/시각 QA·최적화 | 미시작 |
| M9 | Android·Windows 내보내기 및 테스트 | 미시작 |
| M10 | 호감도·거점 확장·로그라이크·길드 검토 | MVP 이후 |

## Phase 순서와 의존성

1. **M0:** 요구사항·엔진·대상 기기·렌더러 확인 → 실행 기준 확정.
2. **M1:** 프로젝트 뼈대·데이터 유효성 검증·로컬 저장·재사용 UI 기반 → 헤드리스 및 수동 실행 성공.
3. **M2:** 3인 전투 시뮬레이터와 스킬/상태이상 → 고정 시드 결과 재현·애니메이션 연결.
4. **M3:** 레벨/승급/장비/재화/방치 → 저장 후 실제 계산과 화면 일치.
5. **M4:** 첫 10스테이지에 진입~보상~성장~재접속 전체 순환 구현 → 수직슬라이스 승인.
6. **M5:** 12개 화면 설계 중 MVP 필수 동작 구현 → UI 시각/접근성 QA.
7. **M6:** 본편 데이터 8/40/2/2 확장 → 모든 콘텐츠 플레이 루프 검증.
8. **M7:** 정식 에셋/오디오/연출 및 시각 품질 통일 → 프레임 예산 충족.
9. **M8:** 저장·경제·전투·메모리 회귀 테스트 및 모바일 실기기 QA → Blocker/Critical 0.
10. **M9:** Android·Windows 패키지 서명/배포 테스트 → 릴리스 후보.

## 공통 Exit Gate

- [ ] 요구기능 구현과 코드 리뷰 완료
- [ ] Headless import와 GDScript Smoke 테스트 통과
- [ ] 데이터 스키마·참조 무결성 검증
- [ ] 실제 Godot 실행·주요 기능 수동 검수
- [ ] PC·모바일 대상 화면에서 시각 QA 통과
- [ ] 저장/재화/전투 시나리오 회귀 테스트 통과
- [ ] Blocker/Critical 결함 0; Major 결함 처리 기록
- [ ] 문서·데이터·동작 결과 일치
- [ ] 해당 브랜치의 CI 성공 및 PR 검토·병합

하나라도 충족하지 못하면 단계 **완료** 금지. 통과하지 않은 항목은 명확한 이슈, 재현 방법, 담당 검증 단계로 기록하고 같은 단계에서 계속 수정한다.

## 현재 작업 정의 (M0/M1-F0)

- Godot 프로젝트 초기화, portrait UI, Compatibility 설정
- 카테고리·색상 기본 UI 플레이스홀더
- 캐릭터 8명·스킬 16개 **명세 데이터**·몬스터 3종·미가동 스테이지 10개
- 파일 로더·피해 계산·레벨 비용·개발용 저장·1턴 샌드박스
- 데이터 정적 검증과 엔진 Smoke 스크립트
- PR 이후 실제 엔진 설치 환경에서 수동 시각 검수 필요

**이번 커밋은 M0/M1의 시작이며, M1 완료 판정이 아니다.**

## M1 검증 업데이트 (2026-11-09)

- PR #3에서 공식 Godot 4.7.2 Linux 바이너리 사용. Import/스크립트 파싱/전투 계산 Smoke/UI 버튼 시그널·저장 재생성/메인 씬 자동 실행 통과.
- 360×800 및 360×900 Xvfb OpenGL 렌더링 PNG 생성 및 실제 이미지 검수 완료: 한글 표시 정상, 기본 패널과 스크롤 배치 확인.
- 검증 기록: [Godot M1 Runtime Validation](https://github.com/nalkarowndal/ppp/actions/runs/42575430523), [QA 상세](../qa/m1_runtime_validation.md).
- Android 실기기 실행, 수동 터치·실제 앱 재시작 저장 검증 및 플랫폼 독립 폰트 번들은 아직 미검증/미구현. **M1 최종 승인 보류**, 이슈 #2 유지.

## 2026-11-09 M1 플랫폼 자동 검증 결과 (PR #4)

- **Windows:** 공식 Godot 4.7.2 Windows 엔진으로 Import/Smoke/UI/별도 OS 프로세스 사이 `user://` 저장·읽기/헤드리스 메인 씬 실행 모두 통과.
- **Android:** Godot 4.7.2 공식 템플릿, JDK 17, Android SDK 35로 arm64 디버그 APK 생성·v2/v3 서명·패키지명 확인 통과. 패키징/보관용 Artifact 제공.
- **Linux:** 기존 Import/Smoke/2종 렌더링 CI 재검증 통과.
- 성공 기록: [Windows Actions](https://github.com/nalkarowndal/ppp/actions/runs/42577123154), [Android Actions](https://github.com/nalkarowndal/ppp/actions/runs/42577123146).
- 추가 임시 에셋: 게임 정식 아트가 아닌 자체 제작 개발용 `assets/icon.svg`.
- **미검증:** 실제 Android 기기 설치·실행·터치·안전 영역·완전 종료 후 복구·한글 폰트, Windows GUI 수동 사용성. 공식 M1 승인 및 M2 진입은 여전히 보류. [검수 계획](../qa/m1_platform_validation_plan.md).

## M1 Android 에뮬레이터 실사용 화면 검증 (2026-11-10)

- [PR #6](https://github.com/nalkarowndal/ppp/pull/6): Android 35 x86_64 에뮬레이터 앱 설치·최초 실행·강제 종료/재실행 및 실제 게임 화면 캡처를 추가.
- [Actions 성공 #42727828387](https://github.com/nalkarowndal/ppp/actions/runs/42727828387): SwANGLE GPU 경로에서 화면 색상·Godot UI 초기화·Android 로그 검사 PASS.
- 실제 1080×1920 PNG 2종 직접 확인: 한글·제목·임시 전투 패널·캐릭터 목록 정상 렌더, 팝업/로고 미표시. 화면은 **M1 임시 UI**이며 정식 도트아트 게임 UI가 아님.
- 순수 SwiftShader GLES3는 shader uniform linking 오류로 앱이 종료된 이력이 있어, 다른 실기기 그래픽 드라이버까지 통과 주장 금지.
- Android 실기기 터치/저장·Windows GUI 수동 테스트 등 잔여 승인은 계속 보류. 상세: [M1 에뮬레이터 QA](../qa/m1_android_emulator_qa.md).

## 2026-11-10 M1 Android 터치 E2E 검증

- [Android x86_64 Actions #42760648521](https://github.com/nalkarowndal/ppp/actions/runs/42760648521)에서 실제 버튼 터치·개발용 저장(turn=1)·Android 강제 종료/별도 PID 재실행 후 저장 표시 검증 **통과**.
- 접근성 개선: 저장 패널을 길게 나열된 캐릭터 데이터 목록보다 상단으로 이동해 초기 화면에서 스크롤 없이 터치 가능하도록 수정.
- 현재 저장은 M1 **디버그 턴 번호 기록**이며 완전한 전투 진행 데이터 복원이 아님. 정식 저장 백업·마이그레이션은 M3 작업.
- Android 실기기 arm64/노치/터치 및 Windows GUI 수동 검증 미완료로 **M1 최종 승인 보류**, M2 본 구현 미착수.

## M2-1 기능 개발 착수 (2026-11-10, Draft PR #12)

- `feature/m2-auto-combat-core`에서 고정 20Hz 자동 기본 공격·최대 5인 런타임 편성·전투 배속 인터페이스·승패 및 시간 제한을 **별도 실험 구현**.
- 테스트: `tests/m2_combat_core_test.gd`, 전용 workflow `godot-m2-combat.yml` (동일 시드 재현·타깃·배속·보스 시간 제한·JSON 데이터 불변).
- **미구현**: 액티브·궁극기, 쿨다운, 상태이상, 피해 외 효과, 실제 전투 화면/UI 통합, 전투 상태 저장.
- **승인 경계**: 실제 Android ARM64 및 Windows PC 수동 QA 미완료. 기존 M1 기준이나 이슈 #2를 변경·해제하지 않음. M2 전체 완료 선언 및 main 병합은 보류.
- [M2-1 상세 QA 범위](../qa/m2_1_combat_core.md), [Draft PR #12](https://github.com/nalkarowndal/ppp/pull/12).

## 2026-11-10 M2-2 직업별 타깃 AI 단계

- M2-1 Draft PR #12를 기반으로 `feature/m2-2-target-ai` 브랜치 작업. M1 기존 샌드박스·디버그 저장 유지.
- 기본 공격의 타깃 정책을 `target_selector.gd`로 분리하고 직업/전열·후열/위협도/도발 우선순위를 결정적 규칙으로 적용.
- Godot 4.7.2 RED → GREEN 사례: [RED CI #42777785656](https://github.com/nalkarowndal/ppp/actions/runs/42777785656) / [GREEN CI #42777966949](https://github.com/nalkarowndal/ppp/actions/runs/42777966949).
- 스킬/상태이상/실제 전투 시각 연출·Android 및 Windows 실기기 QA는 완료하지 않음. 따라서 **M2 전체 승인·main 병합 보류**.
- [M2-2 QA 문서](../qa/m2_2_target_ai.md).

## 2026-11-11 M2-3 스킬 코어 (독립 Draft 스택)

- M2-2를 기반으로 `feature/m2-3-skills` 브랜치에서 액티브 8 + 궁극기 8종의 사용, 쿨다운, 기력, 자동/수동 사용 예약, 대상 판정 및 즉시 효과 처리.
- M2-1/2 회귀 유지: [M2-3 GREEN CI #42980243589](https://github.com/nalkarowndal/ppp/actions/runs/42980243589).
- [M2-3 QA 기록](../qa/m2_3_skill_runtime.md)과 사양 참조.
- M2-4: 지속 상태·면역·중첩·해제/재생·방어 버프. M2-5: 정식 UI/연출/인터랙션/실물 Android arm64 및 Windows 검수.
- M1 이슈 #2와 별도 실기기 검수는 **미승인**, M2 전체 완료 및 main 병합 **보류**.

## 2026-11-11 M2-4 상태이상 코어

- M2-3 Draft PR #14 기반 `feature/m2-4-status-effects` 스택 브랜치.
- `status_effects.gd` 순수 정책 모듈 및 전투 스킬 연동: 화상/독 DOT, 재생 HOT, 빙결 제어, 감속, DEF_UP/DEF_DOWN, 도발 상태화, 중첩·만료·면역·해제.
- RED→GREEN 증거: [RED CI #42981010147](https://github.com/nalkarowndal/ppp/actions/runs/42981010147), [M2-4 강화 GREEN CI #42981725542](https://github.com/nalkarowndal/ppp/actions/runs/42981725542).
- 동기화된 기존 M2-3 테스트는 이제 미구현 마커가 아닌 실제 상태 적용을 검사합니다.
- [M2-4 상세 QA](../qa/m2_4_status_effects.md).
- 잔여: M2-5 UI/상태 아이콘·VFX/실기기 검증, 정식 상태 저항·보스·밸런스·실제 저장 연동. M1 Windows/Android ARM64 물리 QA는 아직 승인 전이며 **M2 전체 마일스톤·main 병합 보류**.

## 2026-11-11 M2-5 실시간 전투 화면 기술 프리뷰

- M2-4 Draft PR #15 기반 `feature/m2-5-battle-ui` 별도 브랜치. M1 UI/임시 샌드박스·저장 기능은 유지하면서 화면의 독립 실행 버튼만 추가.
- `scenes/battle_m2_5.tscn`, `scripts/ui/battle_ui.gd`, `battle_view_model.gd`: 실제 20Hz 3v3 HP/기력/버프·디버프 표기/자동 궁극기/수동 예약/배속/재시작/되돌리기/이벤트 로그, 간단한 색 강조 구현.
- Godot 4.7.2 SceneTree headless 실사용 신호 테스트 및 360×800 / 480×960 Linux Xvfb 실제 렌더러 PNG 자동 캡처. 기본 CI 테스트 통과와 시각 캡처는 별도의 근거로 구분; 상태이상 예시 및 스크롤 패널까지 시각 확인.
- 실제 화면 캡처에서 Linux CJK 글리프가 없던 버그를 확인해 CI에 `fonts-noto-cjk` 설치, 한글 표시 검증. 전투 로그의 내부 ID와 카드 글씨까지 어둡게 하는 강조도 수정. [M2-5 QA](../qa/m2_5_battle_ui.md).
- **M2-5 완료 판정 금지:** 임시 카드/무아트, 정식 애니메이션·VFX/사운드, 전투 결과·보상 및 실기기 Windows GUI/Android ARM64 터치·한글·노치/안전 영역 검수 미완료. M1 이슈 #2 및 main 병합 보류.


## 2026-11-12 M3-1 성장 Draft

- M2-5 Draft #16에서 feature/m3-1-growth-progression 분기, main 미병합.
- Lv.1~100/1~5성, HP/ATK/DEF 승급, 골드·XP·승급석 원자적 차감 정책 및 테스트 추가.
- 검증 문서: docs/qa/m3_1_growth.md, Superpowers specs/plans.
- M3-2 장비, M3-3 재화 지급, M3-4 오프라인 8시간, M3-5 저장, M3-6 성장 UI/실기기 QA 미구현. M1 issue #2 보류 유지.


## 2026-11-12 M3-2 장비/강화 순수 로직 Draft

- `feature/m3-1-growth-progression` 분기 위에 `feature/m3-2-equipment-system` 스택.
- 무기·방어구·장신구 2슬롯, 시제품 아이템 JSON 6종, 강화 5/10/15, 유일 인스턴스 소유권 및 교체, 재화 차감, 능력치 합산 테스트 추가.
- M3-1 성장 공식과 M1 저장, M2-1~5 자동전투를 수정하지 않음.
- 상세: `docs/qa/m3_2_equipment.md`, `docs/superpowers/specs/2026-11-12-m3-2-equipment.md`.
- M3-3~6 (획득 재화, 8h 방치, 저장/복구, UI/실기기 QA), 게임 내 전투 연동은 후속. 물리 QA 이슈 #2 유지, `main` 병합 및 M3 승인 금지.


## 2026-11-12 M3-3 재화·인벤토리·중복 지급 방지

- M3-2 Draft PR #19 기준 별도 스택 브랜치. 6종 재화, 장비 인스턴스 발급, 거래 ID 기반 중복 보상·차감 방지, 성장·승급·강화 영수증 연결.
- JSON 재로드 정수형 정상화 테스트 및 실패 시 원본 상태 불변·재화 미차감 검증. 실세이브는 M3-5, 전투 보상 연결은 M4.
- QA·Superpowers 문서: docs/qa/m3_3_economy_inventory.md, docs/superpowers/specs/2026-11-12-m3-3-economy.md.
- M3 전체 승인·main 병합 및 물리기기 QA 이슈 #2 종료 보류.


## 2026-11-12 M3-4 오프라인 방치 보상

- M3-3 Draft PR #20에서 분기. 종료 시각과 종료 당시 최고 클리어 스테이지를 기준으로 8시간·80% 스테이지 보상 계산.
- 시계 역행 방어·JSON 체크포인트 숫자 정규화·M3-3 거래 ID로 재수령 방지·실패 시 원본 상태 유지.
- 실제 앱 종료/복귀 이벤트와 원자적 영구 저장은 M3-5, Superdesign 기반 보상 UI 및 Windows/Android 실기기 QA는 M3-6로 분리.
- 로컬 시스템 시간 미래 조작은 완전 방어하지 못함. M3 전체 승인·main 병합 및 QA issue #2 종료 보류.
- QA: docs/qa/m3_4_offline_rewards.md / spec·plan: docs/superpowers.


## 2026-11-12 M3-5 프로필 영구 저장 및 복구

- 신규 `scripts/core/profile_store.gd`: 기존 M1 임시 저장과 별개로 성장·장비·재화 원장·방치 체크포인트를 하나의 사용자 프로필 파일에 저장.
- SHA-256 손상 확인, 검증한 임시파일·백업 파일의 rename/promote, 1세대 백업 우선 복구, revision CAS, M3 프로필 v1→v2 마이그레이션.
- M3-4 방치 지급과 M3-3 영수증을 한 파일로 영구 저장한 후 성공 반환. 서로 다른 Godot 프로세스 간 수령/중복 지급 회귀 테스트.
- **한계:** 실제 OS 종료·복귀 UI 이벤트 연결은 M3-6; 서버 시간·실제 ARM64 모바일 저장·정전 중 디스크 내구성 검증 전까지 배포 준비 완료로 보지 않음.
- QA: `docs/qa/m3_5_profile_save.md`, 계획/명세: `docs/superpowers`.
- M3 전체 승인, main 병합 및 M1 실기기 QA issue #2 종료 보류.


## 2026-11-12 M3-6 성장·장비·방치 UI

- Godot 세로형 UI 3개 탭, 8 동료 전환·레벨업/승급·인벤토리 장착/강화·방치 수령 연결. 신규 플레이어에게 임의 재화/장비 지급하지 않음.
- M3-5 실제 단일 프로필 저장으로 각 성공 거래 기록. M1 기존 디버그 화면 보존, M2 전투 화면 영향 제한.
- OS 일시정지·복귀 및 종료는 첫 M3 UI 접근 후 M3Session Autoload가 저장 체크포인트를 처리; 실제 하드웨어 QA 필요.
- Linux Xvfb 360×800 및 480×960 세 화면씩 PNG 캡처, Windows 네이티브 화면·저장 기능 회귀 및 Android ARM64 빌드 자동 검사.
- Superdesign CLI preflight 시간 초과로 실제 캔버스 시안 없음. 기존 UI 브랜드를 그대로 사용.
- 실제 Windows GUI 마우스 조작/Android ARM64 터치·safe area·한글·종료 후 재실행 검수 (이슈 #2), M4 실제 전투 보상 연동, M5 전체 UI 통합 및 M7 아트 보완 대기.
- M3 전체 승인·main 병합 보류.
