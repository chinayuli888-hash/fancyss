const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const pagePath = process.argv[2] || path.join(__dirname, '..', 'fancyss', 'webs', 'Module_shadowsocks.asp');
const page = fs.readFileSync(pagePath, 'utf8');
const start = page.indexOf('function set_proxy_traffic_text(text) {');
const end = page.indexOf('function proxy_speed_result_text(raw) {', start);
assert.ok(start >= 0 && end > start);
const code = page.slice(start, end);

function makeContext(wsEnabled) {
  const elements = Object.fromEntries(['ss_proxy_traffic_result', 'ss_youtube_traffic_result',
    'ss_youtube_check_btn', 'ss_youtube_check_result'].map((key) => [key, {textContent: ''}]));
  const scheduled = [];
  const requests = [];
  const sockets = [];
  const ctx = {
    proxyTrafficTimer: null, proxyTrafficRequest: null, proxyTrafficPrevious: null,
    proxyTrafficGeneration: 0, youtubeCheckPending: false,
    E: (key) => elements[key], is_page_live_updates_allowed: () => true,
    is_ws_available: () => wsEnabled, hostname: '192.168.50.1',
    setTimeout: (fn, ms) => { scheduled.push({fn, ms}); return scheduled.length; },
    clearTimeout: () => {},
    $: {ajax: (request) => {requests.push(request); return {abort: () => {}};}},
    WebSocket: function () {
      this.send = (command) => { this.sent = command; };
      this.close = () => { this.closed = true; };
      sockets.push(this);
    },
  };
  vm.createContext(ctx);
  vm.runInContext(code, ctx);
  return {ctx, elements, scheduled, requests, sockets};
}

const ui = makeContext(true);
ui.ctx.fetch_proxy_traffic();
ui.requests.shift().success({result: 'ok|21|42|10000|1000|2000|1|500'});
assert.equal(ui.elements.ss_youtube_traffic_result.textContent, '正在采样...');
ui.ctx.fetch_proxy_traffic();
ui.requests.shift().success({result: 'ok|21|42|13000|301000|1502000|1|750500'});
assert.equal(ui.elements.ss_proxy_traffic_result.textContent, '上传 0.80 Mbps / 下载 4.00 Mbps');
assert.equal(ui.elements.ss_youtube_traffic_result.textContent, '下载 2.00 Mbps');
ui.ctx.fetch_proxy_traffic();
ui.requests.shift().success({result: 'ok|21|42|16000|301000|1502000|1|750500'});
assert.equal(ui.elements.ss_youtube_traffic_result.textContent, '暂未识别到视频下载');
ui.ctx.fetch_proxy_traffic();
ui.requests.shift().success({result: 'ok|22|43|19000|1|2|1|1'});
assert.equal(ui.elements.ss_youtube_traffic_result.textContent, '正在采样...');
ui.ctx.fetch_proxy_traffic();
ui.requests.shift().success({result: 'ok|22|43|22000|1|2'});
assert.equal(ui.elements.ss_youtube_traffic_result.textContent, '当前模式暂不支持视频单独统计');
ui.ctx.fetch_proxy_traffic();
ui.requests.shift().success({result: 'unavailable|disabled'});
assert.equal(ui.elements.ss_youtube_traffic_result.textContent, '代理已关闭');

assert.equal(ui.ctx.youtube_check_result_text('youtube_status=ok seconds=0.42\n'), 'YouTube 可访问（0.42 秒）');
assert.equal(ui.ctx.youtube_check_result_text('error: some detail\n'), 'YouTube 连接失败，请检查当前节点');
assert.equal(ui.ctx.youtube_check_result_text('junk'), 'YouTube 检测未收到有效结果');
ui.ctx.run_youtube_check();
assert.equal(ui.sockets.length, 1);
ui.sockets[0].onopen();
assert.equal(ui.sockets[0].sent, 'sh /koolshare/scripts/ss_youtube_check.sh');
ui.sockets[0].onmessage({data: 'youtube_status=ok sec'});
assert.equal(ui.ctx.youtubeCheckPending, true);
ui.sockets[0].onmessage({data: 'onds=0.42\n'});
assert.equal(ui.elements.ss_youtube_check_result.textContent, 'YouTube 可访问（0.42 秒）');
assert.equal(ui.ctx.youtubeCheckPending, false);
assert.equal(ui.sockets[0].closed, true);

const http = makeContext(false);
http.ctx.run_youtube_check();
assert.equal(http.requests.length, 1);
assert.match(http.requests[0].data, /ss_youtube_check_http\.sh/);
http.requests[0].success({result: 'youtube_status=ok seconds=1.20'});
assert.equal(http.elements.ss_youtube_check_result.textContent, 'YouTube 可访问（1.20 秒）');
assert.match(page, /YouTube 视频实时流量/);
assert.match(page, /Hetzner 样本下载/);
console.log('PASS: YouTube and aggregate counters, resets, legacy payload, WebSocket and HTTP check');
