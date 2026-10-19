// Example expression for `geom` mode of cdp-page-probe.mjs: reads rects + display for a list of selectors.
// Adjust the selectors array before use. Must evaluate to a JSON-serializable value.
(() => {
  const selectors = ['.login-layout', '.brand-pane', '.form-pane']
  const rect = (sel) => {
    const el = document.querySelector(sel)
    if (!el) return 'absent'
    const b = el.getBoundingClientRect()
    return {
      l: Math.round(b.left),
      r: Math.round(b.right),
      w: Math.round(b.width),
      t: Math.round(b.top),
      h: Math.round(b.height),
      display: getComputedStyle(el).display,
    }
  }
  const out = {
    vw: innerWidth,
    vh: innerHeight,
    scrollH: document.documentElement.scrollHeight,
    vScroll: document.documentElement.scrollHeight > innerHeight,
  }
  for (const sel of selectors) out[sel] = rect(sel)
  return out
})()
