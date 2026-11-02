# 첫 불신 이후 — 기사단장의 추궁

사용자의 ‘다음 이어질 시나리오 진행’ 요청에 따른 구현. 첫 불신 다음 실제 마을 방문에서 목격담을 들은 기사단장이 경위를 확인한다. 설명/숨김에 따라 다른 기록을 남기는 단계이며, 마녀사냥과 집 방화는 후속 구상이다.

## 사건 계약

| 항목 | 구현 |
| --- | --- |
| Trigger | 실제 방치→예언가→광신도 조사→목격→마을 불신의 전체 완료 출처. 첫 불신을 확인한 방문과 다른 실제 마을 도착 |
| Information | 기사단장은 앞서 자신이 조사를 의뢰한 사실을 기억한다. 수레 목격담과 아이에 대한 추측을 구별한다. 예언가가 보여 준 문양과 엿들은 행선지를 설명할 수 있으며, 받지 않은 물증은 제출하지 않는다 |
| Interaction | 조사 경위를 설명하거나 숨긴다. 선택 직후에는 변경 가능하고, 첫 대응을 확인한 다음에는 되돌리지 않는다 |
| Visual | 기존 사건책·금박/청색/붉은색 삽화. 기존 기사단장 갑옷과 주인공의 뒷모습을 맞춘1672×941 원화. 마지막 도장은 설명 시 ‘유보’, 숨김 시 ‘감시’ |
| Memory | 마지막 확인에서만 설명 기록+판단 유보 또는 해명 보류+감시 명령+이번 사건의 불신 심화를 배타적으로 저장 |

### 설명한다

예언가가 보여 준 문양, 제단에서 들은 행선지, 정보를 얻기 위해 수레를 옮긴 경위를 밝힌다. 기사단장은 보고에 그 설명도 남기고 예언가와 목격자의 말을 각각 대조하기로 한다. 즉시 신뢰를 회복하거나 예언가가 현장 의도를 보증하지 않는다. 새로 수행할 수 없는 재방문 퀘스트는 만들지 않는다.

### 숨긴다

정보를 어디까지 믿고 맡길지 알 수 없어 문양과 행선지를 밝히지 않는다. 기사단장은 소문만으로 죄를 묻지는 않지만, 경위를 확인할 때까지 행적을 살피라고 명한다. 주민들은 그 감시를 보고 다시 수군거린다. 이 선택을 자동 유죄·즉시 체포·방화로 바꾸지 않는다.

## 상태·호환

- 사건 ID: `knight_commander_inquiry_01`. 기존 기사단장 사건·의뢰·인정 플래그는 수정하지 않는다.
- 0 도착→1 목격담→2 질문→선택→3 대응 의도→4 기사단장 반응→5 마지막 기록 순서. 순차 bool 체크포인트와 기존 v1 story_events를 사용한다.
- 설명: `story:commander_inquiry_01:account_recorded`, `judgment_deferred`.
- 숨김: 같은 사건 namespace의 `account_withheld`, `watch_ordered`, `distrust_escalated`. 미래의 다른 불신 사건과 과거 완료 판정을 충돌시키지 않는다.
- 첫 불신의 최종 저장에 `place_visit_id("mistrust-finished", index)` bool을 함께 저장한다. laps/move_serial/map_serial/index로 같은 방문 재발동을 막는다. 과거 완료 저장에 이 키가 없어도 다음 실제 도착에서 발견할 수 있다.
- 미리보기/첫 로드로 새 사건을 발견하지 않는다. 저장된 seen/active는 정확한 장면을 복원한다. 저장 실패는 전체 snapshot을 되돌린다.
- 의식 추적, 상점, HOME, 전투·마물·보상·RNG는 그대로 유지한다. 이번 ‘감시’는 서사 기록이며 이동을 제한하는 기계적 효과는 없다.

## 원화와 생성 프롬프트

내장 ImageGen 사용. `assets/map/events/manuscript_commander_inquiry_scene.png`에 생성 PNG를 픽셀 후처리 없이 복사했다.1672×941, 밉맵+기존 manuscript 선형 필터. 원본은 프로젝트 밖 raw_assets에 별도 보존한다.

SHA256: `69b4c2c058b497c9534435b2255c3eed042915bef14f416606fdbbab7cefb2f0`.

실제 참조 순서: `manuscript_commander_actor.png`, `manuscript_commander_base.png`, `manuscript_village_necromancer.png`, `manuscript_cultist_inquiry_scene.png`.

```text
Use case: illustration-story
Asset type: production medieval illuminated-manuscript event illustration for an existing game, opaque full painting, landscape 1672x941 pixels, matching the supplied game's original event paintings in detail and finish.
Input images: Image 1 is character identity reference ONLY for the knight commander (older white swept-back hair and short white beard, silver plate armor covered in gold lion ornament, gray fur mantle, dark green cloak with red lining). Image 2 is the village environment and exact manuscript painting/border style reference. Image 3 is protagonist identity reference ONLY: face entirely concealed, seen from behind, ragged charcoal hood/cloak with restrained gold detail, small chained black-and-gold skull grimoire and censer. Image 4 is the latest event's complete canvas and manuscript finish reference.
Primary request: Create a NEW narrative scene in the SAME illuminated book series: after suspicious rumors spread, the commander fairly questions the necromancer at the village gate. This is a tense inquiry, not a battle or arrest.
Scene: sunlit medieval village square and stone gate, tiled timber houses and distant cathedral consistent with Image 2. Commander on the left-center, shown three-quarter body with unmistakably the same white-bearded face and lion armor, calmly extending an open unarmed hand as he asks for an account. Hooded protagonist at right foreground from behind, same worn cloak, skull book, censer, facing commander. One armored guard with grounded spear stands behind the commander, visibly watchful but not threatening. A worried woodcutter and two quiet villagers stand at a respectful distance by the gate. Clear physical staging, readable silhouettes at thumbnail size, natural hands, commander and protagonist are largest subjects. Nothing should imply hidden identity or supernatural revelation.
Style/medium: richly colored hand-painted medieval manuscript miniature, fine black/brown ink drawing, tempera and gouache, patterned gold leaf, elegant flattened spatial design with detailed faces/materials. Match the vivid ultramarine sky, vermilion accents, warm stone, green plants and crisp brush detail of the reference paintings. Complete ornate gold/ultramarine/vermilion manuscript border on ALL four sides, matching Image 2 and 4, with acanthus scrollwork, small birds, flowers and corner medallions. Entire scene and entire border fit inside the landscape canvas.
Constraints: Same character identities and same illustration quality as supplied originals. Commander has NO crown, no helmet and holds NO drawn weapon. Player's face is never visible. Keep entire scene inside manuscript border. Opaque finished asset with no cutout/empty areas. No text, captions, letters, UI, dialogue boxes, watermark, photocollage, modern rendering or sepia woodcut. No flames, burning homes, mob attack, restraints, violence, cultist robes on commander, skeleton attendants or giant foreground heads.
```

## 검증

`test_commander_inquiry_branch`: 실제 출처 사슬, 두 선택·변경 경계, 동일 방문 차단, 과거 저장 호환, 잘못된 기록, 각 저장 실패 롤백, JSON 재시작, 기존 사건·게임 규칙 보존.

`test_commander_inquiry_capture`: 실제 map.tscn 버튼으로 두 경로를 한글·영문에서 진행. 미리보기/로드 미발견과 중간 재시작, 글자·도장·버튼 경계, 원화·밉맵, 프레임버퍼8장을 검사한다. 개인 저장 대신 PID별 테스트 프로필을 사용한다.

Prophet Story Event CI에서 새 분기와 양언어 캡처를 기존 회귀 검사에 추가했다.

로컬 최종 결과: 임포트 오류0. 새 분기153·실제 양언어 GPU1349, 첫 불신92, 언어89, 예언가160, 공통 배치30, 기존 제단 전투110, 부활 의식235, 전체 사건책337로 **9개 검사2,555항목 통과**. 실제8장과 영문 도장의 한 단어 표시를 확인했다. 기존 제단 전투 검사는 마지막 장면의 로딩·오디오를 배출한 뒤 종료하도록 정리하여 엄격한 종료 누수 검사도 통과했다.
