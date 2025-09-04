(() => {
  const yearEl = document.getElementById('year');
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  const applyLink = (selector, attr) => {
    document.querySelectorAll(selector).forEach(el => {
      const url = el.getAttribute(attr);
      if (url && url !== '#') el.setAttribute('href', url);
    });
  };
  applyLink('[data-github]', 'data-github');
  applyLink('[data-download]', 'data-download');
  // If placeholders are still '#', set sensible defaults
  const ghLink = document.querySelector('[data-github]');
  if (ghLink && ghLink.getAttribute('href') === '#') {
    ghLink.setAttribute('href', 'https://github.com/gpicchiarelli/ChitarraTune');
    ghLink.setAttribute('data-github', 'https://github.com/gpicchiarelli/ChitarraTune');
  }
  const dlLink = document.querySelector('[data-download]');
  if (dlLink && dlLink.getAttribute('href') === '#') {
    dlLink.setAttribute('href', 'https://github.com/gpicchiarelli/ChitarraTune/releases/latest');
    dlLink.setAttribute('data-download', 'https://github.com/gpicchiarelli/ChitarraTune/releases/latest');
  }

  // Badges (shields.io/GitHub)
  const badgeBox = document.getElementById('badges');
  const repoAttr = badgeBox?.getAttribute('data-repo');
  // If not provided, try to infer repo from first [data-github] link
  let repo = repoAttr && repoAttr !== 'USER/REPO' ? repoAttr : null;
  if (!repo) {
    const gh = document.querySelector('[data-github]')?.getAttribute('data-github') || '';
    try { repo = new URL(gh).pathname.replace(/^\//,''); } catch { /* noop */ }
  }
  if (badgeBox && repo) {
    const set = (sel, url) => {
      const el = badgeBox.querySelector(`[data-badge="${sel}"]`);
      if (el) el.setAttribute('src', url);
    };
    set('build', `https://github.com/${repo}/actions/workflows/ci.yml/badge.svg`);
    set('release', `https://img.shields.io/github/v/release/${repo}?include_prereleases&label=release`);
    set('downloads', `https://img.shields.io/github/downloads/${repo}/total?label=downloads`);
    set('license', `https://img.shields.io/github/license/${repo}?color=blue`);
    set('swift', 'https://img.shields.io/badge/Swift-5.9-orange?logo=swift');
    set('platform', 'https://img.shields.io/badge/platform-macOS-1f6feb?logo=apple');

    // Fetch latest release for version label and ensure download URL
    fetch(`https://api.github.com/repos/${repo}/releases/latest`).then(r=>r.ok?r.json():null).then(rel=>{
      if (!rel) return;
      const tag = rel.tag_name || rel.name;
      const ver = document.getElementById('ver');
      if (ver && tag) ver.textContent = `Versione ${tag}`;
      const dl = document.querySelector('#download-btn');
      if (dl && rel.html_url) dl.setAttribute('href', rel.html_url);
    }).catch(()=>{});
  }
})();
