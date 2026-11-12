# M3-6 성장·장비·방치 UI/UX 검수 보고서

## 범위 및 아키텍처
- scenes/m3_progression.tscn / scripts/ui/m3_progression_ui.gd: 세로형 Godot UI.
- scripts/ui/m3_progression_controller.gd: 기존 M3-1 성장/M3-2 장비/M3-3 거래 영수증/M3-4 방치/M3-5 저장을 실제 사용자 액션에 연결. 유효 거래가 저장 완료된 후에만 UI 스냅샷과 성공 문구 갱신.
- scripts/core/m3_session.gd: M3 화면 첫 접근 후 유지되는 Autoload. Godot Android NOTIFICATION_APPLICATION_PAUSED/RESUMED 및 Windows WM_CLOSE_REQUEST 처리. 앱 내 씬 변경 이후에도 저장 체크포인트 갱신.
- 기존 M1 디버그 화면의 저장·전투 버튼 및 M2 전투 씬은 유지. M2 프리뷰 아래 M3 화면 이동 버튼만 추가.

## UX
- 기존 M1 테마: 잉크 #101726, 패널 #1C2840, 아이보리 #F7F1E8, 금색 #DCC18A.
- 8명 캐릭터 좌우 변경, 실제 육성 레벨/등급/HP·ATK·DEF, 보유 골드/경험치/승급석/강화석.
- 3개 탭: 성장(레벨업·승급), 장비(4 슬롯·인벤토리·장착·해제·강화), 방치(최대 8시간/효율 80%·미리보기·수령).
- 터치 버튼 최소 52 논리 픽셀, 폰트 12~22, 모바일 시스템 safe area 패딩, 화면 내 스크롤과 한국어 시스템 폰트 fallback.
- 신규 유저 프로필 8명은 보유하지만 무상 재화/장비가 없으므로 레벨업 버튼이 비활성화될 수 있다. M4 스테이지 보상 실제 연결 전까지 정상 동작. 테스트 전용 경로에만 QA 보상을 별도 지급.
- 실기기 배포 전에는 휴대형 한글 폰트 포함, 작은 단말과 노치 안전영역, 텍스트 줄바꿈 QA 추가 필요.

## 자동 QA
- tests/m3_ui_controller_test.gd: 8 동료 신규 프로필, 무상 보상 없음, 골드 차감 성장/승급 제한, 장비 장착/해제/강화 원장, 방치 보상 중복 수령 차단, 별도 컨트롤러 재실행 후 저장 유지.
- tests/m3_ui_integration_test.gd: Godot Control 실씬 로드, 저장 연결된 실제 버튼 신호 실행, 변경된 골드/레벨/장비 장착 정보 디스크 검사.
- tests/m3_ui_visual_capture.gd: 실제 Godot Compatibility 렌더러 + Xvfb, 360×800 및 480×960 성장/장비/방치 화면 총 6개 캡처. 물리 픽셀과 Godot 논리 좌표 별도 검증.
- Windows Godot 4.7.2 네이티브 엔진 헤드리스 M3 UI/컨트롤러, M1/M2 및 M3-1~5 회귀, Windows EXE와 Android ARM64 APK 내보내기 체크.
- CSV/XLSX 분석이나 서버 결제/아이템 지급 기능 없음. M3 UI는 M4의 실제 전투 보상 생산자 없이 임의로 골드를 생성하지 않는다.

## 물리기기 검수 미완료 (이슈 #2)
1. Windows GUI: 실제 EXE 더블클릭, 마우스로 탭·장비 선택 및 스크롤, OS 종료 후 재실행, 한글 폰트, 창 크기 조절, 360×800/900 레이아웃.
2. Android ARM64: 실제 설치, 화면 노치/상태·내비게이션 바, 48px 이상 터치, 한국어 글리프 누락·줄바꿈, 앱 백그라운드/강제 종료와 보상 수령 후 재시작 및 재화 무중복 검증.
3. M3Session은 플레이어가 M3 화면에 한 번 접근한 뒤 활성화된다. 첫 화면 진입 이전의 앱 강제 종료와 OS가 pause를 생략한 킬 상황은 아직 방치 시간을 보장하지 않는다.
4. 로컬 디스크 정전 내구성, 로컬 시간 조작 방어, 다중 프로세스 잠금, 서버 권위는 미구현. M4 게임 보상 루프·M5 전체 통합 UI 및 M7 아트는 후속 작업.

## 도구/브랜드 기준
- Superdesign CLI preflight 호출은 제한 시간 초과로 캔버스 디자인을 생성·검증하지 못함. 이번 구현은 실제 기존 코드의 색상·폰트·레이아웃 토큰을 따라 네이티브 Godot Control로 작성.
- Superpowers-style RED→GREEN 테스트·명세·계획 문서화 적용. 별도 Superpowers 플러그인 실행 완료 증거 없음.
- Draft PR만 생성, main 병합 또는 M3 전체 승인 금지.
