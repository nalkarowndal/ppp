# M1 Windows 독립 실행 파일 — 포인터 입력·저장·실제 데스크톱 GUI 검증

작성 기준: 2026-11-10, Godot 4.7.2 Debug Export, [M1 QA 이슈 #2](https://github.com/nalkarowndal/ppp/issues/2).

## 검증 계층과 판정 기준

| 단계 | 실행 환경 | 검증 방식 | 완료 조건 |
|---|---|---|---|
| WIN-01 | Windows GitHub Actions | 공식 Godot 4.7.2로 임포트, GDScript/데이터 테스트 | 0 exit, 스크립트 오류 없음 |
| WIN-02 | Windows GitHub Actions | **실제 내보낸 EXE**를 `--headless` 실행 | PE 구조·외부 PCK 없음, 실행 0 exit |
| WIN-03 | Windows GitHub Actions | **실제 내보낸 EXE**에 `Viewport.push_input`으로 마우스 누름/뗌 입력, STEP→RESET→STEP→SAVE | 앱 내부 턴 1→0→1, 파일 쓰기 성공, 두 번째 EXE 프로세스에서 턴 1 복원 |
| WIN-04 | **사용자 Windows 10/11에서 열린 인터랙티브 데스크톱** | Win32 커서 입력·창 캡처·실제 버튼 클릭 및 재실행 | screenshot 초기/저장/복원, 터치 좌표/로그, 사용자 시각 검수 |
| WIN-05 | 사용자 PC 환경 | 한글 폰트, 여러 DPI/모니터, 리사이즈, 키보드/마우스, GPU 호환성 | 별도 실기기 체크리스트 |

**구별:** WIN-03은 Windows 실행 파일 자체를 테스트하지만 `--headless`이므로 사용자의 실제 디스플레이·드라이버·마우스 입력을 검증하지 않는다. WIN-04는 실제 사용자의 **잠금 해제된 Windows 세션**에서 실행해야 한다. GitHub 호스팅 `windows-latest` 러너의 Session-0 등 제한으로 **WIN-04를 CI 통과로 간주하지 않는다.**

## Windows EXE GUI 직접 검증 실행

1. [Windows Desktop Executable Actions](https://github.com/nalkarowndal/ppp/actions/workflows/m1-windows-desktop-export.yml)의 가장 최근 성공 실행에서 `astral-chronicle-m1-windows-x64` ZIP을 다운로드하고, `AstralChronicle-M1-Windows-x64.exe`를 로컬에 압축 해제한다.
2. [GitHub 저장소](https://github.com/nalkarowndal/ppp)에서 코드 ZIP을 내려받거나 Git으로 복제해 `scripts/qa/windows_gui_interactive.ps1`를 사용한다. **스크립트 내용을 확인**하고 신뢰할 수 있는 개발용 EXE에만 적용한다.
3. Windows 데스크톱에 로그인한 상태로 화면 잠금을 해제하고, 화면을 덮는 팝업이나 다른 앱은 닫는다. 자동 검사가 마우스를 직접 움직이므로 검사 동안 수동 마우스 입력을 중단한다.
4. 프로젝트 루트에서 다음을 실행한다.

```powershell
pwsh -NoProfile -File .\scripts\qa\windows_gui_interactive.ps1 `
  -ExePath ".\builds\AstralChronicle-M1-Windows-x64.exe"
```

PowerShell 7이 없다면 Windows PowerShell 5.1에서도 파일 경로를 지정해 실행할 수 있다(실행 정책은 사용자의 조직 정책을 따른다). 성공 시 `qa_artifacts/windows_gui/run-<timestamp>-<id>/` 내부에 다음 결과가 남는다.

- `windows-gui-e2e-report.txt`: 실제 클릭, 스크린샷, PID 전환, 복원 여부
- `initial.log`, `after_restart.log`: Godot 로그, UI 좌표, 버튼 상태
- `initial.png`, `after_save.png`, `after_restart.png`: 화면 캡처
- `isolated_appdata/`: 테스트용 `user://` 저장 데이터

**사용자 데이터 보호:** 검수 스크립트는 실행한 Windows 프로세스에만 별도 `APPDATA` 환경변수를 지정하며, Godot가 출력한 실제 `user://` 저장 경로가 해당 테스트 디렉터리 안인지 확인한다. 경로가 다르면 **클릭이나 저장하기 전에 실패**하므로 기존 개발 세이브를 덮어쓰지 않는다. 테스트 디렉터리 외부의 사용자 데이터는 지우지 않는다.

## 판정 및 증거 제출

- 앱 제목·한글 텍스트 가독성, 버튼 클릭 전후의 턴 상태, 패널 겹침·잘림·프레임 비율을 PNG 3장으로 직접 확인한다.
- 기본 시나리오는 STEP(턴 1)→RESET(턴 0)→STEP(턴 1)→SAVE, 게임 종료 후 완전히 새 PID에서 저장 1턴 표시 확인이다.
- Windows 그래픽 드라이버에 따라 창 캡처에 검은 화면/드라이버 오류가 발생하면 실패로 보고 원본 로그·스크린샷을 이슈 #2에 첨부한다.
- 캡처에는 다른 데스크톱 창/개인 정보가 포함될 수 있으므로 공유 전에 반드시 확인하고 필요하면 민감정보를 가린다.
- 현재 M1은 **개발용 턴 번호만 저장**하며, 전투 전체 상태/원자적 백업/마이그레이션은 정식 저장 시스템(M3)에서 구현한다.

## 남은 M1 승인 게이트

- [ ] WIN-04 실제 잠금 해제된 Windows GUI에서 마우스 클릭, PNG 및 저장 재실행 검수
- [ ] WIN-05 서로 다른 DPI·모니터·키보드/마우스·GPU 드라이버 및 한글 폴백 검수
- [ ] 실제 Android arm64 휴대전화에서 설치·터치·안전영역·저장·프레임 성능 검수

최종 M1 승인 **보류**. M2 자동전투 본 구현은 별도 단계다.

참고: [Godot 명령줄 인수](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html), [Godot Viewport.push_input](https://docs.godotengine.org/en/4.7/classes/class_viewport.html), [Windows 화면 캡처 CopyFromScreen](https://learn.microsoft.com/en-us/dotnet/api/system.drawing.graphics.copyfromscreen).
