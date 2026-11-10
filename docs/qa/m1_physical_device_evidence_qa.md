# M1 실제 Windows/Android ARM64 기기 검수 — 증거 수집

Godot 4.7.2, 2026-11-10. 관련: [M1 QA 이슈 #2](https://github.com/nalkarowndal/ppp/issues/2).

## 상태와 한계

Windows EXE 헤드리스 이벤트·저장 복원 및 Android x86_64 에뮬레이터의 실제 ADB 터치 검사는 이미 CI에서 통과했다. **이는 개인 소유의 실제 Windows GUI·Android ARM64 휴대전화 검수를 대체하지 않는다.** 아래 절차는 현지 하드웨어에서 실행 후 화면·로그를 수집하기 위해 준비된 것이다.

## Windows 실제 PC GUI 검수

1. 기존 개발 저장과 분리된 Windows 10/11 x64 QA 사용자 계정, 잠금 해제된 GUI에서 진행한다.
2. [Windows Desktop Executable GitHub Actions](https://github.com/nalkarowndal/ppp/actions/workflows/m1-windows-desktop-export.yml) 최근 성공 실행의 아티팩트 astral-chronicle-m1-windows-x64에서 디버그 EXE를 다운로드한다.
3. 프로젝트 루트에서 PowerShell 7로 실행한다.

~~~powershell
pwsh -NoProfile -File scripts/qa/windows_gui_interactive.ps1 -ValidateOnly
pwsh -NoProfile -File scripts/qa/windows_gui_interactive.ps1 -ExePath "C:\QA\AstralChronicle-M1-Windows-x64.exe" -EvidenceDir ".\qa_artifacts\windows_gui"
~~~

기존 [Windows GUI 검사 도구](../../scripts/qa/windows_gui_interactive.ps1)는 **실제 Win32 커서 클릭** STEP → RESET → STEP → SAVE 및 새 프로세스에서 저장된 턴 1 복원을 확인하며 first_launch.png, after_save.png, after_restore.png 및 로그를 수집한다.

Windows PC 최종 승인 기준:
- [ ] 실제 마우스가 버튼을 클릭하여 턴 상태와 저장 라벨이 정상 변경됨
- [ ] 앱 완전 종료 후 새 프로세스에서 "이전 개발용 저장: 1턴" 표시
- [ ] PNG 3장에서 한글 깨짐(네모 글리프 포함), 잘림·겹침 없이 게임 UI 표시
- [ ] 100%, 125%, 150% 중 2개 이상 배율의 정상 렌더링 및 가능하면 다중 모니터
- [ ] 실행 충돌·그래픽 드라이버 오류 없음

**데이터 주의:** Windows 로컬 스크립트는 기존 개발용 저장이 있으면 중단한다. 기존 세이브를 보존하기 위해 전용 QA 계정에서만 실행하고 다른 작업과 동시 실행하지 않는다.

## Android 실제 ARM64 기기 검수

Python 3.11+, [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools), 실제 ARM64 휴대전화와 USB 데이터 케이블 준비. 기기에서 개발자 옵션·USB 디버깅을 활성화하고, 이 컴퓨터의 RSA 인증 요청을 휴대전화 화면에서 승인한다.

1. [Android Debug APK Actions](https://github.com/nalkarowndal/ppp/actions/workflows/m1-android-debug-build.yml) 최근 성공 아티팩트 astral-chronicle-m1-android-debug-apk에서 astral-chronicle-m1-debug.apk를 추출한다.
2. 먼저 **설치·터치하지 않는 프리플라이트** 실행:

~~~powershell
adb devices -l
py -3 scripts/qa/android_physical_device_qa.py --apk ".\astral-chronicle-m1-debug.apk"
~~~

3. 실제 전용 테스트 휴대전화이며 앱이 이전에 설치된 적 없는 것을 확인한 뒤 승인해서 실행한다.

~~~powershell
py -3 scripts/qa/android_physical_device_qa.py --apk ".\astral-chronicle-m1-debug.apk" --run
~~~

승인된 연결 기기가 복수면 --serial 옵션으로 해당 기기를 지정한다. 스크립트는 시리얼을 보고서에 기록하지 않는다.

**데이터 보호:** 앱 org.astralchronicle.prototype이 이미 설치되어 있으면 중단한다. 기존 앱 데이터 삭제·덮어쓰기·기존 앱 제거·전체 logcat 초기화·기기 화면 설정 변경을 수행하지 않는다. --run을 넣지 않는 한 APK도 설치하지 않는다.

자동 검사: 실제 ARM64 ABI·비에뮬레이터 확인, 디버그 APK 신규 설치, 최초 저장 없음, 실제 adb input tap으로 STEP(1)→RESET(0)→STEP(1)→SAVE(1), force-stop 후 **새 PID**에서 턴 1 복원. Godot DisplayServer 안전 영역·노치 컷아웃과 버튼 중심 좌표도 검사한다.

자동 증거 폴더 qa_artifacts/android_physical/run_UTC에 저장:
- 01_first_launch.png, 02_after_save.png, 03_after_restart.png
- qa_events.txt 및 첫 실행·저장·재시작 앱 QA 이벤트 로그
- metadata.json (Android 버전·모델·화면 크기·DPI·Godot 안전영역·APK SHA-256, 시리얼 제외)
- 실패 시 FAILURE.txt, failure_screen.png, failure_app_events.txt

Android 물리 기기 최종 승인 기준:
- [ ] ARM64 실기기 최초 설치·실행 및 네 번의 ADB 터치 이벤트
- [ ] 강제 종료 후 새 Android 프로세스에서 개발용 턴 1 복원
- [ ] 카메라 홀·노치·둥근 모서리·제스처 바가 글자/버튼을 가리지 않음
- [ ] 한글 문자·버튼 문구·캐릭터 이름이 잘림/대체 문자/네모 글리프 없이 읽힘
- [ ] 실제 기기 화면비·DPI별 UI, 가능하면 19.5:9 및 20:9 점검
- [ ] 셰이더 오류·충돌 없이 UI 작동

**자동 안전 영역 검사의 한계:** 버튼의 중심점이 안전 영역 안인지 확인하지만 버튼 전체가 노치와 겹치지 않는다는 것을 보장하지 않는다. 세 PNG 이미지를 사람이 직접 확인해야 한다.

## 증거 판정

| 게이트 | 자동 로그 | 사람이 검토할 증거 | 현재 |
|---|---|---|---|
| Windows 물리 GUI 마우스·저장 | 로컬 Win32 QA | PNG 3장과 입력·저장 로그 | 미실행 |
| Android 물리 ARM64 터치·복원 | 로컬 ADB QA | PNG 3장과 저장 로그 | 미실행 |
| Android 노치·안전 영역 | Godot safe-area 텔레메트리 | 실제 화면 컷아웃/텍스트 | 미실행 |
| 한글 가독성 | PNG 수집 | 사람이 글리프 확인 | 미실행 |
| Windows 다중 모니터·DPI·GPU | 일부 수동 | 화면·장치별 오류 | 미실행 |

휴대전화 상태 바 알림, 개인 파일 경로, 기타 식별 가능한 내용을 공유 전에 검토·가린다. **자동 테스트 스크립트 작성·CI 구문 통과만으로는 실제 기기 통과를 인정하지 않는다.** M1 승인 보류이며 현재 저장 시스템은 개발용 턴 번호만 포함한다.

공식 문서: [Android ADB](https://developer.android.com/tools/adb), [Godot 4.7 안전영역](https://docs.godotengine.org/en/4.7/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area), [Windows GUI 검수 안내](m1_windows_gui_qa.md).
