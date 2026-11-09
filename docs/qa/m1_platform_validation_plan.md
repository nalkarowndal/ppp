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
