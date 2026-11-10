# ASTRAL CHRONICLE (아스트라 크로니클)

서브컬처 캐릭터 수집 × 픽셀아트 × 방치형 RPG. Godot 4 기반 게임 개발 프로젝트입니다.

> 현재 상태: **M1 플랫폼 자동 검증 완료 범위는 있으나 실제 Windows/Android ARM64 기기 최종 QA 보류**. 별도 Draft PR #12에서 M2-1 자동전투 코어를 개발·검증 중입니다. 전체 게임이나 MVP가 구현된 상태가 아닙니다.

## 시작하기

1. Godot 4.7.2 stable에서 이 디렉터리의 `project.godot`을 열어 실행합니다.
2. 별도의 에셋 없이 동작하는 **개발용 UI/데이터 샘플**을 확인합니다.
3. Godot CLI: `godot --headless --path . --import`, `godot --headless --path . --script res://tests/smoke_test.gd`.
4. 정적 데이터 검증: `python scripts/validate_data.py` (Python 3.11+).

## 문서

- [GDD](docs/01_gdd/game_design_document.md)
- [UI/UX 설계](docs/02_ui_ux/design_system.md)
- [전투·성장 명세](docs/03_game_systems/system_balance.md)
- [Godot 로드맵](docs/04_roadmap/development_roadmap.md)
- [기술 결정/단계 통과 조건](docs/technical/technical_decisions.md)

## 첫 단계 완료 기준

M0: 엔진·플랫폼·문서·QA 기준 정리. M1: 데이터·씬·UI·저장 기반 구축 후 실제 Godot CLI 및 실행 화면 검증. 검증 결과 없이 완료로 표시하지 않습니다.

## 저작권 및 아트

현재 저장소의 UI는 플레이스홀더입니다. 타 게임의 그래픽을 그대로 복제하거나 출처 불명 에셋을 포함하지 않습니다.

## M1 플랫폼 QA / 디버그 빌드

GitHub Actions에서 Godot 4.7.2의 Linux·Windows 엔진 테스트 및 Android **arm64 개발용 APK** 내보내기를 검사합니다.

- [Windows 네이티브 스모크/프로세스 간 저장 테스트](https://github.com/nalkarowndal/ppp/actions/workflows/m1-windows-platform.yml)
- [Android 디버그 APK 생성](https://github.com/nalkarowndal/ppp/actions/workflows/m1-android-debug-build.yml)
- [플랫폼 검수 범위·실기기 체크리스트](docs/qa/m1_platform_validation_plan.md)

APK 다운로드: 위 Android workflow에서 성공한 실행을 열고 **Artifacts → astral-chronicle-m1-android-debug-apk**를 내려받아 ZIP 안의 `astral-chronicle-m1-debug.apk`를 확인합니다. 디버그 APK는 **게임 데모·정식 배포본이 아니며**, 임시 UI와 1턴 샌드박스만 포함합니다. CI 빌드마다 임시 디버그 키가 달라 기존 앱 업데이트 설치에 실패할 수 있으므로 개발용 기기에서 기존 앱을 삭제하고 설치해야 할 수 있습니다.

## Windows 데스크톱 실행 파일

Godot 없이 실행할 수 있는 Windows x64 개발용 `.exe`가 GitHub Actions로 자동 빌드됩니다.

- [Windows Desktop Executable 빌드](https://github.com/nalkarowndal/ppp/actions/workflows/m1-windows-desktop-export.yml)에서 성공 실행의 `astral-chronicle-m1-windows-x64` 아티팩트 ZIP 다운로드
- ZIP을 해제한 뒤 `AstralChronicle-M1-Windows-x64.exe` 실행
- Godot 게임 리소스는 실행 파일에 포함되어 있어 별도 `.pck` 파일이 필요하지 않습니다.
- **주의:** 개발용 디버그 실행 파일이며 코드 서명되지 않았습니다. Windows SmartScreen 경고가 표시될 수 있습니다. 정식 게임/완성 MVP가 아닙니다.
- [플랫폼 검증 계획 및 남은 실기기 QA](docs/qa/m1_platform_validation_plan.md)

## Windows EXE 실제 포인터 입력 자동검증

[Windows EXE Actions](https://github.com/nalkarowndal/ppp/actions/workflows/m1-windows-desktop-export.yml)는 **내보낸 EXE 자체**를 두 번 실행해 헤드리스 포인터 STEP→RESET→STEP→SAVE 및 저장 후 새로운 프로세스에서 턴 1 복원을 검사합니다. 실제 PC 화면·마우스 직접 검수는 [Windows GUI QA 지침](docs/qa/m1_windows_gui_qa.md)의 수동 절차를 따릅니다. 헤드리스 PASS는 Windows GUI 최종 PASS가 아닙니다.

## M1 실제 Windows PC 및 Android ARM64 기기 검수

[실제 기기 QA 준비 및 증거 수집 절차](docs/qa/m1_physical_device_evidence_qa.md)에 Windows GUI 직접 클릭/캡처와 실제 USB 연결 Android ARM64 휴대전화 터치·저장 복원·안전 영역·한글 검수 방법을 정리했습니다.

- Windows: 기존 `scripts/qa/windows_gui_interactive.ps1`를 실제 **잠금 해제된 QA 계정**에서 실행해야 합니다.
- Android: `py -3 scripts/qa/android_physical_device_qa.py --apk "path-to-debug.apk"`로 안전한 연결 확인 후, 전용 물리 테스트 기기에서만 `--run`으로 설치/터치 검수를 승인합니다.
- 휴대전화에 같은 앱이 이미 설치되어 있으면 데이터를 덮어쓰지 않도록 자동으로 중단합니다. 물리 기기 검수 기록은 CI 검사와 엄격히 구분합니다.

**이 도구들이 저장소에 포함된 것만으로 실제 하드웨어 QA가 완료된 것은 아닙니다.** 실제 PC/휴대전화에서 생성한 PNG·입력 로그의 검토 전 M1 최종 승인은 보류합니다.

## M2-1 고정 틱 자동전투 실험 브랜치

- [Draft PR #12](https://github.com/nalkarowndal/ppp/pull/12)에서 M1 디버그 샌드박스와 분리된 20Hz 기본 공격 자동전투 코어를 검증합니다.
- 실행: `godot --headless --path . --script res://tests/m2_combat_core_test.gd` (해당 브랜치에서 실행).
- [M2-1 구현 범위 및 남은 승인 조건](docs/qa/m2_1_combat_core.md) 참고. 스킬·상태이상·실제 전투 화면은 후속이며, 현재 M2 전체 마일스톤은 미완료입니다.
