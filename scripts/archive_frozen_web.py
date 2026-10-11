#!/usr/bin/env python3
"""Create and verify the immutable P5-02 source ZIP and full Git mirror bundle.

Run only against a newly cloned, read-only mirror of the PUBLIC legacy repo.
No mutation or push to the legacy GitHub repository is allowed.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

FROZEN = "e13d5149fcecc802e5d626f3bef6e5daecd3d66c"
FROZEN_TREE = "a5042ff5d055ddb3c560b23f37ffb307fe74a523"
FROZEN_BRANCH = "refs/heads/reference/html-final"
PART_BYTES = 480 * 1024 * 1024
HIGH_RISK_NAME = re.compile(
    r"(^|/)(?:\.env(?:\.[^/]*)?|\.npmrc|\.pypirc|id_rsa|id_ed25519|"
    r"credentials(?:\.[^/]*)?|secrets?\.(?:json|yaml|yml)|"
    r"[^/]+\.(?:pem|p12|pfx|key))$",
    re.IGNORECASE,
)


def run(*args: str, capture: bool = True) -> str:
    result = subprocess.run(args, check=True, capture_output=capture)
    return result.stdout.decode("utf-8", errors="replace").strip()


def git(path: Path, *args: str) -> str:
    return run("git", "-C", str(path), *args)


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as inp:
        while block := inp.read(4 * 1024 * 1024):
            h.update(block)
    return h.hexdigest()


def verify_tree_zip(source: Path, path: Path, output: Path) -> tuple[int, int]:
    record = subprocess.run(
        ["git", "-C", str(source), "ls-tree", "-r", "-z", "--full-tree", FROZEN],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    expected = {}
    for entry in record.split(b"\0"):
        if not entry:
            continue
        meta, name = entry.split(b"\t", 1)
        mode, kind, sha = meta.decode("ascii").split()
        if kind != "blob":
            raise RuntimeError(f"unsupported Git object {kind}: {name!r}")
        expected[name.decode("utf-8", errors="surrogateescape")] = (mode, sha)
    rows = []
    seen = set()
    total_bytes = 0
    with zipfile.ZipFile(path) as archive:
        for item in archive.infolist():
            if item.is_dir():
                continue
            name = item.filename
            if name not in expected or name in seen:
                raise RuntimeError(f"unexpected/duplicate archive path: {name}")
            seen.add(name)
            content = archive.read(item)
            mode, git_sha = expected[name]
            header = f"blob {len(content)}\0".encode("ascii")
            actual_git_sha = hashlib.sha1(header + content).hexdigest()
            if actual_git_sha != git_sha:
                raise RuntimeError(f"blob SHA-1 mismatch: {name}")
            sha256 = hashlib.sha256(content).hexdigest()
            rows.append(f"{name}\t{mode}\t{git_sha}\t{sha256}\t{len(content)}")
            total_bytes += len(content)
    missing = set(expected) - seen
    if missing:
        raise RuntimeError(f"{len(missing)} files absent from ZIP: {sorted(missing)[:5]}")
    (output / "source-file-manifest.tsv").write_text(
        "path\tgit_mode\tgit_blob_sha1\tfile_sha256\tbytes\n"
        + "\n".join(sorted(rows))
        + "\n",
        encoding="utf-8",
    )
    return len(seen), total_bytes


def verify_bundle(source: Path, archive_path: Path, output: Path) -> int:
    git(source, "bundle", "verify", str(archive_path))
    with tempfile.TemporaryDirectory(prefix="p5-02-restore-") as scratch:
        destination = Path(scratch) / "restored.git"
        run("git", "init", "--bare", str(destination))
        run("git", "-C", str(destination), "fetch", str(archive_path), "+refs/*:refs/*")
        if git(destination, "rev-parse", f"{FROZEN}^{{tree}}") != FROZEN_TREE:
            raise RuntimeError("offline-restored bundle failed frozen tree comparison")
        refs_source = git(source, "for-each-ref", "--format=%(refname) %(objectname)")
        refs_restored = git(destination, "for-each-ref", "--format=%(refname) %(objectname)")
        if refs_source != refs_restored:
            raise RuntimeError("offline bundle did not restore all mirrored branch/tag refs")
        (output / "refs-and-commits.txt").write_text(refs_source + "\n", encoding="utf-8")
        return len(refs_source.splitlines())


def scan_historic_names(source: Path) -> None:
    # Prevent publishing a fresh permanent copy of *obviously* sensitive
    # historical file paths. This is not a full credential-content audit.
    listing = git(source, "rev-list", "--objects", "--all")
    suspicious = []
    for line in listing.splitlines():
        if " " not in line:
            continue
        name = line.split(" ", 1)[1]
        if HIGH_RISK_NAME.search(name):
            suspicious.append(name)
    if suspicious:
        raise RuntimeError(
            "potential credential/private-key names in legacy Git history; "
            "do not publish this public release: " + repr(suspicious[:8])
        )


def split_bundle(bundle: Path, output: Path) -> list[Path]:
    parts = []
    with bundle.open("rb") as inp:
        index = 0
        while block := inp.read(PART_BYTES):
            part = output / f"history.bundle.part.{index:03d}"
            part.write_bytes(block)
            parts.append(part)
            index += 1
    if not parts:
        raise RuntimeError("empty Git history bundle")
    # Verify that concatenated, published chunks exactly reproduce bundle.
    reconstructed = hashlib.sha256()
    for part in parts:
        with part.open("rb") as inp:
            while block := inp.read(4 * 1024 * 1024):
                reconstructed.update(block)
    if reconstructed.hexdigest() != digest(bundle):
        raise RuntimeError("bundle chunk reconstruction mismatch")
    return parts


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if git(source, "rev-parse", FROZEN_BRANCH) != FROZEN:
        raise RuntimeError("frozen branch was changed: do not archive a mutable head")
    if git(source, "rev-parse", f"{FROZEN}^{{tree}}") != FROZEN_TREE:
        raise RuntimeError("frozen source tree differs from audited original")
    scan_historic_names(source)
    source_zip = output / "frozen-web-source.zip"
    run("git", "-C", str(source), "archive", "--format=zip",
        f"--output={source_zip}", FROZEN)
    file_count, source_bytes = verify_tree_zip(source, source_zip, output)
    history_bundle = output / "history.bundle"
    run("git", "-C", str(source), "bundle", "create", str(history_bundle), "--all")
    ref_count = verify_bundle(source, history_bundle, output)
    history_sha = digest(history_bundle)
    parts = split_bundle(history_bundle, output)
    history_bundle.unlink()  # release stores verified parts, not duplicate 800MB
    guide = f"""# P5-02 — Frozen HTML/JS source + full Git repository backup

Legacy public repository: https://github.com/gamja121/necromancer-dice-board
Frozen branch: reference/html-final
Frozen commit: {FROZEN}
Frozen tree: {FROZEN_TREE}
Source ZIP: frozen-web-source.zip ({file_count} tracked files; {source_bytes} unpacked bytes).
Git history: history.bundle.part.* ({len(parts)} ordered parts; {ref_count} mirrored references).
Reassembled history.bundle SHA256: {history_sha}
Manifest: source-file-manifest.tsv (each file's original Git blob SHA1 + SHA256).
Refs: refs-and-commits.txt (every branch/tag full object ID).
Checksums: SHA256SUMS (all published binary archives and manifests).

Verification performed before publication:
- Source tree path list and each ZIP file's real Git blob SHA-1 equal the
  immutable commit's Git tree, including original file contents.
- Original full Git mirror -> bundle verify -> separate OFFLINE bare repository
  fetch -> equal frozen tree SHA and identical refs.
- Bundle parts concatenated byte-for-byte to original SHA256.
- Tracked historical names screened for common credential/private-key names.
  This is not a comprehensive historical secret-content audit.

Restore:
1. Download every file in this GitHub Release to the same directory.
2. Run: sha256sum -c SHA256SUMS
3. Run: cat history.bundle.part.* > history.bundle
4. Check the SHA256 of history.bundle is {history_sha}
5. Run: git clone --mirror history.bundle restored-web.git
6. Run: git -C restored-web.git cat-file -e {FROZEN}^{{commit}}
7. Run: git -C restored-web.git rev-parse {FROZEN}^{{tree}} (should equal {FROZEN_TREE})
8. Extract frozen-web-source.zip for the exact committed working tree.

This archive covers publicly tracked GitHub assets, design documents and
all mirrored Git history, not local PC-only raw_assets or ignored files.
It does NOT authorize deleting the legacy repository. Pages preview still
depends on the legacy repository, and the user must explicitly approve
deletion only after all P4/P5 gates pass.
"""
    (output / "README-RESTORE.md").write_text(guide, encoding="utf-8")
    to_hash = sorted(p for p in output.iterdir() if p.is_file())
    (output / "SHA256SUMS").write_text(
        "".join(f"{digest(p)}  {p.name}\n" for p in to_hash),
        encoding="utf-8",
    )
    # Human-readable summary for GitHub Actions logs and downstream audit.
    print(f"P5_ARCHIVE_VERIFIED: {file_count} source files, {source_bytes} bytes, "
          f"{ref_count} preserved refs, {len(parts)} bundle parts, "
          f"tree {FROZEN_TREE}, bundle SHA256 {history_sha}")
    for name in ("frozen-web-source.zip", "source-file-manifest.tsv",
                 "refs-and-commits.txt", "README-RESTORE.md", "SHA256SUMS"):
        print(f"P5_ARCHIVE_FILE: {name} { (output / name).stat().st_size} bytes")


if __name__ == "__main__":
    main()
