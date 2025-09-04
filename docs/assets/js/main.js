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
    set('release', `https://img.shields.io/github/v/release/${repo}?include_prereleases&label=release`);
    set('downloads', `https://img.shields.io/github/downloads/${repo}/total?label=downloads`);
    set('license', `https://img.shields.io/github/license/${repo}?color=blue`);
    set('swift', 'https://img.shields.io/badge/Swift-5.9-orange?logo=swift');
    set('platform', 'https://img.shields.io/badge/platform-macOS-1f6feb?logo=apple');
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

  // Bug page helpers: prefill issue link and copy buttons
  const issueLinks = document.querySelectorAll('.issue-link');
  if (issueLinks.length) {
    const tplIt = [
      '### Descrizione',
      '<!-- Riassumi il problema in 1-2 frasi -->',
      '',
      '### Passi per riprodurre',
      '1. ',
      '2. ',
      '3. ',
      '',
      '### Risultato atteso',
      '',
      '### Risultato ottenuto',
      '',
      '### Dettagli',
      '- Versione app: ',
      '- Commit/Tag (se noto): ',
      '- macOS: ',
      '- Mac: ',
      '- Dispositivo audio: ',
      '- Modalità: Auto / Manuale',
      '- Preset accordatura: ',
      '- Calibrazione A4: ',
      '',
      '<!-- Allegati (opzionale): screenshot, clip audio brevi, ecc. -->'
    ].join('\n');
    const tplEn = [
      '### Description',
      '<!-- Summarize the issue in 1-2 sentences -->',
      '',
      '### Steps to reproduce',
      '1. ',
      '2. ',
      '3. ',
      '',
      '### Expected behavior',
      '',
      '### Actual behavior',
      '',
      '### Details',
      '- App version: ',
      '- Commit/Tag (if known): ',
      '- macOS: ',
      '- Mac: ',
      '- Audio device: ',
      '- Mode: Auto / Manual',
      '- Tuning preset: ',
      '- A4 calibration: ',
      '',
      '<!-- Attachments (optional): screenshots, short audio clips, etc. -->'
    ].join('\n');
    const bodyIt = encodeURIComponent(tplIt);
    const bodyEn = encodeURIComponent(tplEn);
    const hrefIt = `https://github.com/${repo}/issues/new?title=${encodeURIComponent('Bug: ')}&body=${bodyIt}`;
    const hrefEn = `https://github.com/${repo}/issues/new?title=${encodeURIComponent('Bug: ')}&body=${bodyEn}`;
    issueLinks.forEach(a => {
      const isEn = (a.getAttribute('lang') === 'en');
      a.setAttribute('href', isEn ? hrefEn : hrefIt);
    });

    document.querySelectorAll('.copy-tpl').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-target');
        const ta = document.getElementById(id);
        if (!ta) return;
        ta.select();
        ta.setSelectionRange(0, ta.value.length);
        try { document.execCommand('copy'); } catch {}
      });
    });
  }
})();

