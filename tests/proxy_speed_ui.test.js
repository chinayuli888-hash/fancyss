const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const pagePath = process.argv[2] || path.join(__dirname, '..', 'fancyss', 'webs', 'Module_shadowsocks.asp');
const page = fs.readFileSync(pagePath, 'utf8');
const start = page.indexOf('function proxy_speed_result_text(raw) {');
const end = page.indexOf('function get_ss_status_back() {', start);
assert.ok(start >= 0 && end > start, 'speed test functions must exist');
const source = page.slice(start, end);

function makeContext(websocketEnabled) {
  const elements = {
    ss_proxy_speed_btn: { textContent: '' },
    ss_proxy_speed_result: { textContent: '' },
  };
  const sockets = [];
  const requests = [];
  const context = {
    proxySpeedPending: false,
    E: (id) => elements[id],
    is_ws_available: () => websocketEnabled,
    hostname: '192.168.50.1',
    setTimeout: () => 1,
    clearTimeout: () => {},
    $: { ajax: (request) => requests.push(request) },
    WebSocket: function (url) {
      this.url = url;
      this.send = (message) => { this.sent = message; };
      this.close = () => { this.closed = true; };
      sockets.push(this);
    },
  };
  vm.createContext(context);
  vm.runInContext(source, context);
  return { context, elements, sockets, requests };
}

const half = 'download_mbps=0.37 bytes=524288 seconds=11.38\n';
const legacy = 'download_mbps=0.67 bytes=1048576 seconds=12.54\n';
const parser = makeContext(true).context.proxy_speed_result_text;
assert.equal(parser(half), '下载 0.37 Mbps（512 KiB / 11.38 秒）');
assert.equal(parser(legacy), '下载 0.67 Mbps（1024 KiB / 12.54 秒）');
assert.equal(parser('download_mbps=1 bytes=0 seconds=1\n'), '测速失败：未收到有效结果');
assert.equal(parser('error: download failed\n'), '测速失败： download failed');

for (const [payload, expected] of [[half, '下载 0.37 Mbps（512 KiB / 11.38 秒）'], [legacy, '下载 0.67 Mbps（1024 KiB / 12.54 秒）']]) {
  const { context, elements, sockets } = makeContext(true);
  context.run_proxy_speed_test();
  assert.match(elements.ss_proxy_speed_result.textContent, /512 KiB/);
  assert.equal(sockets.length, 1);
  sockets[0].onopen();
  assert.equal(sockets[0].sent, 'sh /koolshare/scripts/ss_proxy_speed.sh');
  sockets[0].onmessage({data: payload.slice(0, 21)});
  assert.equal(context.proxySpeedPending, true);
  sockets[0].onmessage({data: payload.slice(21)});
  assert.equal(elements.ss_proxy_speed_result.textContent, expected);
  assert.equal(elements.ss_proxy_speed_btn.textContent, '测试下载速度');
  assert.equal(context.proxySpeedPending, false);
  assert.equal(sockets[0].closed, true);
}

const http = makeContext(false);
http.context.run_proxy_speed_test();
assert.equal(http.requests.length, 1);
http.requests[0].success({result: half});
assert.equal(http.elements.ss_proxy_speed_result.textContent, '下载 0.37 Mbps（512 KiB / 11.38 秒）');
assert.equal(http.context.proxySpeedPending, false);
assert.ok(page.includes('title="手动下载 512 KiB'));
console.log('PASS: speed result parser, websocket chunks, HTTP fallback, and sample-size text');
