# Astral Chronicle M2-3 스킬 실행 코어 — QA 보고서

> **후속 업데이트 (2026-11-11):** 이 문서는 M2-3 완료 시점의 *역사적 기록*입니다. M2-4 실험 브랜치에서는 아래에 나오는 deferred effect들(화상·독·빙결·감속·DEF 변화·재생·도발)을 [M2-4 상태이상 엔진](m2_4_status_effects.md)으로 구현했습니다. 이전 단계 설명을 M2-4 현재 구현 상태로 해석하지 마세요.

**날짜:** 2026-11-11. **범위:** M2-3 실험 구현, M2 전체 승인 아님.

## 실제 적용
- `scripts/combat/skill_targeting.gd`: JSON target 모드 SINGLE_ENEMY, ENEMY_BACK, UP_TO_3_ENEMIES, ALL_ENEMIES, ALL_ALLIES, ALLY_LOW_HP, SELF 결정적 대상 결정.
- `scripts/combat/auto_battle_core.gd`: `configure_skills(skills)`, `set_auto_ultimates(enabled)`, `request_ultimate(team,id)` 및 스킬/자원/쿨다운 실행.
- 캐릭터 스킬 목록은 기존 JSON `skill_ids`와 연결, 스킬 데이터는 명시적 주입 및 깊은 복제.
- 행동 우선순위: 기력 100 + 자동/예약 궁극기 → 사용 가능 액티브 → 기본 공격.
- 액티브 성공 시 10 기력 획득, 쿨다운 = `ceil(cooldown_sec * 20)` 틱. 궁극기는 100 기력 소모.
- 적을 대상으로 하는 스킬의 즉시 피해에는 기존 속성 상성·방어력·치명타·고정 RNG를 재사용.
- 3연타, 최대 3명, 모든 생존 적, 후열 단일 타깃, 연쇄 150/110/75%의 동작 구현.
- 회복은 실제 부족 HP만큼만, 보호막은 누적되며 피격 시 HP보다 먼저 감소. 도발은 M2-2의 임시 60틱 훅을 사용.
- 전투 이벤트: `skill_cast`, `skill_hit`, `heal`, `shield`, `taunt` (최근 최대 64건).
- 스킬/파티 입력 원본은 변경하지 않음. UI/저장/M1 샌드박스는 미변경.

## 16개 정의와 M2-4 잔여 효과의 차이

| 캐릭터 | 액티브 | 궁극기 | 남은 지속 효과 |
|---|---|---|---|
| 아리아 | 단일 피해 | 최대 3명 피해 | 화상 |
| 세레나 | 최대 3명 피해 | 전원 피해 | 감속·빙결 확률 |
| 레온 | 체력 비례 보호막 | 자신 보호막·임시 도발 | 도발 지속 정책의 정식 상태 적용 |
| 루나 | 최저 HP 비율 아군 회복 | 전원 회복 | 재생 지속 |
| 카일 | 후열 우선 단일 피해 | 단일 고계수 피해 | 없음(상태이상 측면) |
| 리아 | 동일 대상 3연타 | 최대 3명 연쇄 피해 | 없음(상태이상 측면) |
| 엘린 | 최대 3명 피해 | 전원 피해 | 독·방어 감소 |
| 벨 | 임시 도발 | 전원 보호막 | DEF 증가 지속/갱신 |

`data/skills.json`의 `status: spec_only_not_implemented` 표시는 M2-4가 끝나기 전까지 유지합니다. `skill_cast.deferred_effect`는 시각화/후속 상태 처리를 위한 **미구현 명시**이고, 스탯·행동 간섭을 주지는 않습니다.

## API / 주의
- 스킬 ID가 없는 적·캐릭터는 기존 기본공격 전투를 계속 수행합니다.
- `set_auto_ultimates(false)`일 때 UI가 `request_ultimate(team,id)`를 호출하면, 해당 캐릭터의 다음 행동 시 기력 100일 경우 실행합니다. 현재 전투 UI 버튼은 미연결입니다.
- 동일 시드 및 동일 논리 틱 수의 배속 비교는 기존 M2 테스트와 신규 스킬 RNG 테스트로 검증합니다.
- 현재는 기본 스킬 효과 실험용이며 실제 5인 조합·보스 난이도·장비·패시브 밸런스 검증은 미완료입니다.

## 테스트 증거
- RED CI: [#42979604259](https://github.com/nalkarowndal/ppp/actions/runs/42979604259) — M2-1·M2-2 PASS, 신규 M2-3 API 미구현에 따른 FAIL.
- 초기 GREEN CI: [#42979915686](https://github.com/nalkarowndal/ppp/actions/runs/42979915686) — M2-1/2/3 PASS.
- 테스트 강화 중 테스트 조건 수정: 랜덤 피해가 있는 환경에서 회복 이후의 HP를 직전 HP와 단순 비교하지 않고, 실제 피해량과 회복량으로 계산.
- 강화 GREEN CI: [#42980243589](https://github.com/nalkarowndal/ppp/actions/runs/42980243589) — M2-1/2/3 PASS.

### 실행 명령
```bash
python scripts/validate_data.py
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/m2_combat_core_test.gd
godot --headless --path . --script res://tests/m2_target_ai_test.gd
godot --headless --path . --script res://tests/m2_skill_runtime_test.gd
```

## 미완료 게이트
- M2-4 상태 이상 지속·중첩·면역, 재생, 감속/방어 감소, 도발 방어 버프 구현.
- M2-5 전투 UI, 액티브/궁극기 애니메이션 및 실제 기기 조작 검증.
- M1 issue #2 실물 Windows GUI와 Android ARM64 기기 QA 미완료.
- 이전 M2-1 Draft PR #12, M2-2 Draft PR #13 및 이 단계의 Draft PR을 main에 병합·최종 승인하지 않음.
