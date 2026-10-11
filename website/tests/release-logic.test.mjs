import test from "node:test";
import assert from "node:assert/strict";
import {
  formatSize,
  getChecksumUrl,
  getManifestPlatform,
  getPackageAssets,
  isChecksumAsset,
  isValidManifest,
  safeReleaseUrl,
  selectPlatformRelease
} from "../public/release-logic.mjs";

const releaseUrl = (tag) => `https://github.com/lordkeremello45/HWcontrol2.0/releases/tag/${tag}`;
const assetUrl = (tag, name) => `https://github.com/lordkeremello45/HWcontrol2.0/releases/download/${tag}/${name}`;

test("selects the newest platform release, including a newer beta, and ignores drafts", () => {
  const releases = [
    { tag_name: "v0.2.4-windows", published_at: "2026-09-10T00:00:00Z", assets: [] },
    { tag_name: "v0.3.0-beta-windows", published_at: "2026-10-10T00:00:00Z", prerelease: true, assets: [] },
    { tag_name: "v9.9.9-windows", published_at: "2026-10-11T00:00:00Z", draft: true, assets: [] },
    { tag_name: "v0.3.0-beta-linux", published_at: "2026-10-12T00:00:00Z", assets: [] }
  ];
  assert.equal(selectPlatformRelease(releases, "windows")?.tag_name, "v0.3.0-beta-windows");
  assert.equal(selectPlatformRelease(releases, "linux")?.tag_name, "v0.3.0-beta-linux");
  assert.equal(selectPlatformRelease(releases, "unknown"), null);
});

test("filters Windows assets to real installer/archive formats", () => {
  const release = {
    tag_name: "v0.3.0-beta-windows",
    assets: [
      { name: "HWControl-Setup.exe", browser_download_url: assetUrl("v0.3.0-beta-windows", "HWControl-Setup.exe") },
      { name: "HWControl.msi", browser_download_url: assetUrl("v0.3.0-beta-windows", "HWControl.msi") },
      { name: "SHA256SUMS.txt", browser_download_url: assetUrl("v0.3.0-beta-windows", "SHA256SUMS.txt") },
      { name: "sbom.json", browser_download_url: assetUrl("v0.3.0-beta-windows", "sbom.json") },
      { name: "source.tar.gz", browser_download_url: assetUrl("v0.3.0-beta-windows", "source.tar.gz") },
      { name: "external.exe", browser_download_url: "https://example.org/external.exe" }
    ]
  };
  assert.deepEqual(getPackageAssets(release, "windows").map((asset) => asset.name), ["HWControl-Setup.exe", "HWControl.msi"]);
});

test("filters macOS and Linux to their installable package formats", () => {
  const releases = {
    macos: { assets: [
      { name: "HWControl.dmg", browser_download_url: assetUrl("v0.3.0-beta-macos", "HWControl.dmg") },
      { name: "HWControl.pkg", browser_download_url: assetUrl("v0.3.0-beta-macos", "HWControl.pkg") },
      { name: "HWControl.deb", browser_download_url: assetUrl("v0.3.0-beta-macos", "HWControl.deb") }
    ] },
    linux: { assets: [
      { name: "HWControl.deb", browser_download_url: assetUrl("v0.3.0-beta-linux", "HWControl.deb") },
      { name: "HWControl.tar.gz", browser_download_url: assetUrl("v0.3.0-beta-linux", "HWControl.tar.gz") },
      { name: "HWControl.tar.zst", browser_download_url: assetUrl("v0.3.0-beta-linux", "HWControl.tar.zst") },
      { name: "HWControl.dmg", browser_download_url: assetUrl("v0.3.0-beta-linux", "HWControl.dmg") }
    ] }
  };
  assert.deepEqual(getPackageAssets(releases.macos, "macos").map((asset) => asset.name), ["HWControl.dmg", "HWControl.pkg"]);
  assert.deepEqual(getPackageAssets(releases.linux, "linux").map((asset) => asset.name), ["HWControl.deb", "HWControl.tar.gz", "HWControl.tar.zst"]);
});

test("only trusts HTTPS GitHub URLs", () => {
  assert.equal(safeReleaseUrl("https://github.com/owner/repo/releases"), "https://github.com/owner/repo/releases");
  assert.equal(safeReleaseUrl("http://github.com/owner/repo"), null);
  assert.equal(safeReleaseUrl("https://example.org/package.exe"), null);
  assert.equal(safeReleaseUrl("https://user:pass@github.com/owner/repo"), null);
});

test("validates the static fallback manifest and resolves a platform", () => {
  const manifest = {
    schema: 1,
    project: "HWControl",
    repository: "lordkeremello45/HWcontrol2.0",
    platforms: {}
  };
  for (const platform of ["windows", "macos", "linux"]) {
    const tag = `v0.2.0-${platform}`;
    const extension = platform === "windows" ? "msi" : platform === "macos" ? "dmg" : "deb";
    const name = `HWControl.${extension}`;
    manifest.platforms[platform] = {
      tag,
      published_at: "2026-09-01T00:00:00Z",
      release_url: releaseUrl(tag),
      assets: [{ name, url: assetUrl(tag, name) }]
    };
  }
  assert.equal(isValidManifest(manifest), true);
  assert.equal(getManifestPlatform(manifest, "macos")?.tag, "v0.2.0-macos");
  manifest.platforms.linux.assets[0].url = "https://example.org/not-a-release";
  assert.equal(isValidManifest(manifest), false);
  assert.equal(getManifestPlatform(manifest, "windows"), null);
});

test("finds a checksum manifest and formats package sizes", () => {
  const release = {
    assets: [{ name: "SHA256SUMS.txt", browser_download_url: assetUrl("v0.3.0-beta-linux", "SHA256SUMS.txt") }]
  };
  assert.equal(getChecksumUrl(release), assetUrl("v0.3.0-beta-linux", "SHA256SUMS.txt"));
  assert.equal(isChecksumAsset("SHA256SUMS.txt"), true);
  assert.equal(formatSize(1024), "1.0 KB");
  assert.equal(formatSize(0), "");
});
