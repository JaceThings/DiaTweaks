(() => {
  if (window.DiaExamplePreview?.version === 1) return;
  window.DiaExamplePreview = DPTabIntegrationRuntime.create({
    version: 1,
    collect() {
      return { title: document.title.slice(0, 300) };
    },
  });
})();
