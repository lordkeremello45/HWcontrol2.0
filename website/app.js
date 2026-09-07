const REPO='lordkeremello45/HWcontrol2.0';
const API=`https://api.github.com/repos/${REPO}/releases?per_page=100`;
const state={releases:[],platform:'windows'};
const platformLabels={
  windows:{eyebrow:'WINDOWS PACKAGE',title:'Pick your installer',detected:'Windows 10 / 11 · x64'},
  macos:{eyebrow:'MACOS PACKAGE',title:'Pick your installer',detected:'macOS 14+ · Apple Silicon'},
  linux:{eyebrow:'LINUX PACKAGE',title:'Pick your package',detected:'Linux · x64'}
};
const $=s=>document.querySelector(s);
function esc(v){return String(v).replace(/[&<>\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;'}[c]||c));}
function size(bytes){if(!bytes)return '';const units=['B','KB','MB','GB'];let n=bytes,i=0;while(n>=1024&&i<units.length-1){n/=1024;i++;}return `${n.toFixed(i?1:0)} ${units[i]}`;}
function stableReleases(){return state.releases.filter(r=>!r.draft&&!r.prerelease);}
function platformRelease(platform){return stableReleases().find(r=>new RegExp(`-${platform}$`,'i').test(r.tag_name));}
function matches(name,platform){const n=name.toLowerCase();
  if(platform==='windows')return (/setup\.exe$/.test(n)||/\.msi$/.test(n)||/\.zip$/.test(n))&&(/windows.*x64|win.*x64/.test(n));
  if(platform==='macos')return /macos.*(apple.?silicon|arm64)|darwin.*arm64/.test(n)&&(/\.pkg$|\.dmg$|\.zip$/.test(n));
  return (/linux.*(x64|amd64)/.test(n))&&(/\.deb$|\.rpm$|\.pkg\.tar\.zst$|\.tar\.zst$|\.tar\.gz$/.test(n));
}
function packageName(name){const n=name.toLowerCase();
  if(n.endsWith('-setup.exe'))return 'HWControl Setup · recommended';
  if(n.endsWith('.msi'))return 'HWControl MSI installer';
  if(n.endsWith('.exe'))return 'EXE installer';
  if(n.endsWith('.dmg'))return 'DMG disk image';
  if(n.endsWith('.pkg'))return 'PKG installer';
  if(n.endsWith('.deb'))return 'DEB package · Debian/Ubuntu';
  if(n.endsWith('.rpm'))return 'RPM package · Fedora/RHEL';
  if(n.endsWith('.pkg.tar.zst'))return 'Arch package · Arch/Manjaro';
  if(n.endsWith('.tar.zst'))return 'TAR.ZST archive · generic Linux';
  if(n.endsWith('.tar.gz'))return 'TAR.GZ archive · generic Linux';
  return 'Release asset';
}
function preferred(a,b){const rank=x=>{const n=x.name.toLowerCase();if(state.platform==='windows'){if(n.endsWith('-setup.exe'))return 0;if(n.endsWith('.msi'))return 1;if(n.endsWith('.zip'))return 2;return 3;}if(state.platform==='macos')return n.endsWith('.pkg')?0:n.endsWith('.dmg')?1:n.endsWith('.zip')?2:3;return n.endsWith('.deb')?0:n.endsWith('.rpm')?1:n.endsWith('.pkg.tar.zst')?2:n.endsWith('.tar.zst')?3:n.endsWith('.tar.gz')?4:5};return rank(a)-rank(b);}
function checksumAsset(release,asset){const base=asset.name.toLowerCase();const candidates=release.assets||[];return candidates.find(x=>x.name.toLowerCase()===`${base}.sha256`)||candidates.find(x=>x.name.toLowerCase()===`${base}.sha256sum`)||candidates.find(x=>x.name.toLowerCase()===`${base}.sha256.txt`);}
function releaseChecksumManifest(release){return (release?.assets||[]).find(x=>/^(sha256sums|checksums).*\.(txt|sha256|sha256sum)$/i.test(x.name));}
function render(){
  const meta=platformLabels[state.platform];
  $('.package-title .eyebrow').textContent=meta.eyebrow;
  $('.package-title h3').textContent=meta.title;
  $('#detected').textContent=meta.detected;
  $('#windowsNote').classList.toggle('hidden',state.platform!=='windows');
  const release=platformRelease(state.platform);
  if(!release){$('#packages').innerHTML='<div class="loading">No stable package release was found. See all releases on GitHub.</div>';$('#releaseLink').href=`https://github.com/${REPO}/releases`;$('#checksumsLink').classList.add('hidden');return;}
  const assets=(release.assets||[]).filter(x=>matches(x.name,state.platform)).sort(preferred);
  $('#releaseLink').href=release.html_url||`https://github.com/${REPO}/releases`;
  const manifest=releaseChecksumManifest(release);
  $('#checksumsLink').classList.toggle('hidden',!manifest);
  if(manifest){$('#checksumsLink').href=manifest.browser_download_url;}
  if(!assets.length){$('#packages').innerHTML='<div class="loading">No matching package was found in this stable release. See the release assets on GitHub.</div>';return;}
  $('#packages').innerHTML=assets.map(a=>{const checksum=checksumAsset(release,a);const verify=checksum?`<a class="verify" href="${esc(checksum.browser_download_url)}" target="_blank" rel="noopener noreferrer">Verify SHA-256 ↗</a>`:'';return `<div class="package"><span class="name">${esc(packageName(a.name))}<small>${esc(a.name)} · ${size(a.size)}</small></span><div class="package-actions"><a href="${esc(a.browser_download_url)}" target="_blank" rel="noopener noreferrer">Download ↗</a>${verify}</div></div>`;}).join('');
}
async function load(){
  try{
    const res=await fetch(API,{headers:{Accept:'application/vnd.github+json'}});
    if(!res.ok)throw new Error(`GitHub release API: ${res.status}`);
    state.releases=await res.json();
    state.releases=state.releases.filter(r=>!r.draft&&!r.prerelease&&/-windows$|-macos$|-linux$/i.test(r.tag_name)).sort((a,b)=>new Date(b.published_at||b.created_at)-new Date(a.published_at||a.created_at));
    const latest=state.releases[0];
    $('#latestBadge').textContent=latest?`Latest stable · ${latest.tag_name}`:'Stable release · unavailable';
  }catch(e){$('#latestBadge').textContent='Latest release · unavailable';}
  render();
}
document.querySelectorAll('.platform').forEach(btn=>btn.addEventListener('click',()=>{document.querySelectorAll('.platform').forEach(x=>x.classList.remove('active'));btn.classList.add('active');state.platform=btn.dataset.platform;render();}));
load();