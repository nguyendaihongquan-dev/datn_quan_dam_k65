const CONFIG = {
  host: 'a8e2eca8b3a54e48a698499b8d22c91d.s1.eu.hivemq.cloud',
  port: 8884,
  username: 'LongNe',
  password: 'Abc@1234',
  defaultSubscribeTopic: 'electric',
  defaultPublishTopic: 'electric',
  defaultRelayTopic: 'relay',
  fakeIntervalMs: 2000,
  storageKey: 'ev_mqtt_topics',
  tabKey: 'ev_admin_tab',
  fakeKey: 'ev_admin_fake',
  dataStaleMs: 15000,
  maxInbox: 50,
  maxChartPoints: 40,
};

const $ = (id) => document.getElementById(id);

let client = null;
let fakeTimer = null;
let fakeGenerator = new FakeElectricGenerator();
const subscribedTopics = new Set();
const powerHistory = [];

let statsReceived = 0;
let statsSent = 0;
let fakeSentCount = 0;
let relayManager = null;
let chargingAnimation = null;
let lastElectricData = null;
let staleDataTimer = null;
let fakeEnabledPref = false;

const connDot = $('connDot');
const connLabel = $('connLabel');
const connBadge = $('connBadge');
const btnConnect = $('btnConnect');
const btnDisconnect = $('btnDisconnect');
const btnSubscribe = $('btnSubscribe');
const btnUnsubscribe = $('btnUnsubscribe');
const fakeToggle = $('fakeToggle');
const fakeStatus = $('fakeStatus');
const fakeStatusText = $('fakeStatusText');
const fakeBadge = $('fakeBadge');
const btnPublish = $('btnPublish');
const btnRawPublish = $('btnRawPublish');
const logEl = $('log');
const inboxEl = $('inbox');
const subscribedListEl = $('subscribedList');
const chartCanvas = $('powerChart');
const chartCtx = chartCanvas?.getContext('2d');

$('brokerHost').textContent = CONFIG.host;
$('brokerWs').textContent = `wss://${CONFIG.host}:${CONFIG.port}/mqtt`;

initTabs();
loadTopicConfig();
loadFakePreference();
bindTopicPersistence();
setConnected(false);
renderSubscribedTopics();
updateFakeTopicPreview();
drawChart();
initRelay();
chargingAnimation = new ChargingFlowAnimation('flowCanvas');
chargingAnimation.setState('idle');
updateFakeVisual(false);
log('Sẵn sàng. Kết nối MQTT để bắt đầu giám sát realtime.');

/* ── Tabs ── */
function initTabs() {
  const saved = localStorage.getItem(CONFIG.tabKey) || 'manage';
  switchTab(saved);

  document.querySelectorAll('.tabs__btn').forEach((btn) => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });
}

function switchTab(tabId) {
  document.querySelectorAll('.tabs__btn').forEach((btn) => {
    const active = btn.dataset.tab === tabId;
    btn.classList.toggle('tabs__btn--active', active);
    btn.setAttribute('aria-selected', active);
  });

  const indicator = $('tabIndicator');
  if (indicator) {
    indicator.classList.toggle('tabs__indicator--test', tabId === 'test');
  }

  document.querySelectorAll('.tab-panel').forEach((panel) => {
    const active = panel.id === `tab-${tabId}`;
    panel.classList.toggle('tab-panel--active', active);
    panel.hidden = !active;
    if (active) {
      panel.querySelectorAll('.animate-in').forEach((el, i) => {
        el.style.animation = 'none';
        void el.offsetWidth;
        el.style.animation = '';
        el.style.animationDelay = `${0.05 + i * 0.06}s`;
      });
    }
  });

  localStorage.setItem(CONFIG.tabKey, tabId);

  if (tabId === 'manage') {
    requestAnimationFrame(() => {
      chargingAnimation?.resize();
      if (lastElectricData) {
        setStationUI(lastElectricData);
      }
    });
  }
}

/* ── Topic config ── */
function loadTopicConfig() {
  try {
    const saved = JSON.parse(localStorage.getItem(CONFIG.storageKey) || '{}');
    $('subscribeTopic').value =
      saved.subscribeTopic || CONFIG.defaultSubscribeTopic;
    $('publishTopic').value = saved.publishTopic || CONFIG.defaultPublishTopic;
  } catch {
    $('subscribeTopic').value = CONFIG.defaultSubscribeTopic;
    $('publishTopic').value = CONFIG.defaultPublishTopic;
  }
}

function saveTopicConfig() {
  localStorage.setItem(
    CONFIG.storageKey,
    JSON.stringify({
      subscribeTopic: $('subscribeTopic').value.trim(),
      publishTopic: $('publishTopic').value.trim(),
    }),
  );
  updateFakeTopicPreview();
}

function loadFakePreference() {
  try {
    const saved = JSON.parse(localStorage.getItem(CONFIG.fakeKey) || '{}');
    fakeEnabledPref = Boolean(saved.enabled);
  } catch {
    fakeEnabledPref = false;
  }
  fakeToggle.checked = fakeEnabledPref;
}

function updateFakeVisual(running) {
  fakeStatus.className = `fake-status fake-status--${running ? 'on' : 'off'}`;
  fakeStatusText.textContent = running
    ? `Đang chạy → ${getPublishTopic()}`
    : 'Đang tắt';
  fakeBadge.classList.toggle('tabs__badge--hidden', !running);
  document.querySelector('.fake-card')?.classList.toggle('fake-card--live', running);
}

function saveFakePreference(enabled) {
  fakeEnabledPref = Boolean(enabled);
  localStorage.setItem(
    CONFIG.fakeKey,
    JSON.stringify({ enabled: fakeEnabledPref }),
  );
}

function isElectricCharging(data) {
  return (data.current > 0.1) || (data.power > 0.05);
}

function clearStaleTimer() {
  if (staleDataTimer) {
    clearTimeout(staleDataTimer);
    staleDataTimer = null;
  }
}

function scheduleStaleCheck() {
  clearStaleTimer();
  staleDataTimer = setTimeout(() => {
    if (fakeTimer) return;
    resetStationToIdle('Không nhận dữ liệu trong 15s');
  }, CONFIG.dataStaleMs);
}

function resetStationToIdle(message = 'Chờ dữ liệu') {
  clearStaleTimer();
  lastElectricData = null;
  powerHistory.length = 0;
  drawChart();

  $('mVoltage').textContent = '—';
  $('mCurrent').textContent = '—';
  $('mPower').textContent = '—';
  $('mEnergy').textContent = '—';
  $('mTime').textContent = '—';
  $('lastUpdate').textContent = '—';

  $('stationStatus').textContent = message;
  $('stationStatus').className = 'live-hero__status live-hero__status--idle';

  const chip = $('mStatus');
  chip.textContent = '○ Chờ kết nối';
  chip.className = 'status-chip status-chip--idle';

  chargingAnimation?.setState('idle', false);

  const batteryStd = document.querySelector('.battery-icon--std');
  const batteryCharging = document.querySelector('.battery-icon--charging');
  if (batteryStd && batteryCharging) {
    batteryStd.hidden = false;
    batteryCharging.hidden = true;
  }
}

function bindTopicPersistence() {
  ['subscribeTopic', 'publishTopic'].forEach((id) => {
    $(id).addEventListener('change', saveTopicConfig);
    $(id).addEventListener('input', saveTopicConfig);
  });
}

function getPublishTopic() {
  return $('publishTopic').value.trim() || CONFIG.defaultPublishTopic;
}

function getSubscribeTopicInput() {
  return $('subscribeTopic').value.trim() || CONFIG.defaultSubscribeTopic;
}

function updateFakeTopicPreview() {
  $('fakeTopicPreview').textContent = getPublishTopic();
}

/* ── Stats & UI helpers ── */
function bumpStat(el) {
  el.classList.remove('bump');
  void el.offsetWidth;
  el.classList.add('bump');
}

function incrementReceived() {
  statsReceived++;
  $('statReceived').textContent = statsReceived;
  bumpStat($('statReceived'));
}

function incrementSent() {
  statsSent++;
  $('statSent').textContent = statsSent;
  bumpStat($('statSent'));
}

function flashMetric(name) {
  const el = document.querySelector(`[data-metric="${name}"]`);
  if (!el) return;
  el.classList.add('metric--flash');
  setTimeout(() => el.classList.remove('metric--flash'), 500);
}

function flashInboxPulse() {
  const pulse = $('inboxPulse');
  pulse.classList.remove('pulse-dot--hidden');
  setTimeout(() => pulse.classList.add('pulse-dot--hidden'), 1200);
}

function setLastUpdate() {
  const now = new Date();
  $('lastUpdate').textContent = now.toLocaleTimeString('vi-VN', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

function setStationUI(data) {
  const charging = isElectricCharging(data);
  let statusText = 'Chờ kết nối';
  let chipClass = 'status-chip--idle';
  let heroStatus = 'Trạm sẵn sàng';
  let visualState = 'idle';

  if (data.alarm) {
    statusText = '⚠ Cảnh báo';
    chipClass = 'status-chip--alarm';
    heroStatus = 'Cảnh báo hệ thống';
    visualState = 'alarm';
  } else if (charging) {
    statusText = '⚡ Đang sạc';
    chipClass = 'status-chip--charging';
    heroStatus = 'Đang sạc';
    visualState = 'charging';
  } else {
    statusText = '○ Chờ kết nối';
    heroStatus = 'Chờ kết nối';
    visualState = 'idle';
  }

  const chip = $('mStatus');
  chip.textContent = statusText;
  chip.className = `status-chip ${chipClass}`;

  const statusEl = $('stationStatus');
  statusEl.textContent = heroStatus;
  statusEl.className = `live-hero__status live-hero__status--${visualState}`;

  chargingAnimation?.setState(visualState, charging);

  const batteryStd = document.querySelector('.battery-icon--std');
  const batteryCharging = document.querySelector('.battery-icon--charging');
  if (batteryStd && batteryCharging) {
    batteryStd.hidden = charging;
    batteryCharging.hidden = !charging;
  }
}

function log(message, type = '') {
  const time = new Date().toLocaleTimeString('vi-VN');
  const entry = document.createElement('div');
  entry.className = `log__entry${type ? ` log__entry--${type}` : ''}`;
  entry.innerHTML = `<span class="log__time">${time}</span>${message}`;
  logEl.prepend(entry);
  if (logEl.children.length > 100) logEl.removeChild(logEl.lastChild);
}

function setConnected(connected) {
  connDot.className = `status-dot status-dot--${connected ? 'online' : 'offline'}`;
  connLabel.textContent = connected ? 'Online' : 'Offline';
  connBadge.classList.toggle('header__status--online', connected);
  btnConnect.disabled = connected;
  btnDisconnect.disabled = !connected;
  btnSubscribe.disabled = !connected;
  btnUnsubscribe.disabled = !connected;
  fakeToggle.disabled = !connected;
  btnPublish.disabled = !connected;
  btnRawPublish.disabled = !connected;
  $('btnRelayOn').disabled = !connected;
  $('btnRelayOff').disabled = !connected;
}

/* ── Chart ── */
function drawChart() {
  if (!chartCtx) return;

  const w = chartCanvas.width;
  const h = chartCanvas.height;
  chartCtx.clearRect(0, 0, w, h);

  if (powerHistory.length < 2) {
    chartCtx.fillStyle = '#7d8da8';
    chartCtx.font = '12px Inter, sans-serif';
    chartCtx.textAlign = 'center';
    chartCtx.fillText('Biểu đồ công suất (kW)', w / 2, h / 2);
    return;
  }

  const max = Math.max(...powerHistory, 0.1);
  const pad = { t: 8, b: 8, l: 4, r: 4 };
  const cw = w - pad.l - pad.r;
  const ch = h - pad.t - pad.b;

  chartCtx.strokeStyle = 'rgba(125, 141, 168, 0.15)';
  chartCtx.lineWidth = 1;
  for (let i = 0; i <= 3; i++) {
    const y = pad.t + (ch / 3) * i;
    chartCtx.beginPath();
    chartCtx.moveTo(pad.l, y);
    chartCtx.lineTo(w - pad.r, y);
    chartCtx.stroke();
  }

  const grad = chartCtx.createLinearGradient(0, pad.t, 0, h - pad.b);
  grad.addColorStop(0, 'rgba(0, 230, 118, 0.35)');
  grad.addColorStop(1, 'rgba(0, 230, 118, 0)');

  chartCtx.beginPath();
  powerHistory.forEach((val, i) => {
    const x = pad.l + (i / (CONFIG.maxChartPoints - 1)) * cw;
    const y = pad.t + ch - (val / max) * ch;
    if (i === 0) chartCtx.moveTo(x, y);
    else chartCtx.lineTo(x, y);
  });

  const lastX = pad.l + ((powerHistory.length - 1) / (CONFIG.maxChartPoints - 1)) * cw;
  chartCtx.lineTo(lastX, h - pad.b);
  chartCtx.lineTo(pad.l, h - pad.b);
  chartCtx.closePath();
  chartCtx.fillStyle = grad;
  chartCtx.fill();

  chartCtx.beginPath();
  powerHistory.forEach((val, i) => {
    const x = pad.l + (i / (CONFIG.maxChartPoints - 1)) * cw;
    const y = pad.t + ch - (val / max) * ch;
    if (i === 0) chartCtx.moveTo(x, y);
    else chartCtx.lineTo(x, y);
  });
  chartCtx.strokeStyle = '#00e676';
  chartCtx.lineWidth = 2;
  chartCtx.stroke();

  const lx = pad.l + ((powerHistory.length - 1) / (CONFIG.maxChartPoints - 1)) * cw;
  const ly = pad.t + ch - (powerHistory[powerHistory.length - 1] / max) * ch;
  chartCtx.beginPath();
  chartCtx.arc(lx, ly, 4, 0, Math.PI * 2);
  chartCtx.fillStyle = '#00e676';
  chartCtx.fill();
  chartCtx.shadowColor = '#00e676';
  chartCtx.shadowBlur = 8;
  chartCtx.fill();
  chartCtx.shadowBlur = 0;
}

function pushPower(power) {
  powerHistory.push(power);
  if (powerHistory.length > CONFIG.maxChartPoints) powerHistory.shift();
  drawChart();
}

/* ── Metrics ── */
function updateMetrics(data) {
  lastElectricData = data;
  clearStaleTimer();
  scheduleStaleCheck();

  const fields = [
    ['mVoltage', data.voltage, 1, 'voltage'],
    ['mCurrent', data.current, 2, 'current'],
    ['mPower', data.power, 2, 'power'],
    ['mEnergy', data.energy, 3, 'energy'],
  ];

  fields.forEach(([id, val, dec, metric]) => {
    const el = $(id);
    const formatted = val?.toFixed?.(dec) ?? val ?? '—';
    if (el.textContent !== String(formatted)) {
      el.textContent = formatted;
      flashMetric(metric);
    }
  });

  if (typeof data.power === 'number') pushPower(data.power);

  setStationUI(data);

  const h = String(data.hour ?? 0).padStart(2, '0');
  const m = String(data.minute ?? 0).padStart(2, '0');
  $('mTime').textContent = `${h}:${m}`;
  setLastUpdate();
}

/* ── MQTT subscribe ── */
function renderSubscribedTopics() {
  subscribedListEl.innerHTML = '';
  if (subscribedTopics.size === 0) {
    subscribedListEl.innerHTML = '<span class="chip chip--muted">Chưa subscribe</span>';
    return;
  }
  subscribedTopics.forEach((topic) => {
    const chip = document.createElement('span');
    chip.className = 'chip';
    chip.textContent = topic;
    chip.title = 'Click để chọn topic';
    chip.addEventListener('click', () => {
      $('subscribeTopic').value = topic;
      saveTopicConfig();
    });
    subscribedListEl.appendChild(chip);
  });
}

function subscribeTopic(topic) {
  if (!client?.connected) {
    log('Chưa kết nối MQTT', 'err');
    return;
  }
  const t = (topic || getSubscribeTopicInput()).trim();
  if (!t) {
    log('Topic subscribe không hợp lệ', 'err');
    return;
  }
  client.subscribe(t, { qos: 1 }, (err) => {
    if (err) {
      log(`Subscribe lỗi [${t}]: ${err.message}`, 'err');
      return;
    }
    subscribedTopics.add(t);
    renderSubscribedTopics();
    log(`Subscribe ← "${t}"`);
  });
}

function unsubscribeTopic(topic) {
  if (!client?.connected) {
    log('Chưa kết nối MQTT', 'err');
    return;
  }
  const t = (topic || getSubscribeTopicInput()).trim();
  if (!t) {
    log('Topic unsubscribe không hợp lệ', 'err');
    return;
  }
  client.unsubscribe(t, (err) => {
    if (err) {
      log(`Unsubscribe lỗi [${t}]: ${err.message}`, 'err');
      return;
    }
    subscribedTopics.delete(t);
    renderSubscribedTopics();
    log(`Unsubscribe ✕ "${t}"`);
  });
}

function tryParseElectric(payloadStr) {
  try {
    const data = JSON.parse(payloadStr);
    if (typeof data.voltage === 'number' || typeof data.current === 'number') {
      return data;
    }
  } catch { /* skip */ }
  return null;
}

function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function addInboxMessage(topic, payloadStr) {
  const empty = inboxEl.querySelector('.inbox__empty');
  if (empty) empty.remove();

  const item = document.createElement('div');
  item.className = 'inbox__item inbox__item--new';
  const time = new Date().toLocaleTimeString('vi-VN');
  const preview =
    payloadStr.length > 220 ? `${payloadStr.slice(0, 220)}…` : payloadStr;

  item.innerHTML = `
    <div class="inbox__meta">
      <span class="inbox__topic">${escapeHtml(topic)}</span>
      <span class="inbox__time">${time}</span>
    </div>
    <pre class="inbox__body">${escapeHtml(preview)}</pre>
  `;
  inboxEl.prepend(item);
  setTimeout(() => item.classList.remove('inbox__item--new'), 800);

  while (inboxEl.children.length > CONFIG.maxInbox) {
    inboxEl.removeChild(inboxEl.lastChild);
  }

  flashInboxPulse();
}

/* ── Publish ── */
function publishToTopic(topic, payload) {
  if (!client?.connected) {
    log('Chưa kết nối MQTT', 'err');
    return false;
  }
  const t = topic.trim();
  if (!t) {
    log('Topic publish không hợp lệ', 'err');
    return false;
  }
  const body = typeof payload === 'string' ? payload : JSON.stringify(payload);
  client.publish(t, body, { qos: 1 });
  incrementSent();
  return true;
}

function publishPayload(payload) {
  const topic = getPublishTopic();
  if (publishToTopic(topic, payload)) {
    log(`Gửi → [${topic}]`, 'pub');
    return true;
  }
  return false;
}

/* ── Fake data ── */
function setFakeRunning(running) {
  fakeToggle.checked = running;
  updateFakeVisual(running);
}

function skipFakeToChargingPhase() {
  let data = fakeGenerator.next();
  let guard = 0;
  while (!isElectricCharging(data) && guard < fakeGenerator.cycleLength) {
    data = fakeGenerator.next();
    guard++;
  }
  return data;
}

function publishFakeSample() {
  const data = fakeGenerator.next();
  if (publishPayload(data)) {
    fakeSentCount++;
    $('fakeSentCount').textContent = fakeSentCount;
    updateMetrics(data);
  }
}

function startFake({ persist = true } = {}) {
  if (fakeTimer) return;
  fakeGenerator.reset();
  fakeSentCount = 0;
  $('fakeSentCount').textContent = '0';

  const firstSample = skipFakeToChargingPhase();
  if (publishPayload(firstSample)) {
    fakeSentCount++;
    $('fakeSentCount').textContent = fakeSentCount;
    updateMetrics(firstSample);
  }

  fakeTimer = setInterval(publishFakeSample, CONFIG.fakeIntervalMs);
  setFakeRunning(true);
  if (persist) saveFakePreference(true);
  log(`Bật Fake Data → "${getPublishTopic()}"`, 'pub');
}

function stopFake({ persist = true, resetUi = true } = {}) {
  if (fakeTimer) {
    clearInterval(fakeTimer);
    fakeTimer = null;
  }
  fakeGenerator.reset();
  setFakeRunning(false);
  if (persist) saveFakePreference(false);
  if (resetUi) resetStationToIdle('Chờ dữ liệu');
  log('Tắt Fake Data');
}

/* ── Connection ── */
function handleIncomingMessage(topic, payload) {
  const text = payload.toString();
  incrementReceived();
  addInboxMessage(topic, text);
  log(`Nhận ← [${topic}]`);

  const electric = tryParseElectric(text);
  if (electric) updateMetrics(electric);
}

function connectMqtt() {
  if (client?.connected) return;

  saveTopicConfig();
  const url = `wss://${CONFIG.host}:${CONFIG.port}/mqtt`;
  const clientId = `ev_admin_${Math.random().toString(16).slice(2, 10)}`;

  log(`Kết nối ${url}...`);

  client = mqtt.connect(url, {
    clientId,
    username: CONFIG.username,
    password: CONFIG.password,
    clean: true,
    reconnectPeriod: 5000,
    connectTimeout: 10000,
  });

  client.on('connect', () => {
    setConnected(true);
    log('Kết nối thành công', 'pub');
    subscribeTopic(getSubscribeTopicInput());
    subscribeTopic(CONFIG.defaultRelayTopic);
    scheduleStaleCheck();

    if (fakeEnabledPref) {
      startFake({ persist: false });
    }
  });

  client.on('message', handleIncomingMessage);

  client.on('error', (err) => {
    log(`Lỗi: ${err.message}`, 'err');
  });

  client.on('close', () => {
    setConnected(false);
    subscribedTopics.clear();
    renderSubscribedTopics();
    stopFake({ persist: false, resetUi: false });
    fakeToggle.checked = fakeEnabledPref;
    setFakeRunning(false);
    log('Đã ngắt kết nối');
  });

  client.on('reconnect', () => {
    log('Đang kết nối lại...');
  });
}

function disconnectMqtt() {
  stopFake({ persist: false, resetUi: true });
  fakeToggle.checked = fakeEnabledPref;
  clearStaleTimer();
  if (client) {
    client.end(true);
    client = null;
  }
  subscribedTopics.clear();
  renderSubscribedTopics();
  setConnected(false);
}

/* ── Events ── */
btnConnect.addEventListener('click', connectMqtt);
btnDisconnect.addEventListener('click', disconnectMqtt);
btnSubscribe.addEventListener('click', () => subscribeTopic());
btnUnsubscribe.addEventListener('click', () => unsubscribeTopic());

fakeToggle.addEventListener('change', () => {
  if (fakeToggle.checked) startFake({ persist: true });
  else stopFake({ persist: true, resetUi: true });
});

$('manualForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const voltage = parseFloat($('inVoltage').value) || 0;
  const current = parseFloat($('inCurrent').value) || 0;
  const energy = parseFloat($('inEnergy').value) || 0;
  const alarm = parseInt($('inAlarm').value, 10) || 0;
  const now = new Date();
  const power = (voltage * current) / 1000;

  const payload = {
    voltage: parseFloat(voltage.toFixed(1)),
    current: parseFloat(current.toFixed(2)),
    power: parseFloat(power.toFixed(2)),
    energy: parseFloat(energy.toFixed(3)),
    alarm,
    hour: now.getHours(),
    minute: now.getMinutes(),
  };

  if (publishPayload(payload)) updateMetrics(payload);
});

$('rawForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const topic = $('rawTopic').value.trim() || getPublishTopic();
  const raw = $('rawPayload').value.trim();

  try {
    JSON.parse(raw);
  } catch {
    log('JSON không hợp lệ', 'err');
    return;
  }

  if (publishToTopic(topic, raw)) {
    log(`Gửi JSON → [${topic}]`, 'pub');
    const electric = tryParseElectric(raw);
    if (electric) updateMetrics(electric);
  }
});

$('btnClearLog').addEventListener('click', () => {
  logEl.innerHTML = '';
});

$('btnClearInbox').addEventListener('click', () => {
  inboxEl.innerHTML = `
    <div class="inbox__empty">
      <div class="inbox__empty-icon">📡</div>
      <p>Chưa có bản tin. Kết nối MQTT và subscribe topic.</p>
    </div>`;
});

/* ── Relay (Firebase + MQTT) ── */
function initRelay() {
  relayManager = new RelayManager({
    onStateChange: updateRelayUI,
    onLog: log,
    publishMqtt: (topic, payload) => {
      if (!client?.connected) return false;
      client.publish(topic, payload, { qos: 1 });
      incrementSent();
      return true;
    },
  });
  relayManager.init();

  $('btnRelayOn').addEventListener('click', () => relayManager?.setState(true));
  $('btnRelayOff').addEventListener('click', () => relayManager?.setState(false));
}

function updateRelayUI({ isOn, updatedBy, syncing }) {
  const dot = $('relayStatusDot');
  const label = $('relayStatusLabel');
  const by = $('relayUpdatedBy');
  const hint = $('relaySyncHint');
  const panel = $('relayPanel');
  const iconWrap = $('relayIconWrap');

  dot.className = `relay-dot relay-dot--${isOn ? 'on' : 'off'}`;
  label.textContent = syncing ? 'Đang đồng bộ...' : (isOn ? 'Đang BẬT' : 'Đang TẮT');
  by.textContent = updatedBy || '—';
  hint.textContent = syncing
    ? 'Đang gửi lệnh MQTT và cập nhật Firebase...'
    : 'Đồng bộ realtime với app Flutter qua Firebase RTDB';

  panel?.classList.toggle('relay-panel--on', isOn);
  panel?.classList.toggle('relay-panel--syncing', syncing);
  iconWrap?.classList.toggle('relay-icon-wrap--on', isOn);

  $('btnRelayOn').classList.toggle('relay-toggle-btn--active', isOn && !syncing);
  $('btnRelayOff').classList.toggle('relay-toggle-btn--active', !isOn && !syncing);
}
