// Carries requests from page.js, which runs in the page and can't reach the extension, to worker.js and back.
window.addEventListener('message', (event) => {
  if (event.source !== window || event.data?.diaTweaksPasskey !== 'request') return;
  const { id, kind, options } = event.data;
  chrome.runtime.sendMessage({ kind, options }, (response) => window.postMessage({ diaTweaksPasskey: 'response', id, response }, '*'));
});
