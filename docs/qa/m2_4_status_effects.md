# Astral Chronicle M2-4 상태이상 엔진 QA (2026-11-11)

**작업 브랜치:** `feature/m2-4-status-effects` — M2-3 위에 쌓인 독립 Draft 단계.  
**엔진:** Godot 4.7.2 / GDScript / 20Hz fixed simulation.  
**상태:** 상태이상 전투 코어 및 CI 검증 구현. **M2 전체 승인·실기기 QA 완료가 아님.**

## 실제 변경 코드
- `scripts/combat/status_effects.gd`: 상태 종류와 범주, 중첩 상한, 지속시간 갱신, 면역, 주기 효과 설명, 만료, 속도·방어 보정 규칙을 담당하는 순수 정책 모듈. Godot Timer나 글로벌 RNG를 사용하지 않음.
- `scripts/combat/auto_battle_core.gd`: 매 틱 DOT→HOT→승패→게이지·행동 순서로 상태 정책을 실행하고 M2-3 스킬과 연결.
- `tests/m2_status_effects_test.gd`: 실전 유닛/스킬 기반 상태 동작 회귀 테스트.
- `tests/m2_skill_runtime_test.gd`: M2-3의 **미구현 표식** 검사를 M2-4의 실제 화상/방어 상승 적용 검사로 교체. 스킬 타깃·재현성·회복·보호막 기준은 그대로 검증.
- `.github/workflows/godot-m2-combat.yml`: M2-1/2/3/4 전체 헤드리스 회귀 검사 및 로그 업로드.

## 효과 정책 및 임시 밸런스

| 효과 | 출처 | 지속/중첩 | 전투 적용 |
|---|---|---|---|
| BURN (화상) | 아리아 액티브 | 4초, 최대3중첩 | 1초마다 최대 HP 2% × 중첩, 보호막 우선 |
| POISON (독) | 엘린 액티브 | 6초, 최대3중첩 | 1초마다 최대 HP 1% × 중첩, 보호막 우선 |
| SLOW (감속) | 세레나 액티브 | 4초, 갱신 | SPD 게이지 충전량 -25% |
| FREEZE (빙결) | 세레나 궁극기 | 2초, 갱신 | 각 생존 피격 대상마다 30% 확률, 게이지/행동 중단 |
| DEF_DOWN (방어 감소) | 엘린 궁극기 | 6초, 갱신 | 피해 계산에서 효과 방어력 -20% |
| DEF_UP (방어 증가) | 벨 액티브 | 4초, 갱신 | 피해 계산에서 효과 방어력 +10% |
| REGEN (지속 회복) | 루나 궁극기 | 5초, 갱신 | 1초마다 최대 HP 3% 회복, 최대 HP 상한 |
| TAUNT (도발) | 벨 액티브, 레온 궁극기 | 3초, 갱신 | M2-2 단일 타깃 선택 강제, 해제 시 타깃 강제 종료 |

수치는 **M2-4 QA·기능 시뮬레이션용 잠정값**이며, 보스/5인 파티/장비별 밸런스는 아직 판정하지 않았습니다.

## 세부 규칙
- 모든 지속시간은 `ceil(초 × 20)`에 해당하는 **고정 틱**으로 다룹니다. 빙결/감속 등 행동 효과는 끝 틱을 제외하되 DOT/HOT는 **끝 틱 펄스 포함 후 제거**합니다.
- BURN·POISON 재적용은 최대 3중첩 + 종료 틱 갱신. 이미 예정된 다음 1초 펄스는 뒤로 밀지 않음.
- 면역 목록은 원본 캐릭터 딕셔너리에서 깊게 복제. 면역 효과는 적용 거절; 세레나 빙결 판정은 대상이 면역이면 별도 RNG를 소비하지 않음. 기존 상태를 소급 제거하려면 별도 해제를 요청해야 함.
- `add_status(team,id,type,duration_ticks,potency=0.0)`로 상태를 추가하고, `remove_status(team,id,selector)`의 selector `ALL`, `BUFF`, `DEBUFF` 또는 개별 상태 ID로 정리. `set_status_immunity(team,id,type,enabled)` 지원.
- 상태는 살아있는 유닛에만 적용·작동. DOT로 유닛이 사망하면 승패를 즉시 판정해 이후 행동을 멈춤. 주기 피해는 보호막을 우선 소모하며 회복은 체력 상한을 넘지 않음.
- `status_applied`, `status_immune`, `status_tick`, `status_expired`, `status_removed` 이벤트가 최근 64건 스냅샷에 보임.
- `skill_cast.deferred_effect`는 현재 공란이며 새 `effect_type` 필드가 스킬 종류를 구분. M2-3 단계의 옛 설명을 그대로 적용하지 않도록 주의.

## TDD 및 CI 증거
- **RED:** [Actions #42981010147](https://github.com/nalkarowndal/ppp/actions/runs/42981010147) — M2-1/2/3 PASS, 신규 M2-4 API 미존재 FAIL.
- **초기 GREEN:** [Actions #42981349388](https://github.com/nalkarowndal/ppp/actions/runs/42981349388) — M2-1/2/3/4 PASS.
- **회귀 강화:** 주기 피해의 보호막 흡수·DOT 마무리 승리·스킬 대상 면역·도발 만료 추가. 초기 강화 실패는 테스트 도중 **레온 자동 궁극기가 보호막을 더 생성**한 영향이었으며 검증 대상 테스트에서 자동 궁극기를 비활성화해 분리.
- **강화 GREEN:** [Actions #42981725542](https://github.com/nalkarowndal/ppp/actions/runs/42981725542) — 모든 M2 헤드리스 테스트 PASS.

### 개발용 실행 방법
```bash
python scripts/validate_data.py
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/m2_combat_core_test.gd
godot --headless --path . --script res://tests/m2_target_ai_test.gd
godot --headless --path . --script res://tests/m2_skill_runtime_test.gd
godot --headless --path . --script res://tests/m2_status_effects_test.gd
```

## 범위 및 잔여 위험
1. `data/skills.json` 원본의 `spec_only_not_implemented` 선언은 M2-4 브랜치에서 변경하지 않음. **최종 스킬·UI 전체 완료 여부를 인증하는 상태 필드로 오해하지 말 것.** 즉시 효과 및 지속 상태의 엔진 런타임만 구현한 상태.
2. 상태 UI 아이콘, 남은 시간 시각화, 궁극기 수동 입력 버튼, VFX·오디오·터치 대응·성능 최적화는 **M2-5**에서 별도 구현/검수.
3. 보스 면역 테이블, 제어 저항/DR, 상태이상 해제 스킬, 새 패시브·전투 저장, 정식 스킬 밸런스는 미구현.
4. **M1 issue #2:** 실제 Windows PC GUI 및 Android ARM64 실기기 터치·저장·안전 영역·한글 가독성 검수 여전히 미완료. Android APK를 CI로 빌드했다고 물리 QA를 통과한 것은 아님.
5. PR #12 / #13 / #14 및 이번 M2-4 Draft PR은 `main`에 병합하지 않음. 전체 M2 완료 선언 보류.
