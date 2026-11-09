# M1 Android 에뮬레이터 실행 QA

- 목표: 기존 `arm64-v8a` 휴대전화 APK의 빌드·서명 테스트를 보완하기 위해 Android 35 **x86_64 에뮬레이터**에서 앱 실행 상태를 검증한다.
- 기준 엔진: Godot 4.7.2, Compatibility renderer.
- 워크플로우: `.github/workflows/m1-android-emulator-smoke.yml`
- 테스트 구현: `scripts/qa/android_emulator_smoke.sh`
- 연관 이슈: #2

## 자동 테스트 시나리오
1. x86_64 전용 테스트 APK를 CI에서 별도 생성하고 서명한다.
2. 에뮬레이터를 실행한 다음 `adb install`로 APK 설치를 검증한다.
3. `monkey`로 앱을 최초 실행하여 프로세스가 살아 있는지 확인한다.
4. 첫 화면을 PNG로 캡처하고 PNG 포맷·크기 기준을 검사한다.
5. `am force-stop`으로 앱을 종료하고 재실행한다.
6. 재실행 프로세스 및 두 번째 PNG 캡처를 확인한다.
7. 핵심 Android FATAL EXCEPTION / SIGSEGV 로그를 수집한다.

## 범위 구분

| 구분 | 검수 내용 | 판정 |
|---|---|---|
| Android 빌드 | x86_64 Debug APK 생성/서명 | CI 결과 필요 |
| Android 실행 | 에뮬레이터 설치/최초 실행/재시작 | CI 결과 필요 |
| 시각적 화면 | 캡처 PNG를 실제로 보고 한글·겹침/잘림 판단 | 수동 검수 필요 |
| 물리 모바일 | 실제 arm64 휴대전화에서 터치/성능/노치 및 저장 복구 | **미검증** |
| 조작 경로 | UI의 실제 터치 버튼과 저장 흐름 | **미검증** |
| 정식 저장 | M3 원자적 세이브/검증/마이그레이션 | **미구현** |

*주의:* 에뮬레이터 앱을 강제 종료·재실행하는 것만으로 실제 개발용 저장 데이터 복원이 확인되는 것은 아니다. 저장 버튼을 이용한 테스트는 캡처를 확인한 뒤 별도 확장한다.

## 개발 정책

에뮬레이터 검증이 성공하더라도 사용자의 실제 모바일 기기 QA를 통과한 것으로 간주하지 않는다. M1 승인은 보류하며, 기존 Android arm64 APK 및 Windows EXE 출하 설정은 변경하지 않는다.

참고:
- https://github.com/ReactiveCircus/android-emulator-runner
- https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html

## 최초 실행 시각 QA에서 발견한 결함 (2026-11-09)

최초 에뮬레이터 APK 실행 자체는 성공했으나, 첫 번째 PNG 캡처와 재실행 PNG에서 **Android OS 전체화면 안내(“Viewing full screen” / “Got it”)가 게임 UI를 가리고 있었음**을 직접 확인했다. 처음 자동 스모크 테스트는 PNG 구조만 확인해 이 문제를 발견하지 못했다.

조치: ADB를 통해 해당 시스템 안내를 닫은 후 다시 캡처한다. UIAutomator에서 안내 문구가 남아 있다면 오류로 처리한다. 이 변경을 검증하는 신규 CI 결과와 PNG 수동 검사 전에는 **게임 화면 시각 QA PASS로 처리하지 않는다.**

## 실행 진단 2026-11-09 — Godot/Android GLSL 호환성

Android 35 Google APIs + Pixel 6 + SwiftShader 에뮬레이터에서는 메인 씬 `M1_UI_READY` 로그가 최초 실행과 재시작 모두에 기록되었음에도 실제 캡처가 `Pixel Launcher isn't responding` 경고로 가려졌다. `Godot GLES3 CanvasShaderGLES3` 로깅에서 `Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`이 확인되었다. **이는 화면 QA 불합격이며 첫 자동 스모크 성공과 구분한다.**

완화 실험: AOSP 기본 시스템 이미지(기존 Pixel Launcher 없음) + 에뮬레이터 `-gpu host` 방식으로 변경한다. 그래픽 셰이더 오류 또는 시스템 ANR 문자열을 실제 QA 실패로 처리한다. CI 결과를 재확인하기 전에는 Android 그래픽 성공을 주장하지 않는다.

참고 Godot 이슈: https://github.com/godotengine/godot/issues/109550
