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
})();

