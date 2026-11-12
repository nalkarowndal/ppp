# M3-5 프로필 저장·백업·복구 검증 보고서

**2026-11-12 / Godot 4.7.2 / M3-4 Draft #21 위 스택 작업.**

## 범위
- 개발용 M1 디버그 저장 파일 user://astral_dev_save_v1.json 은 변경·삭제·마이그레이션하지 않는다.
- 새 파일 user://astral_profile_v2.json; 이전 유효한 저장 user://astral_profile_v2.json.bak; 임시 쓰기 user://astral_profile_v2.json.tmp; 백업 준비 user://astral_profile_v2.json.bak.tmp.
- 하나의 프로필 스냅샷(schema_version 2)에 경제 원장(wallet/inventory/seen_events), 방치 체크포인트, 영웅 성장, 장비 장착 상태, 최고 클리어 스테이지, 단조 증가 revision을 저장.
- 저장 전에 원본 상태 전체 검증: 레벨/승급 수식 및 영웅 ID, 장비 소유권과 고유 인스턴스, 재화 및 영수증, 방치 스테이지 유효성. Godot JSON 숫자 float를 정수형으로 복원.
- JSON payload_text SHA-256 체크섬: 외부 JSON에 payload_text 문자열과 sha256을 저장. 파일을 읽기 전에 체크섬 검증하고 데이터 전체 유효성 검사. SHA-256은 **파일 손상 탐지** 용도이며 비밀키 서명이나 치트 방지는 아니다.
- 테스트용 M3 프로필 schema_version 1을 2로 변환해 보유 재화/영수증/체크포인트를 보존하고 영웅/장비 착용 매핑을 추가. **M1 디버그 저장 포맷을 새 포맷으로 자동 변환하는 기능이 아니다.**
- 원자적 저장의 실용적 구현: temp 저장·flush/close → temp 검증 → 현재 primary가 정상일 때만 backup.tmp 복사/검증 → bak 교체 → temp를 primary로 rename → primary 재검증.
- 복구 우선순위: 유효한 primary → 유효한 backup → 원본과 백업이 모두 없는 상태의 유효한 임시 파일. 불명확한/손상된 두 복사본은 오류로 보고 기존 진행 상태를 새 프로필로 자동 초기화하지 않는다.
- revision 비교로 오래된 프로필이 새 거래 원장을 덮어쓰는 것을 거부. 단독 로컬 프로세스에서 작동하는 CAS이며 다중 프로세스 동시 접근이나 OS 레벨 파일 락을 제공하지 않는다.

## 오프라인 보상 원자 커밋
- commit_offline_claim: 현재 유효한 저장을 로드 → M3-4 계산/M3-3 중복 거래 ID로 골드·경험치 지급 → 수정된 경제 원장과 동일한 방치 체크포인트를 **단일 프로필 스냅샷으로 저장** → 검증된 저장 성공 후에만 결과를 성공으로 반환.
- commit_logout_checkpoint: 실제 앱 종료 또는 백그라운드 감지 시 *신뢰된* 스테이지 및 UTC 시각을 저장하는 호출 API. 실제 Godot UI 노드와 운영 OS 생명주기 연결은 아직 없으며 M3-6에서 연동.
- 네트워크 서버 시간/서명/멀티프로세스 락 미구현. 로컬 시계 미래 조작 방어 불완전. 앱 종료 전에 종료 이벤트가 미발생하는 강제 종료는 다음 접속 방치 계산을 하지 못할 수 있음.

## 테스트 범위
- tests/m3_profile_save_test.gd: 프로필 직렬화·역직렬화, 초기 저장/재저장, 유효 백업 로테이션, 일부러 손상한 원본·체크섬·백업 복구, 오래된 revision 차단, 구조 손상 거부, 구버전 M3 프로필 마이그레이션, 저장된 원장과 체크포인트 동시 업데이트.
- tests/m3_save_process_test.gd: 서로 다른 Godot 프로세스 3개에서 파일 작성(write) → 복귀 시 보상 지급(read) → 앱 재기동 후 영수증 확인·중복 지급 거부(verify).
- GitHub Actions Godot 4.7.2 공식 Linux 전체 M3 회귀와 Windows Native engine에서 위 동일 테스트 실행; 기존 M2 전투, M1 Windows/Android 빌드 및 M1 디버그 저장 검증 유지.
- Linux/Windows CI는 실제 사용자 기기의 정전 또는 저장 중 프로세스 강제 종료를 완전히 재현한 내구성 테스트가 아님. rename의 플랫폼별 내구성 및 백업 상태 검증은 실기기 QA 후 승인한다.

## 미완료
- M3-6 정식 UI와 Android ARM64 실기기·Windows 실제 GUI에서 시각·터치·저장·안전영역 검수 및 OS 생명주기 연결.
- M4 실제 최고 클리어 스테이지/전투 보상 생산자 검증. user:// 파일 보호/서버 타임스탬프가 없으므로 클라이언트 변조 방지 불완전.
- M3 전체 승인, M1 물리 기기 QA issue #2 종료, main 병합 모두 보류.
