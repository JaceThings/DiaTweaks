const host = "com.diapatches.tidy_downloads";
const storage = chrome.storage.session;

chrome.downloads.onDeterminingFilename.addListener((item, suggest) => {
  const original = item.filename?.split(/[\\/]/).pop();
  // A user or another extension has chosen a folder or supplied its own name.
  if (item.incognito || item.byExtensionId || !original || original !== item.filename) {
    suggest();
    return;
  }

  let settled = false;
  const finish = (filename) => {
    if (settled) return;
    settled = true;
    clearTimeout(deadline);
    if (filename) suggest({ filename, conflictAction: "uniquify" });
    else suggest();
  };
  const deadline = setTimeout(() => finish(), 3500);

  chrome.runtime.sendNativeMessage(host, {
    operation: "suggest", original, url: item.finalUrl || item.url, referrer: item.referrer, mime: item.mime,
  }).then(async ({ filename } = {}) => {
    if (settled || typeof filename !== "string" || !filename || /[\\/]/.test(filename)) {
      finish();
      return;
    }
    // A storage error only affects the confirmation, not the suggested name.
    await storage.set({ [item.id]: { original, filename } }).catch(() => {});
    if (settled) await storage.remove(String(item.id));
    else finish(filename);
  }).catch(() => finish());
  return true;
});

chrome.downloads.onChanged.addListener(async ({ id, state }) => {
  if (!state || !["complete", "interrupted"].includes(state.current)) return;
  const key = String(id);
  const rename = (await storage.get(key))[key];
  if (!rename) return;
  const [item] = await chrome.downloads.search({ id });
  if (state.current === "interrupted" && item?.canResume) return;
  await storage.remove(key);
  if (state.current !== "complete") return;
  if (!item || !item.filename || item.incognito) return;
  await chrome.runtime.sendNativeMessage(host, {
    operation: "finished", path: item.filename, ...rename,
  }).catch(() => {});
});

chrome.downloads.onErased.addListener(id => storage.remove(String(id)));
