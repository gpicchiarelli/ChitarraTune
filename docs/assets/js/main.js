(() => {
  // Language detection and toggle
  const qs = new URLSearchParams(location.search);
  const stored = localStorage.getItem('lang');
  const pref = (qs.get('lang') || stored || navigator.language || 'it').toLowerCase();
  const initLang = pref.startsWith('en') ? 'en' : 'it';
  const setLang = (l) => {
    const lang = (l === 'en') ? 'en' : 'it';
    document.documentElement.setAttribute('data-lang', lang);
    document.documentElement.lang = lang;
    localStorage.setItem('lang', lang);
    const sel = document.getElementById('lang-select');
    if (sel) sel.value = lang;
  };
  setLang(initLang);
  const langSel = document.getElementById('lang-select');
  if (langSel) langSel.addEventListener('change', (e) => setLang(e.target.value));
  const curLang = () => document.documentElement.getAttribute('data-lang') || 'it';

  // Year in footer
  const yearEl = document.getElementById('year');
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  // Badges (only on home)
  const badgeBox = document.getElementById('badges');
  const repo = badgeBox?.getAttribute('data-repo') || 'gpicchiarelli/ChitarraTune';
  const set = (sel, url) => {
    const el = badgeBox?.querySelector(`[data-badge="${sel}"]`);
    if (el) el.setAttribute('src', url);
  };
  if (badgeBox) {
    set('build', `https://github.com/${repo}/actions/workflows/ci.yml/badge.svg`);
    set('codeql', `https://github.com/${repo}/actions/workflows/codeql.yml/badge.svg`);
    set('swiftlint', `https://github.com/${repo}/actions/workflows/swiftlint.yml/badge.svg`);
    set('release', `https://img.shields.io/github/v/release/${repo}?include_prereleases&label=release`);
    set('downloads', `https://img.shields.io/github/downloads/${repo}/total?label=downloads`);
    set('license', `https://img.shields.io/github/license/${repo}?color=blue`);
    set('swift', 'https://img.shields.io/badge/Swift-5.9-orange?logo=swift');
    set('platform', 'https://img.shields.io/badge/platform-macOS-1f6feb?logo=apple');
    set('stars', `https://img.shields.io/github/stars/${repo}?style=social`);
    set('issues', `https://img.shields.io/github/issues/${repo}`);
    set('prs', `https://img.shields.io/github/issues-pr/${repo}`);
    set('contributors', `https://img.shields.io/github/contributors/${repo}`);
    set('size', `https://img.shields.io/github/repo-size/${repo}`);
    set('last-commit', `https://img.shields.io/github/last-commit/${repo}`);
  }

  // Latest release tag + download link
  fetch(`https://api.github.com/repos/${repo}/releases/latest`).then(r=>r.ok?r.json():null).then(rel=>{
    if (!rel) return;
    const tag = rel.tag_name || rel.name;
    const it = document.getElementById('ver-it');
    const en = document.getElementById('ver-en');
    if (it && tag) it.textContent = `Versione ${tag}`;
    if (en && tag) en.textContent = `Version ${tag}`;
    const dl = document.querySelector('#download-btn');
    if (dl && rel.html_url) dl.setAttribute('href', rel.html_url);
  }).catch(()=>{});

  // Bug page: ensure links point to templates
  const issueLinks = document.querySelectorAll('.issue-link');
  if (issueLinks.length) {
    const hrefIt = `https://github.com/${repo}/issues/new?template=bug_report_it.md&labels=bug&title=${encodeURIComponent('Bug: ')}`;
    const hrefEn = `https://github.com/${repo}/issues/new?template=bug_report_en.md&labels=bug&title=${encodeURIComponent('Bug: ')}`;
    issueLinks.forEach(a => {
      const isEn = (a.getAttribute('lang') === 'en');
      a.setAttribute('href', isEn ? hrefEn : hrefIt);
    });
  }
})();
