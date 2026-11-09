# ASTRAL CHRONICLE (아스트라 크로니클)

서브컬처 캐릭터 수집 × 픽셀아트 × 방치형 RPG. Godot 4 기반 게임 개발 프로젝트입니다.

> 현재 상태: **M0 완료 목표의 초기 저장소 구성 / M1 기반 개발 진행 중**. 전체 게임이나 MVP가 구현된 상태가 아닙니다.

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
