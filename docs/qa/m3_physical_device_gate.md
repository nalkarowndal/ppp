# M3 Windows·Android ARM64 실기기 QA 승인 게이트

2026-11-12 · Godot 4.7.2 · feature/m3-physical-qa-readiness

## 현재 판정

**M3 코드 및 GitHub Actions 자동 테스트는 통과. 실제 Windows 사용자 PC GUI와 Android ARM64 물리 단말 검수 증거는 없음. M3 전체 승인 보류.**

GitHub-hosted Windows runner는 사용자의 물리 PC 모니터·마우스·GPU를 검증하지 못한다. Android ARM64 APK 내보내기와 Android x86_64 에뮬레이터도 실제 ARM64 휴대전화 테스트를 대체하지 않는다.

| 확인 항목 | 현재 판정 | 근거 |
|---|---|---|
| Godot M3-1~6, 경제원장, 저장, 보상, 성장/장비 UI | 자동 PASS | GitHub Actions |
| 방치 보상 미수령 후 재백그라운드 손실 | 재현 RED → 수정 GREEN | tests/m3_pending_idle_lifecycle_test.gd |
| Windows 네이티브 엔진, EXE export | 자동 PASS | Windows runner, headless |
| Android arm64 debug APK ABI/서명 | 자동 PASS | Export workflow |
| Windows 물리 GUI 클릭, DPI, GPU, 한글 | **NOT RUN** | 실제 PC 필요 |
| Android ARM64 실제 터치, 노치, 한글 | **NOT RUN** | 실제 단말 필요 |
| Android 백그라운드·강제 종료 후 프로필/영수증 | **NOT RUN** | 실제 단말 필요 |
| 실제 전투에서 획득한 보상으로 성장/강화 | **M4 미구현** | 실게임 루프 연동 필요 |

## 1. 정확한 QA 빌드

반드시 feature/m3-physical-qa-readiness 브랜치 **최종 커밋**의 성공한 GitHub Actions에서 다운로드한다. 이름은 오래된 M1 이름을 사용하지만 해당 브랜치에서 빌드한 EXE/APK에 M3 UI가 포함된다. main의 M1용 바이너리나 다른 커밋의 산출물로 M3를 검수하면 무효다.

- Windows: M1 Windows Desktop Executable → astral-chronicle-m1-windows-x64 → AstralChronicle-M1-Windows-x64.exe
- Android: M1 Android Debug APK Export → astral-chronicle-m1-android-debug-apk → astral-chronicle-m1-debug.apk
- 증거에는 브랜치 SHA, EXE/APK 해시, OS 및 기기 모델을 함께 기록한다. Actions 아티팩트는 만료될 수 있다.

## 2. Windows 실제 사용자 데스크톱 검수

Windows 10/11 x64, PowerShell 7, 보이는 잠금 해제 데스크톱, **전용 Windows QA 사용자 계정**이 필요하다. 기존 M3 저장 파일이 있을 경우 스크립트는 시작 전 종료하여 기존 진행도를 보존한다.

저장소 루트의 PowerShell에서 실행:

~~~powershell
pwsh -NoProfile -File scripts/qa/m3_windows_physical_qa.ps1 -ValidateOnly
pwsh -NoProfile -File scripts/qa/m3_windows_physical_qa.ps1 -ExePath "C:\QA\AstralChronicle-M1-Windows-x64.exe" -EvidenceDir ".\qa_artifacts\m3_windows_physical"
~~~

검수자는 실제 마우스로 M1→M3 진입 후 성장/장비/방치 탭을 열고 8명 전환, 한글, 장비 4개 슬롯, 빈 인벤토리 및 0재화 상태, 스크롤·클리핑, 버튼 상태를 확인한다. 화면별 PASS/FAIL을 직접 입력한다. 스크립트는 전체 데스크톱이 아닌 **게임 창만** PNG 캡처하고 정상 종료/재실행 뒤 M3 프로필 체크섬·schema_version·8명 캐릭터를 검증한다.

증거: 01_growth.png, 02_gear.png, 03_idle.png, 04_restart.png, first.log, restart.log, acceptance.txt.

이 스크립트는 실제 물리 PC에서 실행해야 하며, CI의 -ValidateOnly 통과는 PowerShell 문법·Win32 API 선언 검증일 뿐 물리 Windows QA가 아니다. 기존 M1의 자동 Win32 클릭 검증은 scripts/qa/windows_gui_interactive.ps1에 별도 존재한다. 처음 시작 시 재화가 0이므로 **유료 성장/강화 성공을 이 시나리오만으로는 검증할 수 없다.**

## 3. Android ARM64 물리 휴대전화 검수

ARM64 폰, USB 디버깅 승인, Android SDK Platform Tools(adb), Git Bash 또는 Linux/WSL Bash가 필요하다. 검수 전용 폰 사용을 권장한다.

~~~bash
adb devices -l
bash scripts/qa/m3_android_arm64_physical_qa.sh --validate-only
bash scripts/qa/m3_android_arm64_physical_qa.sh --serial "물리_ADB_시리얼" --apk "builds/astral-chronicle-m1-debug.apk" --install --execute --allow-force-stop
~~~

선택한 기기의 ADB 권한, 비에뮬레이터와 arm64-v8a ABI를 검사한다. APK 업데이트는 사용자가 INSTALL이라고 명시적으로 입력해야 수행한다. 앱 기존 데이터는 삭제하지 않지만 업데이트할 수 있으므로 별도 시험 기기/검수 프로필을 사용한다.

검수자는 직접 스마트폰을 터치해 M1→M3 이동, 성장/장비/방치 화면의 노치·상태바·내비게이션 바·한글 가독성, 터치 영역을 확인해 PASS/FAIL을 입력한다. ADB HOME→복귀 후 다시 검사하고, 선택적으로 FORCE를 입력한 경우 해당 게임 패키지만 force-stop → 신규 프로세스 재실행한다.

**절대 하지 않는 작업:** pm clear, 앱 데이터 삭제, uninstall, 다른 앱 설정 변경, 전체 logcat 초기화.

증거: 01_growth.png, 02_equipment.png, 03_idle.png, 04_resume.png, 선택적 05_force_restart.png, godot_filtered_logcat.txt, acceptance.txt.

이 스크립트는 실제 기기 스크린샷과 사람이 기록한 판정을 모은다. 금전성 재화를 지급하는 QA 모드는 제공하지 않으므로 경제 원장 영수증·실제 획득 보상 검증은 별도 QA 프로필/후속 플레이테스트가 필요하다. 파일이 보이지 않는 기기의 UI 재실행만으로 전체 디스크 원자성까지 증명하지 않는다.

## 4. 재현한 방치 체크포인트 결함과 수정

미수령 보상이 있는 T0 시점 앱 종료 → 1시간 뒤 복귀 → 수령 없이 다시 백그라운드 → 1시간 뒤 복귀 시 기존 구현은 방치 시작 시간이 덮어써져 최대 2시간 보상(스테이지1 320골드) 대신 1시간분(160골드)만 남을 수 있었다.

- 테스트 먼저 작성: tests/m3_pending_idle_lifecycle_test.gd 의도적 RED 검출.
- 수정: 기존 미수령 체크포인트를 유지한다. 성공 수령한 현재 세션에서만 다음 실제 OS 백그라운드로 새로운 체크포인트가 기록된다. 수령 직후 플레이 중에는 추가 방치 보상 청구 불가.
- GREEN: 방치 시간 누적, 별도 컨트롤러 재실행 후 저장, 영수증 중복, 추가 세션 보상과 M1/M2/M3 회귀 검증.
- 한계: 서버 시간 조작 방지, OS가 알림 없이 강제 종료하는 경우, 앱 최초 M3 화면 진입 전 세션 체크포인트, 저장 중 정전 보호는 아직 보장하지 않는다.

## 5. 승인 절차

검수 결과를 QA issue #2에 스크린샷·요약 로그·기기 모델 및 OS/DPI/해상도·커밋 SHA와 함께 첨부한다. 장치 일련번호, 개인 알림 및 계정/기타 민감정보를 공유 전에 가린다.

M3 최종 승인 조건:
1. 실제 Windows PC에서 마우스/스크롤/DPI/한국어/프로필 저장 후 새 프로세스 복원 PASS와 증거.
2. 실제 Android ARM64 폰에서 터치·노치 안전영역·한글·백그라운드·종료 후 복원 PASS와 증거.
3. 필요한 QA용 충분한 재화/장비와 원장 중복 방지, 레벨업·강화 등 실거래까지 실제 기기에서 확인.
4. Blocker/Critical 0, CI 최종 통과, 각 단계 PR 코드 리뷰 후 승인.

**현 상태: QA PREPARED; REAL HARDWARE NOT RUN; M3 APPROVAL BLOCKED. main과 기존 QA 이슈 #2는 변경/종료하지 않는다.**
