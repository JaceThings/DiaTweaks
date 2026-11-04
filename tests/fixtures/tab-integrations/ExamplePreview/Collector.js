(() => {
  if (window.DiaExamplePreview?.version === 1) return;
  window.DiaExamplePreview = {
    version: 1,
    snapshot() { return { title: document.title.slice(0, 300) }; },
    dispose() { /* Disconnect observers/timers here if the adapter creates any. */ }
  };
})();
