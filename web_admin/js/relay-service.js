/**
 * Đồng bộ trạng thái relay qua Firebase Realtime Database + MQTT.
 */
class RelayManager {
  constructor({ onStateChange, onLog, publishMqtt }) {
    this.onStateChange = onStateChange;
    this.onLog = onLog;
    this.publishMqtt = publishMqtt;
    this.ref = null;
    this.isSyncing = false;
    this.currentState = RELAY_CONFIG.defaultState;
    this.updatedBy = 'init';
  }

  init() {
    if (typeof firebase === 'undefined') {
      this.onLog?.('Firebase SDK chưa tải', 'err');
      return;
    }

    if (!firebase.apps.length) {
      firebase.initializeApp(FIREBASE_CONFIG);
    }

    const db = firebase.database();
    this.ref = db.ref(RELAY_CONFIG.firebasePath);

    this.ref.on('value', (snapshot) => {
      const val = snapshot.val();
      if (!val) return;

      const isOn = val.state === true || val.state === 1;
      this.currentState = isOn;
      this.updatedBy = val.updatedBy || 'firebase';
      this.onStateChange?.({
        isOn,
        updatedBy: this.updatedBy,
        syncing: this.isSyncing,
      });
    });

    this.ensureInitialized();
  }

  async ensureInitialized() {
    const snapshot = await this.ref.once('value');
    if (!snapshot.exists()) {
      const payload = {
        state: RELAY_CONFIG.defaultState,
        defaultState: RELAY_CONFIG.defaultState,
        updatedAt: Date.now(),
        updatedBy: 'init',
      };
      await this.ref.set(payload);
      this.onLog?.('Đã khởi tạo trạng thái relay mặc định trên Firebase');
    }
  }

  async setState(isOn) {
    if (this.isSyncing) return;
    this.isSyncing = true;
    this.onStateChange?.({
      isOn: this.currentState,
      updatedBy: this.updatedBy,
      syncing: true,
    });

    try {
      const payload = {
        state: isOn,
        updatedAt: Date.now(),
        updatedBy: 'web',
      };
      await this.ref.update(payload);

      const mqttPayload = JSON.stringify({ state: isOn ? 1 : 0 });
      if (this.publishMqtt) {
        this.publishMqtt(RELAY_CONFIG.mqttTopic, mqttPayload);
        this.onLog?.(`Relay → MQTT [${RELAY_CONFIG.mqttTopic}]: ${mqttPayload}`, 'pub');
      }

      this.currentState = isOn;
      this.updatedBy = 'web';
      this.onLog?.(`Relay Firebase: ${isOn ? 'BẬT' : 'TẮT'}`, 'pub');
    } catch (e) {
      this.onLog?.(`Relay lỗi: ${e.message}`, 'err');
    } finally {
      this.isSyncing = false;
      this.onStateChange?.({
        isOn: this.currentState,
        updatedBy: this.updatedBy,
        syncing: false,
      });
    }
  }

  destroy() {
    this.ref?.off();
  }
}

window.RelayManager = RelayManager;
