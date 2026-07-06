/** Cấu hình Firebase — đồng bộ với lib/firebase_options.dart */
const FIREBASE_CONFIG = {
  apiKey: 'AIzaSyDJ0RsptB7F6tP693-ItfrM7dUD5JIXE0Q',
  authDomain: 'datn-cuan.firebaseapp.com',
  databaseURL: 'https://datn-cuan-default-rtdb.firebaseio.com',
  projectId: 'datn-cuan',
  storageBucket: 'datn-cuan.firebasestorage.app',
  messagingSenderId: '790076437485',
  appId: '1:790076437485:web:8b226e79cc299a1b44ede4',
};

const RELAY_CONFIG = {
  firebasePath: 'ev_charging/relay',
  mqttTopic: 'relay',
  defaultState: false,
};

window.FIREBASE_CONFIG = FIREBASE_CONFIG;
window.RELAY_CONFIG = RELAY_CONFIG;
