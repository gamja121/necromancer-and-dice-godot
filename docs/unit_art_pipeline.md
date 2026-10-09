# 공용 마물 이미지 파이프라인

마물마다 처리 스크립트를 새로 쓰지 않는다. 원본과 JSON 프로필을 준비하면 분리 → 공통 크기/접지 정렬 → 선택적 로컬 GPU 보강 → 시트/미리보기 → 승인본 백업/적용을 공용 도구로 수행한다. 기존 프레임 수를 유지할 수 있으며 모든 마물을 25장으로 늘리지 않는다.

## 실행

프로젝트 루트에서 PowerShell로 실행한다. 이 PC의 엔진 경로는 로컬 설정에 저장되어 있다.

```powershell
# 현재 히드라 재조립; 같은 입력이면 캐시 생략
.\scripts\unit_art_pipeline\run.ps1 -Action build

# 브라우저가 아닌 Godot 창에서 공격/피격/사망 재생
.\scripts\unit_art_pipeline\run.ps1 -Action preview

# 후보의 최신 여부와 승인 키
.\scripts\unit_art_pipeline\run.ps1 -Action status

# 다른 마물은 해당 프로필을 지정
.\scripts\unit_art_pipeline\run.ps1 -Action preview -Config .\my_unit.json
```

다른 PC의 첫 실행에는 -GodotPath로 설치한 Godot 실행 파일을 지정하거나 UNIT_ART_GODOT 환경변수를 설정한다. Python은 Codex 번들 우선, 없으면 PATH의 python을 사용한다. Pillow가 필요하다. 별도 서비스나 API 키, 이미지 생성 호출은 사용하지 않는다. 자동 설치/다운로드도 수행하지 않는다.

## 구성 파일

- scripts/unit_art_pipeline/unit_art_pipeline.py: 분리, 정렬, GPU 보강, 캐시, PNG/시트 검증, 백업과 적용.
- scripts/unit_art_pipeline/preview.gd: 마물별 manifest를 읽는 공용 Godot 미리보기.
- scripts/unit_art_pipeline/run.ps1: 공용 실행 진입점 및 로컬 도구 경로 재사용.
- scripts/unit_art_pipeline/profiles/hydra.json: 실제 적용된 히드라의 10/7/8, 1152×768, 640px 프로필.
- scripts/unit_art_pipeline/profiles/sheet_template.json: 새 5×5 규격 시트용 템플릿. 원본 PNG와 slug를 지정한 후 사용한다.

기본 작업 결과는 source_assets/unit_art_pipeline/<slug>/에 저장한다. Git과 Godot 런타임 import에서 제외되며 -OutputRoot로 프로젝트 밖 원본 작업 폴더를 지정할 수 있다. 개인 실행 경로는 제외된 local_tools.json에만 저장한다. 런타임 assets 폴더를 작업 출력으로 지정하는 것은 차단한다.

## 입력과 정렬

input.mode=frames는 attack-01.png, hit-01.png, death-01.png 형식의 기존 폴더를 받는다. counts는 실제 공격/피격/사망 개수다. 5/4/6 등 기존 개수를 유지할 수 있다.

input.mode=sheet는 grid=[열,행]으로 분리한다. 기본 순서는 왼쪽→오른쪽, 위→아래이다. order에 필요한 칸 번호(1부터)를 지정하면 다른 순서를 사용할 수 있다. 불규칙 시트는 input.rects에 프레임별 [x,y,width,height]를 한 번 기록한다.

```json
"rects": {"attack-01": [0, 0, 400, 300]}
```

overrides는 문제가 있는 프레임만 교체한다. 교체 PNG는 원본 칸과 크기/접지 기준이 맞아야 한다. crop으로 잘라내고 paste=[x,y]로 원본 칸에 배치할 수 있지만 자동으로 머리나 팔다리를 수정하지 않는다.

```json
"overrides": {"hit-02": {"path": "hit_02_fixed.png"}}
```

output.preserve=true는 규격이 완성된 프레임을 PNG 바이트 그대로 보존한다. false는 대기 자세의 body_height를 기준으로 모든 프레임에 같은 배율과 이동을 적용한다. 개별 자세를 같은 높이로 늘리거나 줄이지 않고, 점프/돌진의 상대 이동을 유지한다. source_anchor와 target_anchor를 지정하면 공통 기준점을 조정할 수 있다. 가로로 긴 공격은 전 프레임의 공통 위치만 조정한다. 여전히 잘리면 중단하고 캔버스/원본 패딩 수정이 필요함을 알린다.

일반 기준은 canvas576×384, body_height320, floor372. 초대형 히드라는 canvas1152×768, body_height640, floor744. floor는 몸체 범위의 아래쪽 끝 다음 좌표이다. 기본 몸체/접지는 알파64 이상, 잘림은 알파16 이상을 기준으로 검사한다.

## 화질 보강과 캐시

enhance.enabled는 기본 false다. 기존 화질이 충분하면 켜지 않는다. 켤 때 설치된 Real-ESRGAN 실행 파일을 -UpscalerPath로 지정한다. 모델 폴더가 다르면 -ModelsPath를 지정한다. 기본 모델은 realesrgan-x4plus, 4배 처리 후 필요한 규격으로 축소하며 RGB는 보강70%/원본30%, 알파는 원본을 보존한다.

입력 PNG/설정/도구/모델/파이프라인 해시를 기록한다. 같은 입력과 정상 출력이면 전체 처리를 생략한다. 프레임이 바뀌었을 때도 준비된 프레임과 GPU 결과는 프레임별 해시로 재사용한다. 최종 시트 조립은 저렴한 단계이므로 관련 설정이 바뀌면 다시 수행한다. 모델 변경은 GPU 캐시를 무효화한다. 시트 전체가 바뀌면 분리는 다시 하지만 동일하게 분리된 프레임의 GPU 결과는 재사용한다.

manifest.json에는 승인 키, 원본 해시, 프레임 크기/범위, 출력 해시, 재생 순서/타격 설정을 기록한다. contact_preview.png는 전체 자세를 비교하는 이미지다. Godot 미리보기에는 공격/피격/사망, 재생/일시정지, 이전/다음, 속도 선택이 있다.

## 승인본 적용

build와 preview는 인게임을 변경하지 않는다. 설치할 때는 검토한 manifest의 build_key를 지정한다. 이는 파일이 검토 이후 바뀌지 않았는지 확인하는 도구 옵션이며, 매번 대화에서 별도 허락을 다시 요구하는 규칙이 아니다. 사용자가 이미 적용을 지시한 후보에는 그 승인 키를 사용해 진행한다.

```powershell
.\scripts\unit_art_pipeline\run.ps1 -Action install `
  -Config .\my_unit.json `
  -ApprovedBuildKey '<검토한 build_key>' `
  -ArchiveRoot '<프로젝트 밖 원본 보관 폴더>'
```

변경되거나 오래된 키는 쓰기 전에 중단한다. 기존 PNG/import와 전체 visual metadata를 외부 보관 폴더에 먼저 백업하고, 승인된 PNG만 교체한다. 해당 마물의 visual metadata만 갱신하며 다른 마물/스탯/규칙은 수정하지 않는다. Godot import와 설치 해시를 확인하고 실패하면 교체한 PNG와 metadata를 복원한다. 기존 .import 식별자를 보존한다. 더 이상 재생하지 않는 기존 PNG는 삭제하지 않는다.

## 확인한 결과와 한계

- 실제 히드라 25프레임 폴더 → 시트 → 분리 경로에서 25장 전부 픽셀 동일.
- 기존 프레임 재사용 후 시트 처리 약4.7초, 동일 입력 캐시 실행 약0.36초를 관측. 이미지 생성/GPU 보강 시간은 제외한 로컬 측정이며 다른 PC나 마물의 소요 시간을 보장하지 않는다.
- 작은 기존 프레임3장의 GPU 보강/320px 공통 정렬을 확인. 접지의 1px 오차를 수정한 뒤 GPU 처리0/재사용3으로 복구했고 후속 전체 캐시 실행도 확인했다.
- 공용 Godot GPU 미리보기 실행 확인. JSON 숫자의 정수 변환 누락을 수정했고 이후 재생 로그에 오류 없음.
- 오래된 승인 키가 설치 전에 중단되는 것을 확인. 이미 승인된 동일 히드라로 백업/설치/Godot import 경로도 확인했다.
- 프로젝트에 검사용 게임 버튼이나 테스트 스크립트는 추가하지 않았다. 실행 확인용 설정과 산출물은 제외된 source_assets에만 보관한다.

투명 배경이 없는 RGB 원본은 배경 제거 작업이 먼저 필요하다. 불규칙한 원본의 칸/앵커는 처음 한 번 지정해야 한다. 머리 개수·무기·팔다리 오류, 자연스러운 자세 연결, 실제 타격 접촉, 부패 진행의 미술적 판단은 사람이 미리보기에서 확인한다. 이 도구는 새 그림이나 중간 자세를 자동 생성하지 않는다. 개선이 필요한 자세만 제작한 뒤 overrides로 다시 연결한다. 공용 도구와 기록은 공개 저장소에서 관리하고, 생성 원본과 미승인 후보 이미지는 로컬 보관한다.

## 격자를 넘어가는 생성 원본

input.segmentation="alpha_components"를 지정하면 알파64 이상의 독립 윤곽을 찾고 grid의 시각 행/열 순서로 분리한다. 자세 개수와 행별 개수가 맞지 않으면 중단한다. prepared_canvas=[400,256], prepared_floor=232처럼 준비 칸과 바닥을 지정한다. 이 옵션은 점프가 없는 지상 자세의 바닥 정렬에만 사용한다. 가로 이동은 원본의 칸 위치에 대해 유지하고 자세별 배율은 변경하지 않는다. 두 픽셀의 안티앨리어싱 여유를 남기며 이웃 자세는 마스크로 제외한다. 붙어 있는 자세나 분리된 작은 부품/파편이 중요한 원본에는 rects/수동 준비 프레임을 사용한다. 크라켄 프로필이 실제24프레임 예시다.

외곽 검수: edge_review.py <프레임폴더> --output <검수폴더>로 밝고 어두운 배경 비교표와 edge_review.json을 만든다. 이미지 픽셀은 바꾸지 않으며 색 검출은 수동검수 보조 지표다. alpha_components의 input.row_grouping="grounded_bottom"은 동일 접지선의 지상 자세가 등분 행을 벗어날 때 바닥 높이 순으로 행을 나누는 선택 옵션이다. 점프/행별 높이가 섞이면 기존 방식이나 수동 rects를 사용한다.

## 공개 동기화 범위 — 2026-10-10

공용 도구, 설정 템플릿과 마물별 제작 프로필/검수 기록만 공개한다. source_assets, raw_assets, 생성 이미지, 도구 실행 파일/모델, local_tools.json과 미승인 후보 이미지는 포함하지 않는다. 기본 히드라 프로필과 각 마물 프로필은 해당 로컬 입력을 별도로 준비해야 하며, 다른 PC에서는 자신의 경로로 원본과 엔진/보강 도구를 지정해야 한다.

초대형4종 후보 제작 완료. 대형은 뼈 골렘·살점 골렘·미노타우로스·오우거·설인·심연 집게사냥꾼·해골 기사7종 후보 제작 완료, 고블린 족장·오크 전사2종 남음. 후보 제작과 인게임 설치는 별도 상태다. 사건 원고 보류와 나머지 HTML→Godot 기능 대응은 docs/godot_port_status.md에서 별도로 추적한다. 이 도구의 게시를 전체 PC 게임 동기화나 완전 이식 완료로 보지 않는다.

공개 전 검증: Python AST/JSON 문법, 비밀키 패턴 검사, 24프레임 무손실 재조립, 최신 main Godot4.7.2 headless import 및120프레임 실행 확인 통과. 기존 후보의 네이티브 미리보기와 밝은/어두운 외곽 검수는 개별 제작 기록에 남긴다. 새 테스트 UI/코드는 추가하지 않는다.
