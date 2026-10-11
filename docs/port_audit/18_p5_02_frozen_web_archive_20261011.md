# P5-02A — 고정 웹 원본·전체 Git 이력 별도 영구 보존 결과 (2026-10-11)

## 보존 위치 및 고정 기준

- **검증·업로드 완료된 보존본:** https://github.com/gamja121/necromancer-and-dice-godot/releases/tag/p5-02-frozen-html-final-e13d5149-20261011
- 업로드 실행: https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38139575843 — **9개 Actions 단계 성공**, `P5_FROZEN_RELEASE_VERIFIED`.
- 원본 공개 저장소: `gamja121/necromancer-dice-board`. **저장소 수정·삭제 없음.**
- 고정 브랜치: `reference/html-final`
- 고정 커밋 SHA: `e13d5149fcecc802e5d626f3bef6e5daecd3d66c`
- 고정 트리 SHA: `a5042ff5d055ddb3c560b23f37ffb307fe74a523`
- 원본 GitHub 파일: **1,316개, 압축 전 260,786,852바이트**.
- Git 이력 참조: **69개** (전체 공개 Git mirror의 브랜치·태그 참조), 오프라인 bare repo 별도 복원 성공.

## 영구 Release 자산과 검증

| 파일 | 크기(바이트) | GitHub 업로드 확인 SHA256 |
| --- | ---: | --- |
| `frozen-web-source.zip` | 258131415 | `42e364889cecbe3ebdff1c8cf37b98f6c56e725960b62b31a28156ad68dbc1cc` |
| `history.bundle.part.000` | 503316480 | `6e7b3341f242544be884df8a5e8a62f7b098d690a207f483fb0f5aef3543ca6d` |
| `history.bundle.part.001` | 352979573 | `8f2f79b30f3b51e9022c7749773e810247eb172f99974e522e3858f56f4a3e50` |
| `source-file-manifest.tsv` | 224022 | `df4cad76b7151e469455c59fc459c29f9b6b284f7a439499feccebfa7105da1f` |
| `refs-and-commits.txt` | 5272 | `9cec813a297049a55eb69c66b647b547892f8a1b47ed7a846c12904ed4accb93` |
| `README-RESTORE.md` | 2250 | `f8a67283cf1d6f2730815c66559cc822d4cd49d5451b536a564624084f2c52d0` |
| `SHA256SUMS` | 530 | `ecf069d051b6e5c3715848f4e668d3cdc27166dc2400f50df7fe3ba5d1d3d855` |

원래 하나인 `history.bundle`을 위 순서로 재결합했을 때 기대되는 **전체 번들 SHA256**: `5c4b08436d6bb2f56d4466e1b46f5b867a2215716fec08a277cb7ed95a37a7a4`.

검증 범위:
1. ZIP 모든 파일의 경로가 고정 Git 트리와 1:1 대응하고, **1,316개 전부의 실제 Git blob SHA-1**과 일치함을 검사.
2. 전 파일 SHA256·Git blob SHA1·모드·크기를 `source-file-manifest.tsv`에 기록.
3. `git bundle verify` 후 **원본 Git 서버와 연결하지 않은 별도 bare 저장소**에 번들을 fetch하여 고정 트리 SHA 및 69개 refs가 정확히 복원되는지 검사.
4. 480MiB 단위로 나눈 두 번들 조각을 SHA256로 재조합 검증. `sha256sum -c SHA256SUMS` 전부 성공.
5. GitHub Release 7개 자산을 `uploaded` 상태와 API 제공 `sha256`으로 조회. 기존 보존본을 무단 갱신하지 않는 새 고정 태그를 사용.

## 복구 예시

GitHub Release의 7개 첨부파일을 같은 폴더에 받은 뒤 실행:

```bash
sha256sum -c SHA256SUMS
cat history.bundle.part.* > history.bundle
sha256sum history.bundle
# 결과가 5c4b08436d6bb2f56d4466e1b46f5b867a2215716fec08a277cb7ed95a37a7a4 인지 확인
git clone --mirror history.bundle restored-web.git
git -C restored-web.git cat-file -e e13d5149fcecc802e5d626f3bef6e5daecd3d66c^{commit}
git -C restored-web.git rev-parse e13d5149fcecc802e5d626f3bef6e5daecd3d66c^{tree}
# 마지막 결과: a5042ff5d055ddb3c560b23f37ffb307fe74a523
```

자세한 복구 절차는 Release의 `README-RESTORE.md`에 보존.

## 중요하게 남은 미완료 항목

- **P5-02A = DONE**, GitHub에 추적된 고정 웹 원본과 공개 Git 전체 이력에 한정.
- **P5-02B = TODO**: 실제 PC에만 있는 `raw_assets`, `source_assets`, PNG/PSD 제작 원본, .gitignore에 의해 제외된 파일 등은 이 연결로 확인하거나 수집하지 못했으며, 사용자가 소유한 로컬·외부 저장소 복구 가능 백업과 별도 복사/검증 필요. **P5-02 상위는 아직 TODO.**
- GitHub의 새 Release는 GitHub 내 독립 저장소에 만든 **보존본 하나**이다. GitHub 장애에 대비한 별도의 사용자 소유 오프사이트 저장소/외장 장치 복제는 아직 확인되지 않았다.
- Git 과거 이력의 통상적 비밀키 파일명 패턴을 확인했으나 **전체 이력 내용의 인증정보·비밀 검토를 전수 보증하지는 않는다**. 공개 Release에는 공개 Git 저장소에 이미 있던 파일만 복사한다.
- 현행 Pages 미리보기는 여전히 옛 웹 저장소에서 서비스하므로 **배포 경로 이전 없이 웹 저장소 삭제 금지**.
- Windows GUI/오디오, PC↔GitHub SHA 동기화, P5-03 최종 159항목 감사, P5-04 사용자 명시 삭제 승인은 여전히 별개다.

기존 웹 원본 브랜치, 커밋, 아트/규칙 파일과 Godot 게임 코드·저장은 변경하지 않았다.
