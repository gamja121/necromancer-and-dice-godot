# 마물카드 누끼 검수 — 사용자 확정 판정 (2026-10-25)

## 판정 기준과 출처
- 사용자 직접 제출: `마물카드_누끼_내검수결과.csv` 48행, 각 행의 `내 판정` 값을 최우선 기준으로 사용
- **복구 필요 24종 / 정상 24종**
- 과거 자동 누끼 점수와 시각적 A/B/C 분류보다 이번 `내 판정`이 우선함
- 기존 카드 이름, 슬러그, 파일 경로/낙인/게임데이터 변경 없음

## 복구 대상 24종 (반드시 검토)
1. `stone-golem`
2. `hell-mantis`
3. `plague-doctor`
4. `goblin-chief`
5. `death-knight`
6. `scorpion-knight`
7. `grave-priest`
8. `skeleton-cavalry`
9. `spider-knight`
10. `flesh-golem`
11. `goblin-soldier`
12. `yeti`
13. `abyss-harpy`
14. `sea-wolf`
15. `minotaur`
16. `abyss-eye`
17. `boulder-ogre`
18. `cerberus`
19. `abyss-claw-hunter`
20. `orc-warrior`
21. `mushroom-soldier`
22. `guardian-seed`
23. `doom-executor`
24. `hydra`

## 수정 금지: 사용자 정상 판정 24종
1. `ancient-treant`
2. `goblin-rider`
3. `kraken`
4. `crystal-devourer`
5. `siren`
6. `ghoul`
7. `spiderling`
8. `raging-treant`
9. `goblin-commoner`
10. `dragon`
11. `grave-worm`
12. `plague-frog`
13. `corpse-slime`
14. `skeleton-archer`
15. `mummy-guardian`
16. `skeleton-spear`
17. `dracula`
18. `forest-fairy`
19. `mimic`
20. `bone-golem`
21. `soul-reaper`
22. `ice-princess`
23. `ice-lord`
24. `bone-hound`

## 2026-10-25 현재 작업 진행
- 사용자 판정 CSV 48행 파싱/중복 없이 전체 대응 확인
- 복구 필요 24종에 대해 원본 별도 보관, **복구 후보 WEBP 24장 생성**
- 후보는 국소적·폐쇄된 투명 구멍 중 진한 먹선에 둘러싸인 영역만 가급적 복원하며 의도된 빈 공간은 유지하도록 시도
- 각 카드별 원본/후보/변경 마스크 3단 비교 이미지 생성; 표시 시 보이는 원본 픽셀이 마스크 밖에서 변하지 않았음을 24/24 검증
- **후보 ≠ 완성 복구 원화**: 누끼 전 원본이 없고 큰 열린 틈/삭제된 색과 먹선의 정확한 재현은 불가능. 일부 원래 빈 공간을 채웠을 수 있음.
- 후보 ZIP은 ChatGPT 대화에서 제공. **게임 `main` 원화는 0건 수정**, 정상 24종은 0건 수정
- 실제 게임 원화 교체는 개별 후보 승인·본래 먹선 확인·밝은/어두운 배경 비교가 완료된 뒤 진행

## 운영 규칙
1. Trigger: 사용자 확정 `복구 필요` 카드의 원화 복구 검토
2. Information: 원본 파일, 후보 이미지, 수정 영역 마스크, 원본 출처 여부
3. Interaction: 최종 적용 전 후보와 원본을 나란히 비교
4. Visual change: 검증된 잉크 누락만 고치고 아트/프레임/텍스트/외형 변경 금지
5. Memory: 사용자 `정상` 판정 24종 보호, 실게임 저장·마물 데이터 변경 금지
