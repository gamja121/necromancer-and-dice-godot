# 게임 정보 UI 폰트 기준 (2026-10-16)

사용자가 확정한 두 서체는 다음과 같다.

| 구분 | 서체 | 실제 파일 |
|---|---|---|
| 일반 글씨 (B) | 나눔스퀘어라운드 Regular | \`res://assets/fonts/NanumSquareRoundR.ttf\` |
| 제목·강조 (D) | 나눔바른고딕 Regular | \`res://assets/fonts/NanumBarunGothic.ttf\` |
| 대사·내레이션 | 종전 서체 유지 | 기존 스토리 화면 설정 |

두 폰트 모두 Regular 무게이며, Bold를 억지로 합성하지 않는다. \`UiTypography\` 오토로드(\`systems/ui_typography.gd\`)가 기존·신규 Control에 정보용 서체를 설정한다. Label의 이름에 Title/Heading/Header/Subtitle/Category가 있거나 글씨가 큰 짧은 한글 제목이면 D를 사용한다. 나머지 본문·상태 숫자·버튼은 B. \`RichTextLabel\`은 기본 B, 강조(BBCode bold) D.

예외는 \`ui_story_copy_role\`이 speech/narration인 스토리 대사/서술과 Intro, EventDiscoveryDescription 등이다. 새로운 UI에서 확실히 강조하거나 보존할 때는 \`set_meta("ui_font_role","heading")\`, \`set_meta("ui_font_role","emphasis")\`, \`set_meta("ui_font_role","body")\`, \`set_meta("ui_font_preserve",true)\`을 명시한다.

글자 크기·색·화면 배치, 저장, 전투 규칙은 바꾸지 않는다. 기존 UI 이미지에 포함된 글자는 서체가 자동 교체되지 않는다. 글자폭 차이 때문에 실제 화면에서 잘림/겹침 여부는 추가 실기기 검사 필요.

## 저작권 및 배포
두 폰트 모두 NAVER 저작권 **SIL Open Font License 1.1**. 일반 상업용 게임에 글꼴을 포함해 배포 가능하며, 저작권 고지와 전문을 \`assets/fonts/OFL.txt\`로 제공한다. 글꼴만 따로 판매하지 않으며 다른 OFL 조건을 준수한다.

원 저작권자 안내: https://help.naver.com/service/11029/contents/18088?lang=ko&osType=PC

이번에 포함한 파일의 출처는 Debian 패키지 미러 \`deepin-community/fonts-nanum\`의 커밋 \`457a47664b20b75ae1b362398d7fc65f164dd0bb\`이며 원본을 변경하지 않았다. 체크섬은 아래 Git blob SHA와 일치한다.

* \`NanumSquareRoundR.ttf\` — \`c8d0c4f073ca952990df41ec9ad654d22ca65242\`
* \`NanumBarunGothic.ttf\` — \`c31486832e412992e7d7e3c93665329e35ad7050\`

GPLv2 은옛글 \`UnYetgul.ttf\`은 게임에 포함하지 않고, 이전 로컬 시험 로더는 공식 B/D 시스템으로 대체한다.

## 기본 설계 5문항
1. **Trigger** — Control 추가/장면 로딩
2. **Information** — 서체 역할, 한글 제목, 스토리 메타데이터
3. **Interaction** — 오토로드가 동적 UI에 폰트를 설정, 데이터/전투 처리와 분리
4. **Visual** — 일반 B / 제목·강조 D / 대사·내레이션 종전 서체
5. **Memory** — 저장 파일/게임 규칙 변경 없음
