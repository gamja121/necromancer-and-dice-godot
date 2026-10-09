# 거미 여왕 24프레임 후보 — 2026-10-09

기존 spider-knight의 갑옷/여성 상체/거미 몸체를 참조하여 built-in image_gen 한 번으로 새 자세 시트를 제작했다. 크라켄과 같은 공용 도구로 처리했다. 기존 인게임 자산은 유지하며 후보만 제작했다.

- 공격10 / 피격6 / 사망8, 공격7이 타격 시점.
- 생성 원본1536×1024 RGBA,6열4행. 알파 윤곽24개 분리, 준비400×300/바닥280.
- 초대형 기준 대기 몸체640px. 공통 배율2.819383, 최종 프레임1280×896/바닥872. 개별 사망 자세를 확대하지 않는다.
- 로컬 RealESRGAN x4plus, RGB보강70%/원본30%, 원본알파 유지.24장 보강, 다음 미리보기 실행 전체 캐시 적중.
- 최종 시트7680×3584. 가장자리 잘림, PNG 저장/시트 픽셀 검증, 마지막 잔해 크기 비증가 검사 통과.
- Godot 공용 미리보기에서24장 로드. 프로젝트 테스트/게임 버튼 추가, 설치, 커밋, 푸시 없음.

프로필: scripts/unit_art_pipeline/profiles/spider_queen.json.
후보: source_assets/unit_art_pipeline/spider-knight/.
원본/최종후보/정확한 생성 프롬프트: D:/Workspace/Games/necromancer-and-dice/raw_assets/spider_queen_24_20261009/.
