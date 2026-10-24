# 마물카드 투명 먹선 복원 후보 — 2026-10-25

## 현재 상태
- 현재 공개 `main` 원화는 수정하지 않았음. 기존 이미지 덮어쓰기 금지.
- `assets/cards/layered/*.webp` 47종 + 특수 보스 고룡 1종 = 실사용 카드 48종 알파 품질 전수 검사 완료
- 고위험 누끼 흔적 28종, 확인 필요 14종, 우선순위 낮음 6종. 자동 점수는 **누끼 오류 확정 판정이 아님**
- 선행 대상으로 지옥 사마귀(hell_mantis.webp), 해골 기사(skeleton_cavalry.webp) 독립 시험 복원 후보 생성
- GitHub 이전 커밋에는 현 누끼 처리 WebP를 도입한 버전만 존재함. 별도 PC `raw_assets` / `source_assets`의 누끼 전 원본이 있다면 그것을 먼저 찾아 대조해야 함

## 시범 복원 후보 (게임 미적용)
- `scripts/candidate_card_ink_shadow_repair.py` → `card_shadow_ink_review/` (GitHub Actions artifact)
- 지옥 사마귀: 투명 영역 20,567픽셀 / 전체의 1.1623%에 어두운 주변 먹선 복원 **후보**
- 해골 기사: 투명 영역 11,528픽셀 / 전체의 0.6107% 동일
- 작은 구멍만 대상인 더 안전한 `scripts/candidate_card_alpha_pinhole_repair.py`는 지옥 사마귀에서 변경 픽셀 0개여서 시각적 개선이 없음
- 원화의 기존 손상과 **의도된 빈 공간**이 알파 정보만으로는 구분되지 않음. 추가 후보 역시 일부 의도된 구멍을 검게 채웠을 가능성이 있음. 자동 병합 금지

## 다음 검토
1. 비교 이미지: `hell_mantis_before_after_paper.jpg`, `skeleton_cavalry_before_after_paper.jpg`를 밝은 배경에서 확인
2. `*_restored_pixel_mask.png`로 손댄 위치 전부 점검; 의도된 구멍이면 복원 마스크에서 제외
3. 누끼 전 원본에 접근 가능하면 원본에서 직접 알파 재추출하는 방식으로 후보 대체
4. 인게임 실제 카드 136×218 크기와 검은/밝은 배경에서 비교
5. 고품질 수동 검토를 통과하기 전에는 `assets/cards/layered/*.webp` 원본 변경이나 `main` 병합 금지

**전투 데이터, 메타데이터, 보상, Godot 원화 연결을 수정하지 않음.**
