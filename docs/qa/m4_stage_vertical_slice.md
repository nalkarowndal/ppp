# M4 첫 10스테이지 플레이 루프: 기술 QA 및 승인 게이트

**2026-11-12 · Draft implementation.** 기준 브랜치: `feature/m4-stage-reward-vertical-slice`, base `feature/m3-physical-qa-readiness` (PR #24), Godot **4.7.2-stable**.

## 기능 범위
- 기존 M2 전투 모듈 `scripts/combat/auto_battle_core.gd`에서 20Hz 고정 시뮬레이션, 타깃 AI, 액티브/궁극기와 지속 효과 그대로 재사용. 스테이지 1~10은 `data/stages.json`의 1~5마리 유효 encounter, 초기 제공된 3종 일반 적의 HP/ATK/DEF 수직 스케일링 적용.
- `scripts/core/m4_stage_run.gd`에 **실제 M2 승리 권위** 배치: 진입 제한, 3~5 유효한 중복 없는 영웅 편성, `Gear.stats_for` 성장·장비 합계, 전투 결과 판정, 최초 클리어/재도전 보상.
- 1스테이지만 최초 입장 가능. `stage:clear:%03d` 영수증이 있어야 다음 스테이지가 해제되며 `highest_cleared_stage` 필드는 기존 M3 모델 의미를 유지. `stage:replay:%03d:r%d`은 저장 revision 기반 재도전 영수증.
- 승리 시 `Economy.try_claim`과 `ProfileStore.save_profile`을 연결. 첫 클리어 장비는 1/3/5/7/10 보상 한정; 재도전 시 최초 장비는 재발급하지 않음. 플레이 중 강제 저장·일시정지 시 미완결 전투 보상은 지급하지 않음.
- 보상 가안: 스테이지 N 골드 `120+30N`, XP 결정 `160+35N`, 최초 클리어 강화석 `2+floor(N/3)`, 5/10단계 승급석 +5, 첫 클리어 장비 각 지정 1개. 서버 결제/광고/뽑기 없음.
- `scenes/m4_stage.tscn` / `scripts/ui/m4_stage_ui.gd`: 기존 M1 화면 아래 별도 입장 버튼, 10개 스테이지/잠금 및 결과, 전투 HP, AUTO 1×/2×/3×, M3 성장·장비 이동. 기존 M1 개발용 저장/터치 버튼과 M2/M3 씬은 유지.

## 검증 계약과 재현 명령
1. `godot --headless --path . --import`: GDScript 임포트·파싱.
2. `godot --headless --path . --script res://tests/m4_stage_loop_test.gd`: 실제 스테이지 1→10 클리어, 첫 클리어 지급·한정 장비, 재도전, 유효하지 않은 파티, 잠금, 저장 후 재시작, M3 실성장·장비 능력치 반영, 스테일 revision 동시 보상 거절.
3. `godot --headless --path . --script res://tests/m4_stage_ui_test.gd`: StageButton1/2 실제 Godot GUI pressed, 승리/보상 상태 및 다음 스테이지 unlock.
4. `tests/m4_stage_visual_capture.gd`와 Linux Xvfb: 360×800 및 480×960 렌더 PNG가 유효한 해상도/화면 색/버튼 크기·위치/잠금 상태인지 검사. **실제 Windows·Android 시각 검수 증거가 아님.**
5. 기존 Godot M1/M2/M3 Linux·Windows Actions와 Windows x64 EXE, Android ARM64 디버그 APK 생성. **APK 빌드 성공은 ARM64 물리 설치·터치 성공을 뜻하지 않음.**
6. GitHub CI 각 실행은 해당 커밋의 상세 로그를 확인할 것. 커밋 SHA·실행 URL·상태가 일치할 때만 통과 주장.

## 출시 차단 및 후속
- 물리 Windows GUI 직접 클릭, 창/디스플레이 크기 조절, 한국어/폰트, 장시간 반복 플레이와 종료/재실행; 실물 Android arm64 설치/터치/안전영역/한글/백그라운드·강제종료 검증이 **NOT RUN**. [QA issue #2](https://github.com/nalkarowndal/ppp/issues/2).
- [issue #25](https://github.com/nalkarowndal/ppp/issues/25): M3 OS resume 후 foreground에서 방치 시간이 중복 누적될 수 있음. M4에서 우회하지 않았으므로 **M3 승인 차단**.
- 현재 10개 일반 전투 씬은 실제 게임 레벨 아트·보스·던전·40개 스테이지·5인 편성 UI·서버 권위·부정 행위 검증을 대체하지 못함. 사용자가 8명 중 직접 출전 조합을 고르는 UI도 후속.
- UI는 기존 네이비/금색 토큰을 재사용. Superdesign CLI preflight 제한 시간 초과로 외부 캔버스 원격 시안을 만들지 못함. Godot 테스트·리눅스 렌더와 실제 모바일 UX QA 구분.
- 실제 PC/휴대전화와 사람이 검토한 이미지/로그, 외부 PR 코드 리뷰, 모든 Exit Gate 충족 전 **M4 승인·main 병합·기존 이슈 폐쇄 금지**.
