# M3-4 오프라인 방치 보상 QA

**2026-11-12 / Godot 4.7.2 / M3-3 Draft #20 위 스택 작업.**

## 구현 범위
- scripts/core/offline_rewards.gd: 순수 함수로 종료 시각과 종료 당시 최고 클리어 스테이지를 기록하고, 방치 보상을 미리보기/지급 처리.
- XP/hour = floor(240 × 1.12^(stage − 1)); Gold/hour = floor(200 × 1.12^(stage − 1)).
- 지급 = floor(min(elapsed_seconds, 28800)/3600 × 시간당 생산량 × 0.8).
- Stage 1, 1시간: XP 결정 192, 골드 160 / 8시간: XP 1,536, 골드 1,280 / 9시간 이상은 8시간분으로 고정.
- Stage 2, 1시간: XP 결정 214, 골드 179. Stage 1~40만 인정하고 *저장된 종료 시점 스테이지*로 지급.
- 거래 원장: offline:<last_exit_unix> 고정 ID를 M3-3 Economy.try_claim에 전달. 성공 시 체크포인트와 지급된 경제 스냅샷 모두 반환. 재시도 시 종료 시각 기준 ID가 같아 중복 수령 거부.
- 보상이 0이면 체크포인트를 변경하지 않아 누적 시간을 보존. 실패(시계 역행, 잘못된 시각·스테이지·설정, 재화 한도 초과, 중복 거래 등)도 입력을 변경하지 않음.
- 오프라인 신규 스테이지 클리어 또는 장비 드롭 없음.

## 호출 계약
1. 실제 종료 또는 백그라운드 전환 시, 검증된 진행 기록의 highest_cleared_stage와 int(floor(Time.get_unix_time_from_system()))로 new_checkpoint 호출.
2. 복귀 시 1회 preview/try_claim 사용. 앱 실행 중 반복 호출하여 플레이 중인 시간을 오프라인 시간으로 보상해서는 안 됨.
3. 성공 반환의 checkpoint와 economy_state를 M3-5의 **단일 원자적 영구 저장 트랜잭션**으로 기록. 둘 중 하나만 저장하면 안 됨.
4. 다음 종료 시 새 체크포인트를 생성. 앱 주기·세션 연결 로직은 M3-5/6 구현 예정.

## 보안/검수 한계
- Godot 공식 Time.get_unix_time_from_system은 사용자가 시스템 시계를 조정할 수 있음. 이전 시점보다 시계를 되돌리는 상황은 거부하지만 고의적인 미래 시간 설정은 방어할 수 없음. 서버 시간 검증은 미구현.
- highest_cleared_stage 값은 신뢰 가능한 게임 진행 데이터에서 전달해야 함. M4 실제 승리 기록 연결 이전에는 API 자체가 진척을 증명하지 않음.
- M3-5 이전에는 앱 재실행 후 기록을 복원하는 영구 디스크 저장 미구현. JSON 왕복 테스트와 운영 저장 완성은 별개.
- Windows GUI 수동 검증과 실제 Android ARM64 실기기 터치·안전 영역·종료 후 복원 검증은 이슈 #2에 남겨둠.
- Superdesign 기반 UI는 M3-6 범위.

## 테스트
- tests/m3_offline_rewards_test.gd: 0/1/60/1800/3600초, 8/9/48시간, stage 1/2/40, 잘못된 설정·시계 역행·한도 초과, 성공 후 재시도·원장 중복 거래·JSON roundtrip.
- 공식 Godot 4.7.2 headless 및 M3-1/2/3, M2-1~5, M1 Linux/Windows/Android CI 결과는 Draft PR 본문에서 추적.
