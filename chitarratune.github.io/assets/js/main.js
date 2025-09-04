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
  }
})();
