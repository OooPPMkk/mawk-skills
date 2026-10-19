// CDP page probe: per-viewport geometry evaluation (viewport override) or real-window screenshot or graceful close.
// Usage:
//   node cdp-page-probe.mjs geom <urlSubstr> <exprFile> [WxH ...]
//   node cdp-page-probe.mjs shot <urlSubstr> <W> <H> <outPng>
//   node cdp-page-probe.mjs close
// Notes: ASCII only (PowerShell 5.1 piping safety). Node 22+ (built-in WebSocket, no npm deps).
//        exprFile content is evaluated as a JS expression per viewport and must return a JSON-serializable value.

import { readFile, writeFile } from 'node:fs/promises'

const CDP = 'http://127.0.0.1:9222'
const USAGE =
  'Usage: node cdp-page-probe.mjs geom <urlSubstr> <exprFile> [WxH ...] | shot <urlSubstr> <W> <H> <outPng> | close'
const mode = process.argv[2]
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

async function connectPage(urlSubstr) {
  const list = await (await fetch(CDP + '/json/list')).json()
  const page = list.find((t) => t.type === 'page' && t.url.includes(urlSubstr))
  if (!page) throw new Error('NO_PAGE: ' + list.map((t) => t.url).join(' | '))
  const ws = new WebSocket(page.webSocketDebuggerUrl)
  await new Promise((res, rej) => {
    ws.onopen = res
    ws.onerror = rej
  })
  let n = 0
  const pending = new Map()
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data)
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg)
      pending.delete(msg.id)
    }
  }
  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = ++n
      pending.set(id, (m) =>
        m.error ? reject(new Error(method + ': ' + JSON.stringify(m.error))) : resolve(m.result),
      )
      ws.send(JSON.stringify({ id, method, params }))
    })
  return { page, ws, send }
}

try {
  if (mode === 'close') {
    const ver = await (await fetch(CDP + '/json/version')).json()
    const ws = new WebSocket(ver.webSocketDebuggerUrl)
    await new Promise((res, rej) => {
      ws.onopen = res
      ws.onerror = rej
    })
    ws.send(JSON.stringify({ id: 1, method: 'Browser.close' }))
    await sleep(500)
    ws.close()
    console.log('CLOSED')
  } else if (mode === 'geom') {
    const urlSubstr = process.argv[3]
    const exprFile = process.argv[4]
    const vps = process.argv.slice(5)
    if (!urlSubstr || !exprFile || vps.length === 0) {
      console.error(USAGE)
      process.exit(2)
    }
    const expr = await readFile(exprFile, 'utf8')
    const { ws, send } = await connectPage(urlSubstr)
    await send('Runtime.enable')
    const results = []
    for (const vp of vps) {
      const [w, h] = vp.split('x').map(Number)
      await send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: false })
      await sleep(400)
      const ev = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })
      results.push({ vp, ...ev.result.value })
      await send('Emulation.clearDeviceMetricsOverride')
    }
    ws.close()
    console.log(JSON.stringify(results))
  } else if (mode === 'shot') {
    const urlSubstr = process.argv[3]
    const W = Number(process.argv[4])
    const H = Number(process.argv[5])
    const outPng = process.argv[6]
    if (!urlSubstr || !W || !H || !outPng) {
      console.error(USAGE)
      process.exit(2)
    }
    const { page, ws, send } = await connectPage(urlSubstr)
    await send('Page.enable')
    const { windowId } = await send('Browser.getWindowForTarget', { targetId: page.id })
    await send('Browser.setWindowBounds', { windowId, bounds: { windowState: 'normal' } })
    await send('Browser.setWindowBounds', { windowId, bounds: { left: 0, top: 0, width: W, height: H } })
    await sleep(1200)
    const ev = await send('Runtime.evaluate', { expression: 'innerWidth + "x" + innerHeight', returnByValue: true })
    const shot = await send('Page.captureScreenshot', { format: 'png' })
    await writeFile(outPng, Buffer.from(shot.data, 'base64'))
    console.log('VIEWPORT=' + ev.result.value)
    console.log('SAVED=' + outPng)
    ws.close()
  } else {
    console.error(USAGE)
    process.exit(2)
  }
} catch (err) {
  console.error('ERROR: ' + err.message)
  process.exit(1)
}
