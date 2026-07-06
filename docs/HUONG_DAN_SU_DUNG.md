# Hướng dẫn sử dụng — EV Charging Station

Dự án gồm **ứng dụng Flutter** (giám sát + điều khiển) và **trang Admin Web** (test MQTT, fake data, relay). Dữ liệu điện qua MQTT, trạng thái relay đồng bộ qua **Firebase Realtime Database**.

---

## 1. Kiến trúc tổng quan

```
┌─────────────────┐     MQTT (electric)      ┌──────────────┐
│  Thiết bị/ESP   │ ─────────────────────► │  HiveMQ Cloud │
└─────────────────┘                          └──────┬───────┘
                                                    │
         ┌──────────────────────────────────────────┼──────────────────────────┐
         │                                          │                          │
         ▼                                          ▼                          ▼
┌─────────────────┐                        ┌─────────────────┐    ┌─────────────────┐
│  App Flutter    │◄── Firebase RTDB ─────►│  Web Admin      │    │  Relay (MQTT)   │
│  (Android/iOS)  │     ev_charging/relay  │  localhost:3000 │───►│  topic: relay   │
└─────────────────┘                        └─────────────────┘    └─────────────────┘
```

| Thành phần | Vai trò |
|------------|---------|
| **App Flutter** | Hiển thị dữ liệu sạc, điều khiển relay |
| **Web Admin** | Giám sát MQTT, fake data test, điều khiển relay |
| **MQTT HiveMQ** | Truyền dữ liệu điện (`electric`) và lệnh relay (`relay`) |
| **Firebase RTDB** | Lưu & đồng bộ trạng thái relay giữa app và web |

---

## 2. Cấu hình Firebase (bắt buộc cho Relay)

### 2.1 Bật Realtime Database

1. Vào [Firebase Console](https://console.firebase.google.com) → project **datn-cuan**
2. **Build** → **Realtime Database** → **Create Database**
3. Copy **Database URL** (vd: `https://datn-cuan-default-rtdb.firebaseio.com`)
4. Cập nhật URL tại:
   - `lib/config/app_config.dart` → `databaseUrl`
   - `web_admin/js/firebase-config.js` → `databaseURL`

### 2.2 Rules (giai đoạn phát triển)

Deploy file `database.rules.json` hoặc dán rules trong Console:

```json
{
  "rules": {
    "ev_charging": {
      "relay": {
        ".read": true,
        ".write": true
      }
    }
  }
}
```

> Production: thêm Firebase Auth và giới hạn `.write` theo `auth != null`.

### 2.3 Cấu trúc dữ liệu Relay trên Firebase

```
ev_charging/
  relay/
    state: true | false      ← trạng thái hiện tại
    defaultState: false      ← mặc định khi khởi tạo lần đầu
    updatedAt: 1700000000000  ← timestamp ms
    updatedBy: "app" | "web" | "init"
```

Đổi trạng thái mặc định ban đầu: sửa `relayDefaultState` trong `lib/config/app_config.dart` và `defaultState` trong `web_admin/js/firebase-config.js`.

---

## 3. MQTT Topics

| Topic | Hướng | Payload mẫu |
|-------|-------|-------------|
| `electric` | Thiết bị → App/Web | `{"voltage":220,"current":10,"power":2.2,"energy":1.5,"alarm":0,"hour":14,"minute":30}` |
| `relay` | App/Web → Thiết bị | `{"state":1}` bật / `{"state":0}` tắt |

Broker: HiveMQ Cloud (cấu hình trong `lib/services/mqtt_service.dart` và `web_admin/js/app.js`).

---

## 4. Chạy App Flutter

### Yêu cầu

- Flutter SDK (FVM 3.35.3)
- Đã chạy `flutterfire configure` (project **datn-cuan**)
- Realtime Database đã bật

### Lệnh

```bash
cd ev_charging_station
flutter pub get
flutter run
```

### Tính năng App

- **Giám sát**: nhận topic `electric`, hiển thị điện áp, dòng, công suất, biểu đồ
- **Timeout 15s**: không có dữ liệu → giao diện mặc định
- **Relay**: nút Bật/Tắt → lưu Firebase + gửi MQTT `relay`
- Đồng bộ relay realtime khi web admin thay đổi

---

## 5. Chạy Web Admin

```bash
cd web_admin
npm start
```

Mở **http://localhost:3000**

### Tab Quản lý

- Kết nối MQTT, cấu hình topic subscribe/publish
- Dashboard realtime + biểu đồ công suất
- **Điều khiển Relay** (Firebase + MQTT)
- Hộp thư bản tin, nhật ký

### Tab Kiểm thử

- **Fake Data Publisher**: tự gửi dữ liệu `electric` mỗi 2 giây
- Gửi dữ liệu điện thủ công
- Gửi JSON tùy chỉnh

### Quy trình test nhanh

1. Web: **Kết nối MQTT**
2. Web: Tab Kiểm thử → bật **Fake Data**
3. App Flutter: `flutter run` → thấy dữ liệu cập nhật
4. App hoặc Web: bật/tắt **Relay** → kiểm tra Firebase Console + MQTT log

---

## 6. Điều khiển Relay — Luồng hoạt động

1. Lần đầu mở app/web: tạo node `ev_charging/relay` với `state = defaultState` (mặc định **tắt**)
2. User bấm **Bật** hoặc **Tắt**:
   - Cập nhật Firebase RTDB
   - Gửi MQTT `{"state":1}` hoặc `{"state":0}` lên topic `relay`
3. App và Web lắng nghe Firebase → UI cập nhật đồng bộ

Thiết bị (ESP32, v.v.) cần subscribe topic `relay` và xử lý JSON `state`.

---

## 7. Cấu trúc thư mục chính

```
ev_charging_station/
├── lib/
│   ├── config/app_config.dart
│   ├── services/relay_service.dart
│   ├── bloc/relay/
│   └── widgets/relay_control_card.dart
├── web_admin/
│   ├── js/firebase-config.js
│   └── js/relay-service.js
├── database.rules.json
└── docs/HUONG_DAN_SU_DUNG.md
```

---

## 8. Xử lý lỗi thường gặp

| Lỗi | Cách xử lý |
|-----|------------|
| App không nhận MQTT | Kiểm tra internet, credential HiveMQ, topic `electric` |
| Relay không đồng bộ | Bật Realtime Database, kiểm tra `databaseUrl`, rules |
| `flutterfire configure` lỗi 401 | `firebase logout` → `firebase login --reauth` |
| Web relay không gửi MQTT | Bấm **Kết nối MQTT** trước khi bật/tắt relay |

---

## 9. Tham chiếu nhanh

```bash
flutter run
cd web_admin && npm start
flutterfire configure --project=datn-cuan
flutter build apk --debug
```
