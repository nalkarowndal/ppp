# M1 Windows GUI 검증 — CI 입력 경로와 실제 화면 검증 분리

2026-11-10 · Godot 4.7.2 · 관련 [QA 이슈 #2](https://github.com/nalkarowndal/ppp/issues/2)

## 구분 (실제 Windows GUI 완료 주장 금지)

| 검증 | 실행 환경 | 범위 | 판정 |
|---|---|---|---|
| Windows EXE 생성·내보낸 EXE 실행 | GitHub-hosted Windows 러너 | EXE 내보내기와 Headless 시작 | 기존 CI PASS |
| Windows Godot UI 포인터 이벤트 | GitHub-hosted Windows 러너의 **헤드리스** Godot | `InputEventMouseButton` 이벤트를 UI로 전파, STEP/RESET/STEP/SAVE 및 새 씬에서 저장 턴 표시 | PR #8 검증 필요 |
| 실제 Windows 앱 창 조작 | **잠금 해제된 일반 사용자 데스크톱** | Win32 커서/마우스 클릭, 게임 창 스크린샷 3장, 앱 종료 후 새 프로세스 저장 복원 | **별도 수동 실행·증거 확인 필요** |
| 실제 기기별 GUI 품질 | Windows PC 여러 화면비·DPI·그래픽 드라이버 | 한글 폰트·잘림·렌더링·SmartScreen | **미검증** |

GitHub-hosted Windows 러너는 실제 사용자 데스크톱 입력이 보장되지 않으므로, 헤드리스 검증 로그를 화면 클릭 QA로 둔갑시키지 않는다.

## 준비

1. **깨끗한 Windows 사용자 계정**(Windows 10/11, 64비트, 모니터 연결 및 세션 잠금 해제)을 사용한다.
2. GitHub Actions의 `astral-chronicle-m1-windows-x64` 아티팩트에서 EXE를 내려받고 압축을 해제한다. Godot는 별도로 설치할 필요 없다.
3. 로그인 후 화면 배율을 100%로 설정하고 전체 게임 창이 모니터 안에 들어오는지 확인한다.
4. 기본 경로 `%APPDATA%\Godot\app_userdata\Astral Chronicle\astral_dev_save_v1.json`에 기존 개발 저장 파일이 있으면 다른 **전용 검수 계정**에서 진행한다. 스크립트는 기존 저장 파일이 있으면 실패하며 삭제하지 않는다.

## 실제 Windows 사용자 화면 테스트

저장소 루트에서 PowerShell 7을 실행:

```powershell
pwsh -NoProfile -File scripts/qa/windows_gui_interactive.ps1 -ValidateOnly
pwsh -NoProfile -File scripts/qa/windows_gui_interactive.ps1 `
  -ExePath "C:\path\to\AstralChronicle-M1-Windows-x64.exe" `
  -EvidenceDir ".\qa_artifacts\windows_gui"
```

이 스크립트는 먼저 실제 사용자 세션·입력 데스크톱을 검사한다. 게임을 실행하고 Godot 디버그 로그에서 버튼의 **클라이언트 영역 좌표**를 읽은 뒤 Win32 `ClientToScreen`으로 변환하여 실제 OS 마우스 커서를 이동·클릭한다. STEP→RESET→STEP→SAVE가 차례로 처리된 후 첫 프로세스를 종료하고 새로 실행한 프로세스에서 개발용 저장 턴 `1`을 검사한다.

결과 파일:
- `windows_first_process.log`, `windows_second_process.log`: UI_READY, 버튼 좌표/이벤트, 턴=1 저장 복원 로그
- `first_launch.png`, `after_save.png`, `after_restore.png`: 게임 창을 직접 캡처한 화면. 사용자 화면 일부만 잘라내며 전체 데스크톱은 캡처하지 않는다.
- `interactive_windows_qa.txt`: 실제 OS 클릭 결과 및 이벤트 로그 요약

### 통과 조건

- [ ] `WINDOWS INTERACTIVE GUI QA PASS` 로그
- [ ] 스크린샷 3장을 실제 눈으로 확인 — 한글, 텍스트 잘림·겹침, 화면 색상, 저장 성공·복원 배지
- [ ] Windows 이벤트 뷰어 또는 Godot 로그에 충돌·셰이더 오류 없음
- [ ] 100% 외 화면 배율 및 다중 모니터·저해상도 테스트
- [ ] Windows 배포 서명/SmartScreen 특성 별도 확인 (M1 빌드는 무서명 개발 빌드)

### 데이터 보호

- 스크립트는 기존 `astral_dev_save_v1.json`이 발견되면 **시작 전에 중단**한다.
- 검수로 새로 생긴 개발용 턴 파일만 종료 시 정리한다. 실제 계정 데이터 대신 **전용 QA Windows 사용자 계정**에서 실행하는 것을 권장한다.
- `-ValidateOnly`는 PowerShell 문법·Win32 P/Invoke 코드 컴파일 확인용이다. **실제 클릭/화면 테스트가 아니다.**
- 검수는 현재 M1 **디버그 턴 번호 저장**만 다루며, 전투 전체 상태 복구와 정식 백업/마이그레이션(M3)은 검증하지 않는다.

## 참고

- [Godot 4.7 Viewport.push_input](https://docs.godotengine.org/en/4.7/classes/class_viewport.html#class-viewport-method-push-input)
- [Godot 4.7 user:// Windows 위치](https://docs.godotengine.org/en/4.7/classes/class_os.html#class-os-method-get-user-data-dir)
- [Windows 대화형 러너 제약](https://github.com/tig/mcec/blob/develop/dev/self-hosted-interactive-runner.md)

Android arm64 실기기 터치·저장·안전 영역·폰트 검증 역시 별도 단계로 유지하며, **M1 최종 승인 보류**.

## 2026-11-10 내보낸 Windows EXE 입력 경로 추가 검증

- [독립 Windows EXE CI #42763935221](https://github.com/nalkarowndal/ppp/actions/runs/42763935221)에서 **실제 내보낸 EXE**를 `--headless -- --m1-windows-qa write` 및 `read`로 별도 실행: STEP→RESET→STEP→SAVE = 턴 1→0→1, 개발용 저장 파일 작성 및 새로운 EXE 프로세스에서 턴 1 복원 PASS.
- 기존 PR #8의 [Windows 헤드리스 Godot `tests/windows_pointer_ui_test.gd`](../../tests/windows_pointer_ui_test.gd)와 구분: 이번 테스트는 **에디터 엔진이 아니라 내보낸 EXE 자체**의 버튼 입력을 확인한다.
- 기존 [실제 Windows GUI harness](../../scripts/qa/windows_gui_interactive.ps1)는 보존하며, 로컬 화면 클릭·스크린샷 직접 검수 및 실제 PC GUI 통과는 별도 미완료이다.
- Android arm64 실기기 및 Windows 다중 GPU·DPI·한글 폰트도 미검증이므로 M1 최종 승인 **보류**.
