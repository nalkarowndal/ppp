# 기술 결정 기록 (ADR) / 초기 구현 가이드

## ADR-001 엔진/언어

Godot 4.7.2 안정 릴리스 기준으로 GDScript를 사용한다. 엔진 버전이 다를 경우 씬·스크립트 및 내보내기를 재검증한다. 현재 작업 환경에서는 Godot 바이너리 실행 검증을 완료하지 못했으므로 **실행 성공으로 표기하지 않는다**.

## ADR-002 배포 우선순위

Android 우선, Windows 개발/QA, Web은 Compatibility/WebGL2 지원 검증 후 진행. 게임의 입력·세이브·네트워크 의존성을 플랫폼 레이어로 분리.

## ADR-003 픽셀 아트 & 화면

프로토타입 UI 기준 360×800 portrait, stretch canvas_items/expand. 월드는 향후 저해상도 SubViewport + 고해상도 UI 레이어 분리. 정수 확대가 가능한 픽셀 아트 스타일을 목표로 하되 화면비 검증을 선행한다. 현재 M1 UI는 고해상도 임시 Control만 사용한다.

## ADR-004 데이터

캐릭터/스킬/몬스터/스테이지 정적 데이터는 UTF-8 JSON. 데이터를 별도 파일로 작성해 런타임 상태와 분리. ID 단일성, 참조 일관성, 값 범위 검증. 엔진 로더는 배열/객체 JSON을 분리 지원한다.

## ADR-005 저장

M1 `save_manager.gd`는 **개발용 샌드박스 턴만 기록**한다. 실제 게임 진행 및 보상 저장은 미구현. M3에서 원자적 저장·이중 백업·스키마 마이그레이션·중복 지급 방지 구현 후 승격한다.

## ADR-006 전투

M1 `battle_sandbox.gd`는 고정 시드 기반 1턴 테스트이며 실시간 자동전투/AI/스킬을 대체하지 않는다. M2에서 논리 시뮬레이션과 시각출력을 분리하고 단위 테스트를 확대한다.

## ADR-007 검증 및 CI

현재 GitHub Actions는 **Python 정적 데이터 검사만** 실행한다. 실제 엔진 바이너리로의 import/스크립트 smoke/시각 QA는 별도 환경에서 실행하고 결과를 기록해야 한다.

## 수동 실행 명령 (작업환경에 Godot가 설치된 경우)

```bash
python scripts/validate_data.py
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke_test.gd
godot --path .
```

## 기술 출처

- [Godot 4.7 Project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html)
- [Godot 4.7 multiple resolutions](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html)
- [Godot 4.7 FileAccess](https://docs.godotengine.org/en/4.7/classes/class_fileaccess.html)
- [Godot 4.7 command line](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)
