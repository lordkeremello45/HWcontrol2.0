import {
  formatSize,
  getChecksumUrl,
  getManifestPlatform,
  getPackageAssets,
  isValidManifest,
  safeReleaseUrl,
  selectPlatformRelease
} from "./release-logic.mjs";

const repo = "lordkeremello45/HWcontrol2.0";
const manifestUrl = "./release.json";
const apiUrl = `https://api.github.com/repos/${repo}/releases?per_page=100`;
const allReleasesUrl = `https://github.com/${repo}/releases`;
const state = {
  platform: "windows",
  manifest: null,
  releases: [],
  liveStatus: "pending",
};
const labels = {
  windows: ["WINDOWS PACKAGE", "Choose your installer", "Windows 10 / 11 · x64"],
  macos: ["MACOS PACKAGE", "Choose your package", "macOS 14+ · Apple Silicon"],
  linux: ["LINUX PACKAGE", "Choose your package", "Linux · x64"]
};
const platformIcons = {
  windows: "https://cdn.simpleicons.org/windows/0078D4",
  macos: "https://cdn.simpleicons.org/apple/F4F7FB",
  linux: "https://cdn.simpleicons.org/linux/FCC624"
};
const $ = (selector) => document.querySelector(selector);
const esc = (value) => String(value).replace(/[&<>"]/g, (character) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"
}[character]));

function render() {
  const [eyebrow, defaultTitle, detected] = labels[state.platform];
  $("#packageEyebrow").textContent = eyebrow;
  $("#detected").textContent = detected;

  const release = state.liveStatus === "success"
    ? selectPlatformRelease(state.releases, state.platform)
    : getManifestPlatform(state.manifest, state.platform);
  const usingManifest = Boolean(release) && state.liveStatus !== "success";
  const releaseUrl = safeReleaseUrl(release?.release_url || release?.html_url) || allReleasesUrl;
  $("#releaseLink").href = releaseUrl;

  if (!release) {
    $("#packageTitle").textContent = defaultTitle;
    if (state.liveStatus === "pending") {
      $("#packages").innerHTML = '<div class="loading">Checking current release metadata…</div><p class="muted">If release data cannot be reached, open the official releases page below.</p>';
    } else {
      $("#packages").innerHTML = '<div class="loading">No package data could be loaded for this platform.</div><p class="muted">The release service may be unavailable or no matching release is published. Open GitHub Releases to check the current status.</p>';
    }
    return;
  }

  const tag = release.tag_name || release.tag || "published release";
  $("#packageTitle").textContent = `Available downloads · ${tag}`;
  const assets = getPackageAssets(release, state.platform);
  if (!assets.length) {
    $("#packages").innerHTML = '<div class="loading">The release exists, but no compatible installer/archive asset was found.</div><p class="muted">Open the release page to inspect its assets. Do not download unrelated files as installers.</p>';
    return;
  }

  const checksumUrl = getChecksumUrl(release);
  const status = usingManifest
    ? `<div class="loading">${state.liveStatus === "pending" ? "Showing cached release metadata while checking for newer packages." : "Live release metadata is unavailable; showing the last published manifest. Check GitHub Releases for newer packages."}</div>`
    : "";
  const packageRows = assets.map((asset) => {
    const assetUrl = safeReleaseUrl(asset.url || asset.browser_download_url);
    if (!assetUrl) return "";
    const sizeLabel = asset.size ? ` · ${formatSize(asset.size)}` : "";
    const verifyUrl = safeReleaseUrl(asset.checksum_sha256_url) || checksumUrl;
    const verifyLink = verifyUrl
      ? `<a class="verify" href="${esc(verifyUrl)}" target="_blank" rel="noopener noreferrer">SHA-256 verification file ↗</a>`
      : "";
    return `<div class="package"><span class="name">${esc(asset.name)}<small>${esc(asset.name)}${sizeLabel}</small></span><div class="package-actions"><a class="download-link" href="${esc(assetUrl)}" target="_blank" rel="noopener noreferrer"><img src="${platformIcons[state.platform]}" alt="" aria-hidden="true" />Download ↗</a>${verifyLink}</div></div>`;
  }).join("");

  $("#packages").innerHTML = status + packageRows;
}

async function fetchWithRetry(url, options = {}, config = {}) {
  const timeout = config.timeout ?? 4500;
  const retries = config.retries ?? 1;
  const baseDelay = config.baseDelay ?? 350;
  let lastError;

  for (let attempt = 0; attempt <= retries; attempt += 1) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
        cache: options.cache || "no-store"
      });
      if (response.ok || [400, 401, 403, 404, 422].includes(response.status)) return response;
      lastError = new Error(`HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    } finally {
      clearTimeout(timer);
    }
    if (attempt < retries) await new Promise((resolve) => setTimeout(resolve, baseDelay * (2 ** attempt)));
  }
  throw lastError || new Error("Request failed");
}

async function fetchJson(url, options = {}, config = {}) {
  const response = await fetchWithRetry(url, options, config);
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return { response, data: await response.json() };
}

async function loadManifest() {
  try {
    const { data } = await fetchJson(
      manifestUrl,
      { headers: { Accept: "application/json" } },
      { timeout: 3500, retries: 0 }
    );
    if (isValidManifest(data)) state.manifest = data;
  } catch {
    state.manifest = null;
  }
  render();
}

async function loadLiveReleases() {
  try {
    const { data } = await fetchJson(
      apiUrl,
      { headers: { Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" } },
      { timeout: 4500, retries: 1, baseDelay: 350 }
    );
    if (!Array.isArray(data)) throw new Error("Unexpected release API response");
    state.releases = data.filter((release) => release && typeof release === "object");
    state.liveStatus = "success";
    const latest = state.releases
      .filter((release) => !release.draft && release.tag_name)
      .sort((a, b) => (Date.parse(b.published_at || b.created_at || "") || 0) - (Date.parse(a.published_at || a.created_at || "") || 0))[0];
    $("#latestBadge").textContent = latest
      ? `${latest.prerelease || /-beta/i.test(latest.tag_name) ? "Latest beta" : "Latest release"} · ${latest.tag_name}`
      : "No published release found";
  } catch {
    state.liveStatus = "failed";
    if (!state.manifest) $("#latestBadge").textContent = "Release data unavailable";
    else {
      const cached = Object.values(state.manifest.platforms || {})
        .filter((release) => release && release.tag)
        .sort((a, b) => (Date.parse(b.published_at || "") || 0) - (Date.parse(a.published_at || "") || 0))[0];
      $("#latestBadge").textContent = cached ? `Cached release · ${cached.tag}` : "Release data unavailable";
    }
  }
  render();
}

function initializePlatformTabs() {
  document.querySelectorAll(".platform").forEach((button) => {
    button.addEventListener("click", () => {
      document.querySelectorAll(".platform").forEach((item) => {
        item.classList.remove("active");
        item.setAttribute("aria-selected", "false");
      });
      button.classList.add("active");
      button.setAttribute("aria-selected", "true");
      state.platform = button.dataset.platform;
      render();
    });
  });
}

async function load() {
  render();
  await Promise.allSettled([loadManifest(), loadLiveReleases()]);
  render();
}

initializePlatformTabs();
load();
