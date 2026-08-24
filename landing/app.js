(() => {
  const titles = {
    en: 'Token Monitor for macOS | Claude, ChatGPT & Codex usage',
    de: 'Token Monitor für macOS | Claude-, ChatGPT- und Codex-Nutzung'
  };
  const descriptions = {
    en: 'See Claude, ChatGPT, Codex, and optional OpenCode Go usage from one local macOS menu bar app. Check limits and reset windows without opening multiple dashboards.',
    de: 'Sieh Claude-, ChatGPT-, Codex- und optionale OpenCode-Go-Nutzung in einer lokalen macOS-Menüleisten-App. Prüfe Limits und Reset-Zeiten ohne mehrere Dashboards.'
  };
  const meta = document.querySelector('meta[name="description"]');
  const buttons = document.querySelectorAll('[data-language]');

  function setLanguage(language) {
    const lang = language === 'de' ? 'de' : 'en';
    document.documentElement.lang = lang;
    document.title = titles[lang];
    meta.setAttribute('content', descriptions[lang]);
    document.querySelectorAll('[data-lang]').forEach(node => node.classList.toggle('active', node.dataset.lang === lang));
    buttons.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.language === lang)));
    localStorage.setItem('token-monitor-language', lang);
  }

  buttons.forEach(button => button.addEventListener('click', () => setLanguage(button.dataset.language)));
  const saved = localStorage.getItem('token-monitor-language');
  const initial = saved || (navigator.language.toLowerCase().startsWith('de') ? 'de' : 'en');
  setLanguage(initial);
})();
