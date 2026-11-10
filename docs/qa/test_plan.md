# 품질관리 / 개발 검수 계획

## 검수 정책

**검증 없이 다음 단계 진행 금지**. 심각도 Blocker(실행 불가/저장 손상), Critical(재화/전투 핵심 오류), Major(핵심 UI 또는 플레이 결함), Minor(경미한 시각 문제)로 구분한다.

| ID | 종류 | 재현/판정 기준 | 현재 |
|---|---|---|---|
| QA-DATA-01 | 정적 데이터 | 캐릭터 8·스킬 명세 16·ID 및 참조 일치 | Python 검증 CI 성공 |
| QA-DATA-02 | 공식 수치 | XP(1)=120, XP(99)=40888, DAMAGE 벡터 172 | Godot Linux Smoke 통과 |
| QA-COMBAT-01 | 난수 | 동일 데이터/동일 시드 1턴 결과 일치 | 고정 시드 재현 테스트 통과 |
| QA-RUN-01 | Godot | 프로젝트 Import 및 Run 시 파싱/씬 오류 없음 | Linux 임포트 성공, Android 미검증 |
| QA-UI-01 | 모바일 | 360×800·다양한 화면비에서 잘림/겹침 없음 | 미검증 |
| QA-SAVE-01 | 재접속 | 샌드박스 턴 번호 저장·다음 실행 인식 | 헤드리스 UI 저장·다시 열기 통과, 실기기 수동 검증 필요 |
| QA-M2-01 | 자동전투 | 5명, 스킬, 버프, 승패 및 배속 | 미구현 |
| QA-M3-01 | 보상 | 8시간 상한·중복 정산 0건 | 미구현 |
| QA-M4-01 | 수직슬라이스 | 10스테이지 전투→보상→성장→저장 | 미구현 |

## 실행 절차

1. `python scripts/validate_data.py` → 오류 0.
2. `godot --headless --path . --import` → 임포트 오류 0.
3. `godot --headless --path . --script res://tests/smoke_test.gd` → SMOKE PASS.
4. `godot --path .` → 에디터 외 게임 화면, 버튼, 저장 수동 검증.
5. Windows 및 Android(별도 패키징)에서 터치·화면 비율·메모리 검수.

## 오류 추적 형식

`ID | severity | 단계 | 재현 조건 | 기대 결과 | 실제 결과 | log/screenshot | 수정 커밋 | 재검증 결과`.

## PR 게이트

CI 실패 시 병합 금지. CI 미구성 또는 실행 결과 없는 경우 **미검증**으로 표시. 수동 QA 미실행이면 마일스톤 완료 금지. 변경 후에는 실패한 테스트 + 관련 회귀 테스트를 재실행.

## 2026-11-09 M1 자동/시각 QA 결과

- 공식 Godot 4.7.2 Linux CI: Import / 계산·재현 Smoke / 버튼·저장 UI 통합 / 메인 씬 실행 모두 통과.
- Xvfb OpenGL에서 360×800·360×900 PNG 생성 및 직접 검토: 한글 정상 렌더링, 기본 UI 패널·스크롤 이상 미발견.
- 결과: https://github.com/nalkarowndal/ppp/actions/runs/42575430523
- 상세: [M1 실행 QA](m1_runtime_validation.md).
- 미완료: Android APK 실기기, 실제 터치, 앱 완전 재시작, 기기별 한글 글꼴. 따라서 M1 승인 게이트 **미통과**.

## M1 Windows/Android 플랫폼 CI 추가 검증 (2026-11-09)

- Windows Godot 4.7.2 native `--import`, Smoke, UI 테스트: PASS.
- OS 프로세스가 완전히 종료된 이후 별도 프로세스에서 `user://` 디버그 저장 복원: PASS. 이는 Android 기기 재실행 검증을 대체하지 않음.
- Android arm64 Debug APK 생성/서명/패키지: PASS, **실기기 설치 및 동작은 미검증**.
- 워크플로우: [Windows](https://github.com/nalkarowndal/ppp/actions/runs/42577123154), [Android](https://github.com/nalkarowndal/ppp/actions/runs/42577123146).
- M1 최종 승인: **보류** (Android 실기기, 터치·안전 영역, 플랫폼 글꼴, Windows 수동 GUI 포함).

## 2026-11-10 M1 Android 에뮬레이터 UI QA

- 공식 Godot 4.7.2 x86_64 Debug APK와 Android 35 AOSP 에뮬레이터 SwANGLE: 설치·실행·강제 종료 후 재실행 **PASS**.
- 1080×1920 두 화면 PNG 직접 검토, M1 UI 한글 및 패널 렌더 **PASS** (에뮬레이터 한정).
- 검사 기록: [Actions #42727828387](https://github.com/nalkarowndal/ppp/actions/runs/42727828387), [자세한 검수](m1_android_emulator_qa.md).
- M1 최종 승인은 **보류**: Android 실제 기기·터치/저장 동작·안전 영역, Windows GUI, 폰트 번들 확인이 필요함.

## M1 Android 실제 터치 및 저장 복원 자동화

- [x] Android 35 x86_64 에뮬레이터 UI STEP→RESET→STEP→SAVE 실제 `adb shell input tap` 동작 확인
- [x] 에뮬레이터 `pm clear` 후 무저장 초기값 및 `am force-stop` 이후 저장된 턴=1 복원
- [x] QA 로그·화면 PNG 보관 및 Android 치명 오류 확인 ([Actions #42760648521](https://github.com/nalkarowndal/ppp/actions/runs/42760648521))
- [ ] 실제 arm64 기기의 터치·안전 영역·한글·성능 수동 검증 (CI로 대체 불가)

검증 코드: `scripts/qa/android_emulator_interaction.sh`, `scripts/ui/main_ui.gd`. CI 통과 전에는 미검증 상태다.

## Windows 내보낸 EXE 자체 포인터 검증 (2026-11-10)

- [x] 실제 EXE Debug 빌드 `write` 프로세스의 STEP→RESET→STEP→SAVE, 상태·개발용 파일 기록 확인
- [x] 실제 EXE Debug 빌드 `read` 독립 프로세스에서 저장된 턴 1 확인 (기준 성공 [Actions #42763935221](https://github.com/nalkarowndal/ppp/actions/runs/42763935221))
- [ ] 실제 Windows 사용자 화면에서 Win32 마우스 클릭 및 PNG 직접 검수, 다중 모니터/DPI·한글 검수
- [ ] Android arm64 실기기 테스트

상세: [M1 Windows GUI QA](m1_windows_gui_qa.md). CI 헤드리스 통과만으로 M1 승인하지 않는다.
