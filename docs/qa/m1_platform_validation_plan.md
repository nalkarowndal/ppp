# M1 플랫폼 교차 검증 — Android APK 및 Windows

- 기준 엔진: Godot 4.7.2 Stable
- 목적: GitHub Linux 런타임 성공 이후 Windows 네이티브 실행 및 Android 패키징까지 자동 증빙
- 요구 이슈: #2
- 주의: **CI 패키징 성공 ≠ Android 물리 기기 테스트 성공**

## 자동 QA

| ID | 실행 환경 | 검증 | Exit Gate |
|---|---|---|---|
| PLAT-WIN-01 | windows-latest Windows 네이티브 Godot | 프로젝트 임포트, GDScript smoke, UI 시그널, 메인 씬 헤드리스 실행 | 모두 Exit 0 + 오류 없음 |
| PLAT-WIN-02 | 별도 Windows Godot 프로세스 2회 | `user://` 개발용 저장 파일 쓰기→종료→재실행→읽기 | 저장 복구 확인 |
| PLAT-AND-01 | ubuntu-latest / Godot 4.7.2 / JDK 17 / Android SDK 35 | Android Debug APK 생성 | 비어 있지 않은 APK와 정상 종료 코드 |
| PLAT-AND-02 | Ubuntu SDK 도구 | `apksigner verify`, `aapt dump badging`, ABI 및 package 확인 | 디버그 서명 정상 및 package 일치 |

## Android 보안과 배포 설정

- 앱 식별자: `org.astralchronicle.prototype` (개발 전용)
- 서명: CI에서 만드는 **임시 디버그 키**로만 서명. 정식 배포 서명키는 저장소에 기록하지 않는다.
- APK: Android arm64 Debug, Gradle 빌드/Google Play AAB는 현재 범위 밖.
- 실제 사용자 데이터 저장/복원과 정식 서비스 보안 검증은 M3 이후 확대.
- CI의 APK artifact는 **개발·검수용**, 정식 게임 출시본이 아니다.

## 실기기 QA 체크리스트 — 미통과 항목

- [ ] 실제 Android 64비트 기기에 APK 설치·최초 실행
- [ ] 한글 UI 렌더링 및 터치 입력(턴 진행/초기화/저장)
- [ ] 노치/안전 영역 및 다양한 DPI/19.5:9·20:9 화면비
- [ ] 실제 OS 앱 종료→재실행, user:// 저장 보존
- [ ] 실기기 프레임/메모리 확인 및 오류 로그 확보
- [ ] 대상 Windows 데스크톱에서 GUI 실행 및 마우스 입력 확인
- [ ] 필요 시 재배포 가능한 한글 폰트 프로젝트 번들 채택

M1은 위 플랫폼 실기기·GUI 검수가 남아 있는 동안 최종 승인 **보류** 상태를 유지한다.

## 공식 자료

- [Godot 4.7 Android Export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)
- [Godot 4.7 CLI Export](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)
- [Godot 4.7 EditorSettings](https://docs.godotengine.org/en/4.7/classes/class_editorsettings.html)

## 2026-11-09 1차 CI 실행 결과

- **Windows CI 통과:** 공식 Godot 4.7.2 Windows 엔진으로 임포트, 수식, UI 시그널, 별도 프로세스 저장·복원, 메인 씬 헤드리스 실행 성공.
- **Android 최초 APK 실패:** SDK·JDK·디버그 서명 및 템플릿은 준비되었으나 `ETC2/ASTC texture compression is required for Android export` 오류가 발생.
- 조치: `project.godot` [rendering]의 `textures/vram_compression/import_etc2_astc=true` 추가. 이는 Android 전용 텍스처 포맷 임포트를 활성화하는 설정이며 픽셀 스프라이트에 무조건 VRAM 압축을 강제하는 것이 아님.
- 최신 CI에서 APK 생성과 서명 검증을 재확인한 뒤 승인 판정 예정.

## Android 2차 CI 결과 및 대응

- ETC2/ASTC 설정 추가 후 APK 내보내기가 압축·서명·검증 단계까지 완료되었으나, `No project icon specified`가 Godot의 `ERROR:`로 출력되어 CI 실패.
- 자체 제작 개발용 `assets/icon.svg`를 추가하고 `application/config/icon`에 지정한 다음 재검증한다.

## 2026-11-09 실제 자동검증 성공 결과

| 테스트 | 상태 | 증거 |
|---|---|---|
| Windows 공식 엔진 임포트·Smoke | **PASS** | [Windows CI #42577123154](https://github.com/nalkarowndal/ppp/actions/runs/42577123154) |
| Windows UI 버튼·개발용 저장 | **PASS** | `UI INTEGRATION PASS` |
| Windows 프로세스 완전 종료 후 저장 복원 | **PASS** | `SAVE PROCESS WRITE/READ PASS` (별도 Godot 프로세스) |
| Android APK 내보내기 | **PASS** | [Android CI #42577123146](https://github.com/nalkarowndal/ppp/actions/runs/42577123146) |
| Android 디버그 APK 서명 및 패키지 검사 | **PASS** | v2/v3 Verify; `org.astralchronicle.prototype`, `arm64-v8a` 확인 |
| Android 실제 기기에서 실행 | **NOT TESTED** | 별도 실기기 필요 |
| Windows GUI 수동 클릭 | **NOT TESTED** | Windows CI는 Headless 검증 |

**Android APK 아티팩트:** 위 성공 CI의 `astral-chronicle-m1-android-debug-apk`에서 다운로드. GitHub Actions ZIP은 일정 보관 기간 후 만료될 수 있음.

**알려진 엔진 진단:** Godot `--headless --editor --script`로 Android SDK 경로를 설정할 때, 에디터 종료 시 `RID allocations ... leaked at exit` 경고/오류가 기록됨. 실제 APK export 프로세스의 로그와 서명 검증은 성공했지만, 이 **설정 스크립트 종료 진단은 별도 개선/회귀 관리 필요**하며 실게임 런타임 오류와 혼동해서는 안 됨.

**기기 설치 주의:** 이번 테스트는 빌드마다 새 임시 디버그 키를 생성함. 기존 기기에 동일 패키지명으로 다른 키의 APK가 설치되어 있다면 삭제 후 재설치가 필요하며, 삭제 시 개발용 데이터도 사라질 수 있음.

## Windows Desktop EXE 내보내기 검증 추가

- Godot 4.7.2 공식 Windows 엔진+공식 Windows x64 Debug Export Template.
- `export_presets.cfg` 의 `Windows Desktop` 및 `binary_format/embed_pck=true` 사용, 파일은 `builds/AstralChronicle-M1-Windows-x64.exe`.
- 실제 PE (MZ) 시그니처, 별도 PCK 미생성, EXE 크기, SHA-256 및 실행 파일을 별도 `builds` 경로에서 헤드리스 실행하는지 검증.
- 통과 시 GitHub Actions `astral-chronicle-m1-windows-x64` 아티팩트 ZIP 생성.
- **남은 검증:** Windows 사용자 화면의 직접 클릭, 한글 표시, 다중 모니터/해상도, 사용자별 SmartScreen 동작 등은 자동 Headless 빌드만으로 판정할 수 없음.

## 2026-11-10 Windows EXE 본체 입력·저장 QA

- 실제 Windows x64 Debug EXE의 `--headless -- --m1-windows-qa write/read` 두 프로세스에서 Godot Viewport 마우스 입력 STEP→RESET→STEP→SAVE와 턴 1 복원 자동 테스트 성공: [Actions #42763935221](https://github.com/nalkarowndal/ppp/actions/runs/42763935221).
- Windows 엔진 GDScript 포인터 시험(PR #8)과 별도로 **사용자가 받는 EXE 본체**의 이벤트·저장을 검사한다.
- 로컬 Windows 잠금 해제된 화면에서 실제 클릭·3종 PNG 검사 미완료: [검수 절차](m1_windows_gui_qa.md). M1 최종 승인 보류.
