(() => {
  const yearEl = document.getElementById('year');
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  const badgeBox = document.getElementById('badges');
  const repo = badgeBox?.getAttribute('data-repo') || 'gpicchiarelli/ChitarraTune';
  const set = (sel, url) => {
    const el = badgeBox?.querySelector(`[data-badge="${sel}"]`);
    if (el) el.setAttribute('src', url);
  };
  set('build', `https://github.com/${repo}/actions/workflows/ci.yml/badge.svg`);
  set('release', `https://img.shields.io/github/v/release/${repo}?include_prereleases&label=release`);
  set('downloads', `https://img.shields.io/github/downloads/${repo}/total?label=downloads`);
  set('license', `https://img.shields.io/github/license/${repo}?color=blue`);
  set('swift', 'https://img.shields.io/badge/Swift-5.9-orange?logo=swift');
  set('platform', 'https://img.shields.io/badge/platform-macOS-1f6feb?logo=apple');

  fetch(`https://api.github.com/repos/${repo}/releases/latest`).then(r=>r.ok?r.json():null).then(rel=>{
    if (!rel) return;
    const tag = rel.tag_name || rel.name;
    const ver = document.getElementById('ver');
    if (ver && tag) ver.textContent = `Versione ${tag}`;
    const dl = document.querySelector('#download-btn');
    if (dl && rel.html_url) dl.setAttribute('href', rel.html_url);
  }).catch(()=>{});
})();

