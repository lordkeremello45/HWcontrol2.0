#!/usr/bin/env python3
"""Generate a deterministic metadata-only release manifest for GitHub Pages."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

PLATFORMS = {
    "windows": {
        "suffix": "-windows",
        "patterns": [
            r"windows.*x64.*-setup\.exe$",
            r"windows.*x64.*\.exe$",
            r"windows.*x64.*\.msi$",
            r"windows.*x64.*\.zip$",
        ],
    },
    "macos": {
        "suffix": "-macos",
        "patterns": [
            r"macos.*(apple.?silicon|arm64).*\.pkg$",
            r"macos.*(apple.?silicon|arm64).*\.dmg$",
            r"macos.*(apple.?silicon|arm64).*\.zip$",
            r"darwin.*arm64.*\.pkg$",
            r"darwin.*arm64.*\.dmg$",
        ],
    },
    "linux": {
        "suffix": "-linux",
        "patterns": [
            r"linux.*(x64|amd64).*\.deb$",
            r"linux.*(x64|amd64).*\.rpm$",
            r"linux.*(x64|amd64).*\.pkg\.tar\.zst$",
            r"linux.*(x64|amd64).*\.tar\.zst$",
            r"linux.*(x64|amd64).*\.tar\.gz$",
        ],
    },
}
CHECKSUM_SUFFIXES = (".sha256", ".sha256sum", ".sha256.txt")


def published_at(release: dict[str, Any]) -> str:
    return str(release.get("published_at") or release.get("created_at") or "")


def stable_platform_releases(releases: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for platform, cfg in PLATFORMS.items():
        candidates = [
            r
            for r in releases
            if not r.get("draft")
            and not r.get("prerelease")
            and str(r.get("tag_name", "")).lower().endswith(cfg["suffix"])
        ]
        candidates.sort(key=published_at, reverse=True)
        if candidates:
            result[platform] = candidates[0]
    return result


def matching_assets(release: dict[str, Any], platform: str) -> list[dict[str, Any]]:
    patterns = [re.compile(p, re.IGNORECASE) for p in PLATFORMS[platform]["patterns"]]
    assets = []
    for asset in release.get("assets", []):
        name = str(asset.get("name", ""))
        if any(p.search(name) for p in patterns):
            assets.append(asset)
    return sorted(assets, key=lambda a: str(a.get("name", "")).lower())


def checksum_asset(release: dict[str, Any], asset_name: str) -> dict[str, Any] | None:
    by_name = {str(a.get("name", "")).lower(): a for a in release.get("assets", [])}
    base = asset_name.lower()
    for suffix in CHECKSUM_SUFFIXES:
        candidate = by_name.get(base + suffix)
        if candidate:
            return candidate
    return None


def manifest_assets(release: dict[str, Any], platform: str) -> list[dict[str, Any]]:
    output = []
    for asset in matching_assets(release, platform):
        name = str(asset.get("name", ""))
        checksum = checksum_asset(release, name)
        output.append(
            {
                "name": name,
                "url": asset.get("browser_download_url"),
                "size": asset.get("size"),
                "content_type": asset.get("content_type"),
                "checksum_sha256_url": checksum.get("browser_download_url") if checksum else None,
            }
        )
    return output


def release_manifest(release: dict[str, Any], platform: str) -> dict[str, Any]:
    assets = manifest_assets(release, platform)
    if not assets:
        raise SystemExit(f"{platform}: stable release exists but has no recognized package assets")
    all_assets = {str(a.get("name", "")).lower(): a for a in release.get("assets", [])}

    def url(name: str) -> str | None:
        asset = all_assets.get(name.lower())
        return asset.get("browser_download_url") if asset else None

    return {
        "tag": release.get("tag_name"),
        "version": re.sub(r"-[^-]+$", "", str(release.get("tag_name", "")).lstrip("v")),
        "published_at": release.get("published_at"),
        "release_url": release.get("html_url"),
        "assets": assets,
        "integrity": {
            "sha256sums_url": url("SHA256SUMS.txt"),
            "sha512sums_url": url("SHA512SUMS.txt"),
            "sha3_512sums_url": url("SHA3-512SUMS.txt"),
            "ed25519_signature_url": url("SHA256SUMS.txt.sig"),
            "ed25519_public_key_url": url("SHA256SUMS.txt.pub"),
            "gpg_signature_url": url("SHA256SUMS.txt.asc"),
            "gpg_public_key_url": url("HWControl-GPG-public.asc"),
            "gpg_fingerprint_url": url("HWControl-GPG-fingerprint.txt"),
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    releases = json.loads(args.input.read_text(encoding="utf-8"))
    if not isinstance(releases, list):
        raise SystemExit("GitHub release API response must be a JSON array")
    latest = stable_platform_releases(releases)
    missing = [p for p in PLATFORMS if p not in latest]
    if missing:
        raise SystemExit(f"Missing stable platform release(s): {', '.join(missing)}")

    manifest = {
        "schema": 1,
        "project": "HWControl",
        "repository": "lordkeremello45/HWcontrol2.0",
        "platforms": {p: release_manifest(latest[p], p) for p in PLATFORMS},
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
