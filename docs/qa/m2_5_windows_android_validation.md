# Astral Chronicle M2-5 Windows/Android 플랫폼 QA (2026-11-11)

**브랜치:** `feature/m2-5-platform-qa` (M2-5 Draft PR #16 기반).  
**중요:** 이 보고서에서 Windows/GitHub Runner, Android x86_64 에뮬레이터, ARM64 APK 생성 및 **실제 Windows PC / Android ARM64 실기기**는 서로 다른 검수 등급입니다. 물리 실기기 검수는 아직 하지 않았으며 M1 issue #2는 열려 있습니다.

## 수행된 검수 범위 및 근거

| 검수 종류 | 실행 방식과 실제 확인 | 결과/한계 |
|---|---|---|
| Windows 네이티브 Godot 4.7.2 | `windows-latest`에서 `tests/m2_battle_ui_test.gd` 실제 엔진 실행. M1 레거시 및 M2-5 전투 UI, AUTO, 배속, 궁극기, 재시작 | PASS. 창이 열린 실제 물리 Windows 마우스 검수 **아님** |
| Windows 내보내기 EXE | `AstralChronicle-M1-Windows-x64.exe`(실행 파일에 PCK 포함)을 Windows Runner의 새로운 프로세스로 실행. `--m2-windows-qa` 인자를 통한 내장 M2 씬 로드, 3v3 초기화, AUTO/배속, 20틱 전투, 리셋 | PASS. EXE 리소스/버튼 시그널 및 네이티브 런타임 검증, **headless** |
| Android x86_64 에뮬레이터 | Android 15/API35, x86_64, 실 Android APK 설치·실행, `adb shell input tap/swipe`로 M1 저장/재실행 및 M2-5 버튼 탐색/진입·AUTO OFF·속도 2×·재시작·복귀. M2 네 장 PNG 수집 | PASS. Google Android Emulator이며 **실제 ARM64 스마트폰 아님** |
| Android ARM64 APK 내보내기 | Android SDK35, arm64-v8a, 디버그 서명/패키지/ABI 검증 | PASS. **실기기 실행을 의미하지 않음** |
| Linux Xvfb 시각 테스트 | M2-5 이전 UI 검수의 360×800·480×960 Godot 렌더러 스크린샷 | PASS. Windows GUI/Android 물리 검수 아님 |
| 실제 Windows 로컬 PC | 잠금 해제된 PC에서 Win32 물리 포인터 클릭·실제 출력 캡처 | **미실행 / 보류** |
| 실제 Android ARM64 휴대전화 | 기기 터치·절전 복귀·노치/안전 영역·한글·앱 완전 종료 후 저장 복원 | **미실행 / 보류** |

### 검증의 주요 증거

- **Android RED**: [CI #42986160971](https://github.com/nalkarowndal/ppp/actions/runs/42986160971) — M1 에뮬레이터 앱 설치·첫 화면·실제 ADB 터치 저장/복원은 PASS, M2 진입은 `M2_5_QA_TARGET ENTER` 부재로 FAIL.
- **Android GREEN**: [CI #42986860654](https://github.com/nalkarowndal/ppp/actions/runs/42986860654) — 앱 런타임의 실제 화면→픽셀 변환으로 아래 버튼을 누름:
  - `ENTER x=530 y=1690` → `M2_5_BATTLE_READY allies=3 enemies=3`
  - `AUTO x=467 y=1716` → `M2_5_QA_ACTION AUTO enabled=0`
  - `SPEED x=954 y=1716` → `M2_5_QA_ACTION SPEED value=2`
  - `RESTART x=1001 y=86` → `M2_5_QA_ACTION RESTART ticks=0`
  - `BACK x=110 y=86` → `M2_5_QA_ACTION BACK` 및 재진입된 `M1_UI_READY`
- 에뮬레이터 PNG `m2/01_m1_relaunch.png`, `m2/02_m2_battle_initial.png`, `m2/03_m2_controls_after_touch.png`, `m2/04_m1_return.png`는 **1080×1920**. 실제 다운로드 후 이미지 02, 03을 육안 점검하여 한글 캐릭터/상태 텍스트, HP, 기력 및 AUTO OFF·2× 반영을 확인함. **포함된 로그와 화면은 x86_64 에뮬레이터 전용**.
- **Windows native**: [CI #42986160906](https://github.com/nalkarowndal/ppp/actions/runs/42986160906) — 실제 Windows-native Godot CLI에서 M2-5 UI 테스트 통과.
- **Windows embedded EXE**: [CI #42986956434](https://github.com/nalkarowndal/ppp/actions/runs/42986956434) — `verify-windows`에서 M1 새 프로세스 저장 복원 및 `M2_5_WINDOWS_EXE_QA_PASS`.
- **추가 안전 게이트:** `tests/test_m2_emulator_guard.py`는 x86_64 에뮬레이터 전용 ADB 스크립트에 가짜 **실물 휴대전화** 정보를 주입하여, 앱 설치·터치뿐 아니라 **화면 캡처/로그캣 수집도 없이 즉시 종료**하는지 확인함.
- 최종 브랜치 HEAD에 대한 각 CI의 성공 여부는 항상 GitHub Actions에서 해당 커밋 SHA로 별도 확인. 특정 이전 실행을 새 SHA 성공 증거로 오인하지 말 것.

## 실제 구현된 QA 계측·경계

- `scripts/ui/main_ui.gd`: M1 SAVE 아래 **M2-5 전투 프리뷰 진입 버튼**의 위치를 `M2_5_QA_TARGET ENTER`로 보고. 기존 M1 STEP/RESET/SAVE 및 저장 상태 변경 없음.
- `scripts/ui/battle_ui.gd`: `M2_5_QA_TARGET BACK/RESTART/AUTO/SPEED/MOTION`를 보고. 좌표는 `get_viewport().get_screen_transform() * button.get_global_transform_with_canvas() * (button.size*0.5)`; 스크롤 영역 클리핑을 고려해 `visible` 기록. `M2_5_QA_SAFE_AREA`와 `M2_5_QA_SCREEN`도 기록. 디버그 실행에서만 계측; 좌표를 임의로 만들어내지 않음.
- `scripts/qa/android_emulator_m2_battle.sh`: `ro.kernel.qemu=1`, x86 ABI 가드 **이후에만** 스크린샷·로그·ADB 터치. Android ARM64 물리 기기에서 실행하지 않는 검수 도구. 이미 통과한 M1 저장값을 지우지 않고 M2-5를 이어 검수.
- `scripts/ui/main_ui.gd` 디버그 인자 `--m2-windows-qa`: **배포된 EXE에 포함된 실제 전투 PackedScene**을 실행, 버튼 시그널/전투 틱을 검증 후 종료. 실제 포인터 입력이나 Windows GUI 렌더링을 확인하는 기능이 아님.
- `test_m2_emulator_guard.py`: 물리 기기를 모사한 가짜 adb 검수로 실물 보호 정책을 테스트.

## Windows 물리 GUI — 재현 절차 (미승인)

테스트 전용 Windows 10/11 x64 사용자 계정의 잠금 해제된 데스크톱에서만 다음을 진행:

1. 성공한 `M1 Windows Desktop Executable` Actions의 `astral-chronicle-m1-windows-x64` 아티팩트를 내려받아 테스트 전용 폴더에 압축 해제.
2. `pwsh -NoProfile -File scripts/qa/windows_gui_interactive.ps1 -ValidateOnly`로 Win32 interop 사전 점검. 실제 검증은 `-ExePath "C:\QA\AstralChronicle-M1-Windows-x64.exe" -EvidenceDir ".\qa_artifacts\windows_gui"` 옵션으로, 저장 충돌이 없는 **전용 QA 계정**에서 실행. M1 자동화에서 PNG/STEP·SAVE·프로세스 재진입 기록 확인.
3. M2-5는 별도 GUI로 실행해 **M2-5 전투 화면 열기** 클릭, HP/기력/한글/상태이상, AUTO ON/OFF, 배속 1×→2×→3×, 수동 궁극기(100 기력), 재시작, 복귀까지 *물리 마우스*로 조작하고 단계별 스크린샷 저장.
4. 100%/125%/150% 중 2가지 DPI와 최소 2가지 화면비에서 글자 잘림·버튼 반응·물리 마우스 좌표·앱 강제 종료/재실행을 확인하고, 그래픽 오류가 없다는 로그를 수집.

이 절차를 **작성했다는 이유로 Windows 물리 GUI PASS를 선언하지 않음.**

## Android ARM64 실기기 — 재현 절차 (미승인)

1. 실물 **ARM64** 테스트 전용 Android 기기에서 개발자 옵션/USB 디버깅을 허가하고 `adb devices -l`을 확인. 다른 사용자 앱이나 기존 저장을 건드리지 말 것.
2. GitHub Actions `M1 Android Debug APK Export` 성공 실행의 `astral-chronicle-m1-android-debug-apk`를 내려받고 `py -3 scripts/qa/android_physical_device_qa.py --apk ".\astral-chronicle-m1-debug.apk"`로 **읽기 전용 사전 검사**를 먼저 수행.
3. 기존 테스트 패키지가 **전혀 설치되지 않은 전용 기기**에서만 승인 후 `--run`으로 M1 설치·탭·종료/복원 검수. 스크립트는 설치된 앱을 발견하면 덮어쓰지 않고 중단.
4. M2-5 전투 화면으로 이동해 손가락으로 AUTO, 배속, 재시작, 복귀를 조작하고 다양한 텍스트 및 상태아이콘을 확인. 실제 노치/카메라 홀/제스처 영역과 `M2_5_QA_SAFE_AREA` 로그를 대조. 버튼 **전체 경계**가 안전 영역에 드는지 이미지에서 직접 확인.
5. 실제 화면(초기, 전투, 조작, 복귀), DPI/해상도/OS/모델(일반 정보), 앱 완전 종료/복원 로그, 한글 가독성·그래픽 오류를 기록. 개인 정보와 기기 ID는 가리고 제출.

**실물 기기에서 Android ARM64 전투·저장 화면까지 승인되지 않았으므로 M1 issue #2는 닫지 않음.**

## 최종 판정 원칙

- 이번 검수는 **Windows CI 및 Android x86_64 에뮬레이터에서의 실행/입력 QA**에 한함.
- 스크린샷 육안 검수는 해당 에뮬레이터 1080×1920 구성에서만 수행. 실물 기기의 한글·안전 영역, 다양한 성능/발열/배터리, 실제 로컬 Windows GUI는 별도 필요.
- 캐릭터 그래픽은 M2-5 개발용 카드이며 최종 아트·VFX/오디오 등 정식 게임 기능이 아님.
- M2-5 / M1 QA 서명·배포/보안 완성, 정식 출시·main 병합은 이 검수에서 승인하지 않음.

[기존 M1 물리 기기 검수 지침](m1_physical_device_evidence_qa.md) · [M2-5 기능 QA 보고서](m2_5_battle_ui.md) · [M1 실제 기기 QA issue #2](https://github.com/nalkarowndal/ppp/issues/2)
