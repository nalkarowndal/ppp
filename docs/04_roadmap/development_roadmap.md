# Godot 개발 로드맵 / 마일스톤 승인 조건

**Version:** v1.0. 시작일 2026-11-09. MVP는 8 캐릭터 / 40 스테이지 / 2 보스 / 2 성장 던전 / 기본 거점 1개.

## 진행 현황

| Milestone | 목표 | 현 상태 |
|---|---|---|
| M0 | 기술 결정·GDD/QA 문서·Git 저장소 준비 | 문서·환경 기준 수립; Linux Godot 실행 CI 통과, Android 검증 필요 |
| M1 | 씬·로더·저장·임시 UI 기초 | 임시 씬·로더·UI·저장 구현, Linux CI와 360×800/900 렌더 검증 통과; Android 수동 QA 미통과(승인 보류) |
| M2 | 3인+보스 전투 코어·상태이상·자동 AI | 미시작; M1 턴 샌드박스는 별도 |
| M3 | 1~100 레벨·승급·장비·재화·8h 방치 | 미시작; 수식 함수·데이터 일부만 존재 |
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
