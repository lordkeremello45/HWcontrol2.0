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
  selectPlatformRelease,
  selectLatestDownloadableRelease
} from "../public/release-logic.mjs";

const releaseUrl = (tag) => `https://github.com/lordkeremello45/HWcontrol2.0/releases/tag/${tag}`;
const assetUrl = (tag, name) => `https://github.com/lordkeremello45/HWcontrol2.0/releases/download/${tag}/${name}`;

test("ignores empty releases and selects the newest downloadable platform release", () => {
  const releases = [
    { tag_name: "v0.2.4-windows", published_at: "2026-09-10T00:00:00Z", assets: [
      { name: "HWControl-Windows-x64.msi", browser_download_url: assetUrl("v0.2.4-windows", "HWControl-Windows-x64.msi") }
    ] },
    { tag_name: "v0.3.0-beta-windows", published_at: "2026-10-10T00:00:00Z", prerelease: true, assets: [] },
    { tag_name: "v9.9.9-windows", published_at: "2026-10-11T00:00:00Z", draft: true, assets: [] },
    { tag_name: "v0.3.0-beta-linux", published_at: "2026-10-12T00:00:00Z", assets: [] }
  ];
  assert.equal(selectPlatformRelease(releases, "windows")?.tag_name, "v0.2.4-windows");
  assert.equal(selectPlatformRelease(releases, "linux"), null);
  assert.equal(selectLatestDownloadableRelease(releases)?.tag_name, "v0.2.4-windows");
  assert.equal(selectPlatformRelease(releases, "unknown"), null);
});

test("rejects wrong-platform assets in platform-specific releases and accepts macOS ZIP bundles", () => {
  const releases = [
    { tag_name: "v0.4.0-windows", published_at: "2026-10-25T00:00:00Z", assets: [
      { name: "HWControl-v0.4.0-Linux-x64.deb", browser_download_url: assetUrl("v0.4.0-windows", "HWControl-v0.4.0-Linux-x64.deb") }
    ] },
    { tag_name: "v0.3.0-macos", published_at: "2026-10-20T00:00:00Z", assets: [
      { name: "HWControl-v0.3.0-macOS-AppleSilicon.zip", browser_download_url: assetUrl("v0.3.0-macos", "HWControl-v0.3.0-macOS-AppleSilicon.zip") }
    ] }
  ];
  assert.equal(selectPlatformRelease(releases, "windows"), null);
  assert.equal(selectPlatformRelease(releases, "macos")?.tag_name, "v0.3.0-macos");
  assert.equal(getPackageAssets(releases[1], "macos").length, 1);
});

test("supports unified beta tags while filtering package and checksum assets by platform", () => {
  const release = {
    tag_name: "v0.3.1-beta.42", published_at: "2026-10-20T00:00:00Z", assets: [
      { name: "HWControl-v0.3.1-beta.42-Windows-x64.msi", browser_download_url: assetUrl("v0.3.1-beta.42", "HWControl-v0.3.1-beta.42-Windows-x64.msi") },
      { name: "HWControl-v0.3.1-beta.42-Linux-x64.deb", browser_download_url: assetUrl("v0.3.1-beta.42", "HWControl-v0.3.1-beta.42-Linux-x64.deb") },
      { name: "HWControl-v0.3.1-beta.42-macOS-AppleSilicon.dmg", browser_download_url: assetUrl("v0.3.1-beta.42", "HWControl-v0.3.1-beta.42-macOS-AppleSilicon.dmg") },
      { name: "HWControl-v0.3.1-beta.42-Windows-x64.sha256", browser_download_url: assetUrl("v0.3.1-beta.42", "HWControl-v0.3.1-beta.42-Windows-x64.sha256") },
      { name: "SHA256SUMS", browser_download_url: assetUrl("v0.3.1-beta.42", "SHA256SUMS") }
    ]
  };
  assert.equal(selectPlatformRelease([release], "windows")?.tag_name, release.tag_name);
  assert.deepEqual(getPackageAssets(release, "linux").map((asset) => asset.name), ["HWControl-v0.3.1-beta.42-Linux-x64.deb"]);
  assert.deepEqual(getPackageAssets(release, "macos").map((asset) => asset.name), ["HWControl-v0.3.1-beta.42-macOS-AppleSilicon.dmg"]);
  assert.equal(getChecksumUrl(release, "windows"), assetUrl("v0.3.1-beta.42", "HWControl-v0.3.1-beta.42-Windows-x64.sha256"));
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
  assert.equal(safeReleaseUrl("https://github.com/lordkeremello45/HWcontrol2.0/releases/tag/v0.3.0-windows"), "https://github.com/lordkeremello45/HWcontrol2.0/releases/tag/v0.3.0-windows");
  assert.equal(safeReleaseUrl("https://github.com/other/project/releases/tag/v1.0.0"), null);
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
