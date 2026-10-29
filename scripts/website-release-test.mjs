import fs from 'node:fs';

const file = process.argv[2];
if (!file) throw new Error('Usage: node scripts/website-release-test.mjs <release.json>');

const data = JSON.parse(fs.readFileSync(file, 'utf8'));
if (data.schema !== 1) throw new Error(`Unsupported release manifest schema: ${data.schema}`);
if (data.project !== 'HWControl') throw new Error('Unexpected project name');
if (data.repository !== 'lordkeremello45/HWcontrol2.0') throw new Error('Unexpected repository');

function safeGitHubUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname === 'github.com' && !url.username && !url.password;
  } catch {
    return false;
  }
}

const expected = ['windows', 'macos', 'linux'];
for (const platform of expected) {
  const release = data.platforms?.[platform];
  if (!release) throw new Error(`Missing platform: ${platform}`);
  if (!new RegExp(`-${platform}$`, 'i').test(release.tag)) {
    throw new Error(`${platform}: invalid tag ${release.tag}`);
  }
  if (!safeGitHubUrl(release.release_url)) throw new Error(`${platform}: invalid release_url`);
  if (!Array.isArray(release.assets) || release.assets.length === 0) {
    throw new Error(`${platform}: no package assets`);
  }
  const packagePattern = {
    windows: /windows.*x64.*(\\.exe|\\.msi|\\.msix|\\.zip)$/i,
    macos: /macos.*(apple.?silicon|arm64).*(\\.pkg|\\.dmg|\\.zip)$/i,
    linux: /linux.*(x64|amd64).*(\\.deb|\\.tar\\.gz|\\.tar\\.zst|\\.rpm)$/i,
  }[platform];
  for (const asset of release.assets) {
    if (!asset.name || !safeGitHubUrl(asset.url)) throw new Error(`${platform}: malformed or unsafe asset entry`);
  }
  if (!release.assets.some((asset) => packagePattern.test(asset.name))) {
    throw new Error(`${platform}: no recognized installable package assets`);
  }
}

console.log(`Validated HWControl release manifest: ${file}`);
