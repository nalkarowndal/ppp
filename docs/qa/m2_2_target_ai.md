# M2-2 직업별 타깃 AI / 도발·위협도 QA 기록

**날짜:** 2026-11-10  
**상태:** 기능 테스트 단계 구현 / M2 전체·실기기 QA 미완료  
**브랜치:** `feature/m2-2-target-ai` (M2-1 브랜치 위에 스택)  
**사양:** `docs/superpowers/specs/2026-11-10-m2-2-target-ai-design.md`

## 실제 코드

- `scripts/combat/target_selector.gd` : 스킬이나 렌더와 분리된 순수 결정적 타깃 정책 (난수 소비 없음).
- `scripts/combat/auto_battle_core.gd` : 유닛의 `row`, `threat`, `taunt_until_tick` 런타임 상태·타깃 AI 연동; `add_threat()`와 `apply_taunt()` 훅.
- `tests/m2_target_ai_test.gd`: 행동 검증; M2-1 기존 코어 테스트도 같은 CI에서 실행.
- `.github/workflows/godot-m2-combat.yml` : Godot 4.7.2 import, M2-1과 M2-2 헤드리스 테스트.

## 타깃 정책 (초안)

| 공격자 역할 | 목표 열 | 같은 열에서의 우선순위 |
|---|---|---|
| ASSASSIN | 후열 우선 | 남은 HP 최소 |
| MAGE / ARCHER / RANGED | 전열 우선 | 남은 HP 최소 |
| TANK / DEFENDER / WARRIOR / MELEE / SUPPORT | 전열 우선 | 위협도 최대 |
| 지정되지 않은 역할 | 전열 우선 | 위협도 최대 |

- 선택 열에 살아있는 대상이 없으면 다른 열의 생존자로 후퇴합니다.
- 유닛의 `row`가 유효한 경우 이를 우선 사용하고, 없으면 직업으로 기본 배치 열을 추정합니다. 기존 샘플 적 `DEFENDER`가 세 번째 원소여도 전열로 취급합니다.
- 기본 위협도: TANK/DEFENDER 100, WARRIOR/MELEE 40, 기타 10. 기본 공격 피해량만큼 공격자의 위협도가 증가하며 1,000,000에 상한을 둡니다.
- `apply_taunt(team, unit_id, duration_ticks)`: 해당 팀에서 살아있는 유닛의 도발만 허용, 같은 팀 이전 도발은 성공적으로 새로 부여된 경우에만 대체합니다. 도발 타깃이 죽으면 즉시 무시합니다.
- `taunt_until_tick`은 **끝 틱을 포함하지 않습니다**. tick 0에서 지속 3을 부여하면 tick 1과 2에 유효하고 tick 3부터 기본 타깃 정책입니다.
- 동일 점수에서는 배치 순서가 앞선 살아있는 유닛을 선택합니다. 타깃 결정을 위해 RNG를 추가 사용하지 않습니다.
- `apply_taunt`, `add_threat`는 후속 스킬 시스템 연동을 위한 공개 정책 훅입니다. 실제 도발 스킬과 상태이상 지속·중첩 구현은 M2-3·M2-4 범위입니다.

## QA 증거

`tests/m2_target_ai_test.gd`는 변경 전 기존 M2-1 코드에서 의도한 정책 불일치로 실패했습니다. 테스트의 누락 필드 접근 오류를 별도 수정한 후 **실제 요구 동작 관련 FAIL만 재확인**했고, 구현 후 PASS를 받았습니다.

- RED GitHub Actions: [#42777785656](https://github.com/nalkarowndal/ppp/actions/runs/42777785656) (Godot import 및 M2-1 PASS, M2-2 역할/열/도발/위협도 FAIL)
- GREEN GitHub Actions: [#42777966949](https://github.com/nalkarowndal/ppp/actions/runs/42777966949) (Godot import, M2-1 PASS, M2-2 PASS).
- 검증 영역: 직업별 공격 대상, 명시적 열 지정, 후열 우회, 전열 섬멸 후 후열 공략, 도발 우선/정확한 만료/사망 무시, 위협도 이동, 같은 시드+배속 재현, 원본 데이터 불변.
- 파싱/스크립트 오류 및 테스트 실패 로그는 GREEN run에서 발견되지 않았습니다.
- **이 파일에서 별도의 Android 물리 기기, Windows GUI, 인터랙티브 전투 애니메이션, 5대5 실사용 밸런스 PASS를 주장하지 않습니다.** 그 검사는 각 단계의 후속 게이트입니다.

### 검증 명령

```bash
python scripts/validate_data.py
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/m2_combat_core_test.gd
godot --headless --path . --script res://tests/m2_target_ai_test.gd
```

## 남아 있는 개발 항목

- **M2-3:** JSON 스킬 16종의 기본 효과, 쿨다운, 궁극기와 AI 행동 의사결정
- **M2-4:** 도발 스킬 적용과 상태이상/중첩/면역/갱신, 회복·보호막
- **M2-5:** 전투 UI·VFX·오디오 및 Android/Windows 실제 화면 검수
- **M1 issue #2:** Windows GUI와 Android ARM64 실기기 QA 미승인 유지

이 PR은 M2-1의 Draft PR #12 위에 쌓이며 `main`에 직접 병합하지 않습니다.
