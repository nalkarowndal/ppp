# M2-1 자동전투 코어 개발 기록 (승인 전)

- 프로젝트: Astral Chronicle / Godot 4.7.2 / GDScript
- 작업 브랜치: `feature/m2-auto-combat-core`
- 단계 상태: **M2-1 개발 및 자동 CI 검증 대상. M2 최종 완료 아님**
- 별도 보류: M1의 실제 Windows GUI 및 Android ARM64 실기기 QA (issue #2)

## 구현 범위

`scripts/combat/auto_battle_core.gd`는 화면·저장·OS 프레임과 분리된 20Hz (0.05초) 전투 시뮬레이터입니다.

1. 캐릭터 JSON 원본은 변경하지 않고 런타임 HP/ATK/DEF/SPD/CRIT를 복제
2. 초기 수직 슬라이스인 아군 3명 / 적 3명과 향후 5인 전열·후열 편성의 기본 슬롯 지원
3. SPD 누적 게이지 기반 자동 기본 공격; 동속도는 배치순으로 결정
4. 기본 타깃 AI: 방어형 적 우선, 암살자는 후열·원거리 우선
5. 기존 피해 공식 재사용, 0.95~1.05 분산·치명타·초기 속성 상성 적용
6. 일반전 90초 / 보스전 120초의 고정 틱 제한, 승리·전멸·시간 초과 처리
7. 하나의 seed에 종속된 RNG, 최근 최대 64건 공격 이벤트, 상태 스냅샷
8. `advance_frame(1|2|3)`가 고정 전투 틱만 1·2·3개 전진시키는 논리 배속 인터페이스

## 실행 검증

```bash
python scripts/validate_data.py
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/m2_combat_core_test.gd
```

`tests/m2_combat_core_test.gd`의 검증 항목:

- 3대3 교전 및 최대 5인 아군 데이터 처리
- 동일 입력/시드에서 상태·이벤트 순서 재현
- 동일 논리 틱 수의 1/2/3배속 결과 동등
- 방어형 적 우선 타깃, 승리 후 시뮬레이션 정지
- 일반전 1800틱·보스전 2400틱 시간 초과
- 런타임 상태가 JSON 원본을 변조하지 않는지 검사
- 빈 적 편성 거부

GitHub Actions: `.github/workflows/godot-m2-combat.yml`.
**PASS는 워크플로우가 실제로 성공한 이후에만 판정합니다.**

## 다음 작업 (미구현)

- **M2-2:** 직업별 AI, 전/후열 위협·도발, 유닛별 타깃/행동 정책, 전투 균형
- **M2-3:** `data/skills.json` 8 액티브 + 8 궁극기, 쿨다운·기력·수동 궁극기
- **M2-4:** 화상/독/빙결/감속/방어감소/보호막/회복/중첩·지속 시간·상태이상 면역
- **M2-5:** 전투 이벤트→Godot UI 애니메이션 연결, 단계별 3/5인 편성·보스 시각 검수, CI·Android/Windows 실기기 검증

`data/skills.json` 항목의 `spec_only_not_implemented` 표시는 그대로 유지합니다. M1 UI의 `battle_sandbox.gd`도 변경하지 않았습니다. M2-1 코어는 **아직 플레이어가 조작하는 게임 화면에 연결되지 않았으며**, 스킬·상태이상·최종 밸런스·전투 저장이 구현되었다고 간주하지 않습니다.

## 단계 판정

M1 실기기 Gate가 열리기 전에는 M2 마일스톤 전체를 승인하거나 `main` 병합 완료로 처리하지 않습니다. M2-1 PR은 통합 전 검토·검증용으로 유지합니다.
