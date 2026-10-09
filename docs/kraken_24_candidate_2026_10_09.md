# 크라켄 24프레임 후보 — 2026-10-09

공용 unit_art_pipeline으로 생성 원본의 24개 자세를 분리하고 정렬/화질 보강/미리보기까지 완료했다. 기존 인게임 크라켄 5/4/6 프레임은 유지하며 아직 이 후보를 설치하지 않았다.

- 공격10, 피격6, 사망8. 단일 촉수 공격의 접촉은 공격7.
- 참조: 기존 kraken attack01/03, death06 및 정보창 초상. 기본 외형과 보랏빛 피부, 흡착판 유지. 새 자세 제작은 built-in image_gen 한 번 사용. 최종 프롬프트는 원본 보관 폴더에 저장.
- 생성 원본1536×1024, 시각 배열6×4. 촉수가 정규 칸을 넘어 alpha_components로24개 독립 윤곽을 분리했다. 다른 자세의 픽셀을 제외하고 각 윤곽에2px 안티앨리어싱 여유를 유지했다.
- 준비 프레임400×256, 접지232. 원본의 가로 이동은 유지하고 점프가 없는 자세만 바닥 정렬.
- 대기 몸체640px, 전 프레임 공통 배율 약3.950617. 긴 촉수의 잘림을 피하도록 최종 캔버스1440×832, 바닥808. 가로 여백을 늘린 것이며 개별 자세의 몸을 축소하지 않았다.
- 로컬 RealESRGAN-x4plus 4배, 보강RGB70%/원본30%, 원본알파 유지. 최초24장 처리 후 여백 수정에서는 GPU 처리0/재사용24. 후속 실행은 전체캐시 적중.
- 최종 시트8640×3328 RGBA,6열4행. 프레임24장의 PNG round-trip과 시트 포장, 가장자리 잘림,640px/접지, 마지막 사체 외곽 크기 비증가 검사 통과.
- 실제 Godot OpenGL 공용 미리보기: kraken 공격10/피격6/사망8 로딩 및 재생, 오류 없는 실행 로그 확인.

프로필: scripts/unit_art_pipeline/profiles/kraken.json. 실행: scripts/unit_art_pipeline/run.ps1 -Action preview -Config scripts/unit_art_pipeline/profiles/kraken.json.

최종 후보/원본/프롬프트/해시는 D:/Workspace/Games/necromancer-and-dice/raw_assets/kraken_24_20261009/에 보관했다. 작업 산출물은 source_assets/unit_art_pipeline/kraken/에 있으며 런타임에서 참조하지 않는다. anatomy/자세 연결은 사용자가 미리보기로 검토한다. 게임 내 피해·피격 동기화는 후보 설치 후 확인할 항목이다. 프로젝트에 테스트 버튼/스크립트는 추가하지 않았다. 커밋/푸시는 하지 않았다.
