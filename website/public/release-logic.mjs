const REPOSITORY = "lordkeremello45/HWcontrol2.0";
const PLATFORMS = new Set(["windows", "macos", "linux"]);

export function safeReleaseUrl(value) {
  if (typeof value !== "string" || !value) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.hostname !== "github.com" || url.username || url.password) return null;
    return url.href;
  } catch {
    return null;
  }
}

export function isValidManifest(manifest) {
  if (!manifest || manifest.schema !== 1 || manifest.project !== "HWControl" || manifest.repository !== REPOSITORY || !manifest.platforms) return false;
  for (const platform of PLATFORMS) {
    const release = manifest.platforms[platform];
    if (!release || typeof release.tag !== "string" || !new RegExp(`-${platform}$`, "i").test(release.tag)) return false;
    if (!safeReleaseUrl(release.release_url) || !Array.isArray(release.assets) || release.assets.length === 0) return false;
    if (!release.assets.every((asset) => asset && typeof asset.name === "string" && safeReleaseUrl(asset.url))) return false;
  }
  return true;
}

export function getManifestPlatform(manifest, platform) {
  if (!PLATFORMS.has(platform) || !isValidManifest(manifest)) return null;
  return manifest.platforms[platform];
}

export function selectPlatformRelease(releases, platform) {
  if (!PLATFORMS.has(platform) || !Array.isArray(releases)) return null;
  const suffix = new RegExp(`-${platform}const REPOSITORY = "lordkeremello45/HWcontrol2.0";
const PLATFORMS = new Set(["windows", "macos", "linux"]);

export function safeReleaseUrl(value) {
  if (typeof value !== "string" || !value) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.hostname !== "github.com" || url.username || url.password) return null;
    return url.href;
  } catch {
    return null;
  }
}

export function isValidManifest(manifest) {
  if (!manifest || manifest.schema !== 1 || manifest.project !== "HWControl" || manifest.repository !== REPOSITORY || !manifest.platforms) return false;
  for (const platform of PLATFORMS) {
    const release = manifest.platforms[platform];
    if (!release || typeof release.tag !== "string" || !new RegExp(`-${platform}$`, "i").test(release.tag)) return false;
    if (!safeReleaseUrl(release.release_url) || !Array.isArray(release.assets) || release.assets.length === 0) return false;
    if (!release.assets.every((asset) => asset && typeof asset.name === "string" && safeReleaseUrl(asset.url))) return false;
  }
  return true;
}

export function getManifestPlatform(manifest, platform) {
  if (!PLATFORMS.has(platform) || !isValidManifest(manifest)) return null;
  return manifest.platforms[platform];
}

, "i");
  const unifiedBeta = /^v\\d+\\.\\d+\\.\\d+-beta\\.\\d+$/i;
  return releases
    .filter((release) => {
      if (!release || release.draft || typeof release.tag_name !== "string" || !Array.isArray(release.assets)) return false;
      if (!suffix.test(release.tag_name) && !unifiedBeta.test(release.tag_name)) return false;
      return getPackageAssets(release, platform).length > 0;
    })
    .sort((a, b) => {
      const dateA = Date.parse(a.published_at || a.created_at || "") || 0;
      const dateB = Date.parse(b.published_at || b.created_at || "") || 0;
      return dateB - dateA;
    })[0] || null;
}

export function selectLatestDownloadableRelease(releases) {
  if (!Array.isArray(releases)) return null;
  return releases
    .filter((release) => release && !release.draft && Array.isArray(release.assets) &&
      ["windows", "macos", "linux"].some((platform) => getPackageAssets(release, platform).length > 0))
    .sort((a, b) => {
      const dateA = Date.parse(a.published_at || a.created_at || "") || 0;
      const dateB = Date.parse(b.published_at || b.created_at || "") || 0;
      return dateB - dateA;
    })[0] || null;
}

export function isChecksumAsset(name) {
  return /(?:sha-?256|sha-?512|checksum|checksums|\.sig$|\.asc$|attestation|provenance|sbom)/i.test(name || "");
}

export function isInstallableAsset(name, platform) {
  const value = String(name || "").toLowerCase();
  if (platform === "windows") return /\.(exe|msi|msix|zip)$/.test(value);
  if (platform === "macos") return /\.(pkg|dmg)$/.test(value);
  if (platform === "linux") return /\.(deb|tar\.gz|tar\.zst)$/.test(value);
  return false;
}

export function getPackageAssets(release, platform) {
  if (!release || !Array.isArray(release.assets) || !PLATFORMS.has(platform)) return [];
  const unifiedBeta = /^v\\d+\\.\\d+\\.\\d+-beta\\.\\d+$/i.test(release.tag_name || "");
  const platformAsset = {
    windows: /windows-x64/i,
    macos: /macos-applesilicon|macos-arm64|darwin-arm64/i,
    linux: /linux-x64|linux-amd64/i
  }[platform];
  return release.assets
    .filter((asset) => asset && isInstallableAsset(asset.name, platform) &&
      (!unifiedBeta || platformAsset.test(asset.name)) &&
      safeReleaseUrl(asset.url || asset.browser_download_url))
    .map((asset) => ({ ...asset, url: safeReleaseUrl(asset.url || asset.browser_download_url) }));
}

export function getChecksumUrl(release, platform) {
  const explicit = safeReleaseUrl(release?.integrity?.sha256sums_url);
  if (explicit) return explicit;
  const assets = Array.isArray(release?.assets) ? release.assets : [];
  const platformToken = {
    windows: /windows-x64/i,
    macos: /macos-applesilicon|macos-arm64|darwin-arm64/i,
    linux: /linux-x64|linux-amd64/i
  }[platform];
  const candidates = assets.filter((item) => item && /(?:sha-?256|checksum)/i.test(item.name || ""));
  const preferred = platformToken ? candidates.find((item) => platformToken.test(item.name || "") && /\\.sha256$/i.test(item.name || "")) : null;
  const aggregate = candidates.find((item) => /^(SHA256SUMS|SHA256SUMS\\.txt)$/i.test(item.name || ""));
  const asset = preferred || aggregate || candidates[0];
  return safeReleaseUrl(asset?.url || asset?.browser_download_url);
}

export function formatSize(bytes) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "";
  const units = ["B", "KB", "MB", "GB"];
  let size = bytes;
  let index = 0;
  while (size >= 1024 && index < units.length - 1) {
    size /= 1024;
    index += 1;
  }
  return `${size.toFixed(index ? 1 : 0)} ${units[index]}`;
}
