#import "Patches/Boosts/Boosts.h"
#import <objc/message.h>

// The front window's focused tab, else its first visible one (2 is Chromium's Visibility::VISIBLE).
id DPFrontContents(void) {
    id visible = nil;
    for (id contents in DPTrackedContents(DPCommandBrowser())) {
        if ([contents respondsToSelector:@selector(hasFocus)] && DPMsgBool(contents, @selector(hasFocus))) return contents;
        if (!visible && [contents respondsToSelector:@selector(visibility)] && ((NSInteger (*)(id, SEL))objc_msgSend)(contents, @selector(visibility)) == 2) visible = contents;
    }
    return visible;
}

NSString *DPFrontDomain(void) {
    id contents = DPFrontContents();
    return [contents respondsToSelector:@selector(url)] ? DPDomainKey(DPText(DPMsg(contents, @selector(url)))) : nil;
}

// Dia hands back the script's value as JSON: a string comes back quoted.
static NSString *DPDecoded(id result) {
    NSString *text = DPText(result);
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    id value = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil] : nil;
    return [value isKindOfClass:NSString.class] ? value : text;
}

static void DPRunScript(id contents, NSString *script, void (^done)(NSString *result)) {
    if (![contents respondsToSelector:@selector(executeJavascript:completion:)]) return done(nil);
    ((void (*)(id, SEL, NSString *, void (^)(id)))objc_msgSend)(contents, @selector(executeJavascript:completion:), script, ^(id result) {
        NSString *text = DPDecoded(result);
        dispatch_async(dispatch_get_main_queue(), ^{ done(text); });
    });
}

// Like Arc's selector picker: highlight what's under the pointer, and on click name it with the steadiest parts it has
// (an id, test id or label before class names that look generated), adding parents until it names only that element.
static NSString *const DPPickerScript = @"(() => {"
    "if (window.__dpZap) return;"
    "window.__dpZap = true;"
    "const box = document.createElement('div');"
    "box.style.cssText = 'position:fixed;z-index:2147483647;pointer-events:none;background:rgba(255,59,48,.2);outline:2px solid #ff3b30;border-radius:4px';"
    "const hint = document.createElement('div');"
    "hint.textContent = 'Click something to hide it \u00B7 Esc to stop';"
    "hint.style.cssText = 'position:fixed;top:14px;left:50%;transform:translateX(-50%);z-index:2147483647;pointer-events:none;"
    "font:500 13px -apple-system,system-ui,sans-serif;color:#fff;background:rgba(20,20,20,.82);padding:8px 16px;border-radius:999px';"
    "document.documentElement.append(box, hint);"
    "const generated = s => /\\d{3}|[bcdfghjklmnpqrstvwxz]{5}|__|^(css|sc|jsx|tw)-/i.test(s);"
    "const one = sel => { try { return document.querySelectorAll(sel).length === 1; } catch { return false; } };"
    "const step = el => {"
    "  if (el.id && !generated(el.id)) return '#' + CSS.escape(el.id);"
    "  for (const name of ['data-testid', 'aria-label']) { const v = el.getAttribute(name); if (v) return `${el.localName}[${name}=\"${CSS.escape(v)}\"]`; }"
    "  return el.localName + [...el.classList].filter(c => !generated(c)).slice(0, 2).map(c => '.' + CSS.escape(c)).join('');"
    "};"
    "const name = el => {"
    "  let sel = '';"
    "  for (let node = el; node && node !== document.documentElement; node = node.parentElement) {"
    "    let part = step(node); const siblings = node.parentElement ? [...node.parentElement.children] : [];"
    "    if (!part.startsWith('#') && siblings.filter(s => s.matches(part)).length > 1) part += `:nth-child(${siblings.indexOf(node) + 1})`;"
    "    sel = sel ? `${part} > ${sel}` : part;"
    "    if (one(sel)) break;"
    "  }"
    "  return sel;"
    "};"
    "const kinds = { A: 'Link', ASIDE: 'Sidebar', BUTTON: 'Button', FOOTER: 'Footer', FORM: 'Form', H1: 'Heading', H2: 'Heading',"
    "  H3: 'Heading', H4: 'Heading', HEADER: 'Header', IFRAME: 'Embed', IMG: 'Image', INPUT: 'Field', LI: 'List item', NAV: 'Menu',"
    "  OL: 'List', P: 'Paragraph', UL: 'List', VIDEO: 'Video', svg: 'Icon' };"
    "const label = el => { const kind = kinds[el.tagName] || 'Section';"
    "  const text = (el.getAttribute('aria-label') || el.innerText || el.alt || el.title || '').trim().replace(/\\s+/g, ' ');"
    "  return text ? `${kind} \u201C${text.length > 40 ? text.slice(0, 40) + '\u2026' : text}\u201D` : kind; };"
    "let target = null;"
    "const move = e => { target = e.target; const r = target.getBoundingClientRect();"
    "  Object.assign(box.style, { left: r.left + 'px', top: r.top + 'px', width: r.width + 'px', height: r.height + 'px' }); };"
    "const block = e => { e.preventDefault(); e.stopImmediatePropagation(); };"
    "const presses = ['pointerdown', 'mousedown', 'pointerup', 'mouseup'];"
    "const finish = result => { removeEventListener('mousemove', move, true); removeEventListener('click', click, true);"
    "  removeEventListener('keydown', key, true); presses.forEach(k => removeEventListener(k, block, true)); box.remove(); hint.remove();"
    "  window.__dpZap = false; delete window.__dpZapStop; window.__dpZapResult = result; };"
    "const click = e => { block(e); finish(target ? JSON.stringify({ selector: name(target), label: label(target) }) : ''); };"
    "window.__dpZapStop = () => finish('');"
    "const key = e => { if (e.key === 'Escape') { block(e); finish(''); } };"
    "addEventListener('mousemove', move, true); addEventListener('click', click, true); addEventListener('keydown', key, true);"
    "presses.forEach(k => addEventListener(k, block, true));"
    "})()";

// A page that navigated away has neither a result nor the picker: that ends it as if Escape.
static NSString *const DPPollScript = @"(() => { const r = window.__dpZapResult;"
    "if (r === undefined) return window.__dpZap ? 'dp:pending' : ''; delete window.__dpZapResult; return r; })()";

static NSDictionary *DPZap(NSString *json) {
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *zap = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    return [zap isKindOfClass:NSDictionary.class] && [zap[@"selector"] length] ? zap : nil;
}

static void DPPoll(id contents, int left, void (^picked)(NSDictionary *)) {
    DPRunScript(contents, DPPollScript, ^(NSString *result) {
        if (![result isEqual:@"dp:pending"]) return picked(DPZap(result));
        if (left <= 0) return picked(nil);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 4), dispatch_get_main_queue(), ^{ DPPoll(contents, left - 1, picked); });
    });
}

void DPPickElement(id contents, void (^picked)(NSDictionary *zap)) {
    __weak id weak = contents;
    DPRunScript(contents, DPPickerScript, ^(NSString *_) { DPPoll(weak, 4 * 120, picked); });  // Gives up after two minutes.
}

void DPStopPicking(id contents) {
    DPRunScript(contents, @"window.__dpZapStop && window.__dpZapStop()", ^(NSString *_) {});
}
