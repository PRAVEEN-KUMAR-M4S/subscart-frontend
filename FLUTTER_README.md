# SubsCart — Flutter Frontend

A meal subscription schedule app built with **Flutter 3.x** and **GetX**. Users manage their weekly deliveries — skip, swap, move, or add individual meal items — all from a single screen with dark/light mode support and live connectivity monitoring.

---

## Quick Start

```bash
# 1. Install dependencies
flutter pub get

# 2. Point to your backend
#    Edit lib/app/data/providers/schedule_api_provider.dart
#    Set baseUrl to your machine's LAN IP:
#    static const String baseUrl = 'http://192.168.1.41:3000/api';

# 3. Run
flutter run
```

> **Tip:** Use your PC's Wi-Fi IP for physical devices. For Android emulators use `10.0.2.2`. For iOS simulator / web use `localhost`.

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `get` | State management, dependency injection, routing, snackbars |
| `dio` | HTTP client for REST API calls |
| `intl` | Date/time formatting |
| `connectivity_plus` | Live network connectivity monitoring (WiFi, mobile, none) |
| `cupertino_icons` | iOS-style icons |

---

## Project Structure

```
lib/
├── main.dart                                      # App entry, theme, DI
├── app/
│   ├── data/
│   │   ├── providers/
│   │   │   └── schedule_api_provider.dart         # Raw Dio HTTP calls
│   │   └── repositories/
│   │       └── schedule_repository.dart           # Error handling + data parsing
│   ├── modules/
│   │   └── schedule/
│   │       ├── bindings/
│   │       │   └── schedule_binding.dart          # GetX dependency registration
│   │       ├── controllers/
│   │       │   └── schedule_controller.dart       # All business logic + state
│   │       ├── models/
│   │       │   ├── meal_model.dart                # Item/meal data model
│   │       │   ├── order_model.dart               # Order data model
│   │       │   └── subscription_model.dart        # Subscription + DateSlot
│   │       └── views/
│   │           ├── schedule_view.dart             # Main screen (Scaffold + ListView)
│   │           └── widgets/
│   │               ├── bottom_action_bar.dart     # Skip / Swap / Move buttons
│   │               ├── date_pill_row.dart         # Horizontal scrollable date pills
│   │               ├── meal_item_card.dart        # Single item card + per-item actions
│   │               ├── order_card.dart            # Order container + sheets
│   │               ├── schedule_header.dart       # Back arrow, plan title, theme toggle
│   │               └── subscription_actions_row.dart  # Pause / Add Slots buttons
│   ├── routes/
│   │   ├── app_pages.dart                        # Route definitions
│   │   └── app_routes.dart                       # Route name constants
│   └── services/
│       ├── connectivity_service.dart              # Live connectivity monitoring
│       └── theme_service.dart                    # Dark/light mode state
```

---

## Architecture

### Layer Diagram

```
┌──────────────────────────────────────────────────┐
│  Views (Widgets)                                  │
│  schedule_view.dart, order_card.dart, etc.        │
│  • Reactive Obx() builders                        │
│  • Call controller methods on user action          │
│  • Show offline banner when offline                │
└─────────────────────┬────────────────────────────┘
                      │ calls
┌─────────────────────▼────────────────────────────┐
│  Controller (schedule_controller.dart)             │
│  • Holds RxList/Rx state (orders, items, dates)    │
│  • Validates input (past dates, edit windows)      │
│  • Checks connectivity before mutations            │
│  • Auto-retries on reconnection                    │
│  • Shows snackbars + error dialogs                 │
└─────────────────────┬────────────────────────────┘
                      │ delegates
┌─────────────────────▼────────────────────────────┐
│  Repository (schedule_repository.dart)             │
│  • Wraps Dio calls in try/catch                    │
│  • Converts DioException → RepositoryException     │
│  • Parses JSON → Model objects                     │
└─────────────────────┬────────────────────────────┘
                      │ HTTP
┌─────────────────────▼────────────────────────────┐
│  API Provider (schedule_api_provider.dart)         │
│  • Raw Dio get/patch/post calls                    │
│  • Base URL + headers config                       │
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│  Services (GetX permanent services)                │
│  • ConnectivityService — live online/offline state │
│  • ThemeService — dark/light mode toggle           │
└──────────────────────────────────────────────────┘
```

### State Management (GetX)

- **Reactive lists:** `orders`, `availableItems`, `scheduleDays` — wrapped in `RxList`, auto-update UI via `Obx()`
- **Selected state:** `selectedOrder`, `selectedDateIndex` — `Rx` primitives
- **Loading/mutating flags:** `isLoading`, `isMutating` — disable buttons during async ops
- **Error state:** `errorMessage`, `isConnectionError` — shown as error view or snackbar
- **Connectivity:** `isOnline` — reactive `RxBool` from `ConnectivityService`

---

## Key Features

### 1. Schedule Navigation

- **DatePillRow** — horizontal scrollable list of day pills (auto-generated for the full subscription duration)
- Tapping a pill loads that day's orders via `GET /api/subscriptions/:id/orders?date=...`
- Shows "X deliveries on this date" when multiple orders exist

### 2. Per-Item Actions (Skip / Swap / Move)

Each meal item card has its own **Skip**, **Swap**, and **Move** buttons:

| Action | What happens | Backend endpoint |
|--------|-------------|-----------------|
| **Skip** | Item is removed from the order (with fade-out animation) | `PATCH /orders/:orderId/items/:itemId/skip` |
| **Swap** | Bottom sheet opens with the full item catalog; picks a replacement | `PATCH /orders/:orderId/items/:itemId/swap` |
| **Move** | Date picker → picks a target order on another day → item transfers | `PATCH /orders/:orderId/items/:itemId/move` |

### 3. Add Items

- "Add Item" button below the item list (visible when order is editable)
- Opens a bottom sheet listing all available items from `GET /api/items`
- One tap adds the selected item to the order

### 4. Reschedule Order

- "Reschedule" button in the order card header
- Two-step picker: **date** (date picker, only shows scheduled days) → **time** (time picker)
- Client-side validation: rejects past dates and past times for today
- Confirmation dialog shows the new date/time before submitting

### 5. Dark / Light Mode

- Toggle from the ⋮ menu in the **ScheduleHeader**
- Theme state managed by `ThemeService` (GetX service, persists across navigation)
- All widgets use `Theme.of(context).colorScheme` — no hardcoded light-only colors

### 6. Live Connectivity Monitoring

Powered by `connectivity_plus` — monitors network status in real-time:

| Feature | Description |
|---------|-------------|
| **Real-time detection** | Listens to `Connectivity().onConnectivityChanged` stream |
| **Offline banner** | Red banner at top of schedule view when offline |
| **Toast notifications** | Green "Back online" / red "You're offline" snackbars |
| **Mutation guard** | Blocks skip/swap/move/add/reschedule when offline |
| **Auto-retry** | Automatically retries `fetchSubscription()` when connectivity restores |
| **Reactive state** | `ConnectivityService.isOnline` — `RxBool` available to any widget/controller |

```
┌──────────────────────────────────────────────┐
│            ConnectivityService               │
│  (GetX permanent service)                    │
├──────────────────────────────────────────────┤
│  isOnline: RxBool  ←── updated by listener   │
│                                              │
│  On change:                                  │
│    → Online:  green snackbar + auto-retry    │
│    → Offline: red snackbar + offline banner  │
│                                              │
│  On mutation (skip/swap/move/add):           │
│    → Checks isOnline before API call         │
│    → Shows snackbar if offline               │
└──────────────────────────────────────────────┘
```

### 7. Error Handling

- **Connection error** — friendly "You're offline" screen with retry button
- **API errors** — dark snackbar with server message
- **Validation** — past date/time rejection with descriptive snackbar
- **Offline mutations** — "This action requires an internet connection" snackbar

---

## Connectivity Service

### How It Works

```dart
// lib/app/services/connectivity_service.dart
class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;  // Reactive connectivity state

  // 1. Checks initial status on startup
  // 2. Listens to Connectivity().onConnectivityChanged stream
  // 3. Shows snackbars on state changes
  // 4. Cancels subscription on dispose
}
```

### Integration Points

| Location | What happens |
|----------|-------------|
| `main.dart` | Registered as `Get.put(ConnectivityService(), permanent: true)` |
| `schedule_controller.dart` → `onInit()` | `ever(isOnline)` listener auto-retries when back online |
| `schedule_controller.dart` → `fetchSubscription()` | Offline check before network call; shows error screen |
| `schedule_controller.dart` → `_mutateOrder()` | `_requireOnline()` guard blocks mutations when offline |
| `schedule_controller.dart` → `moveItem()` / `moveOrder()` | Same `_requireOnline()` guard |
| `schedule_view.dart` | Obx-wrapped offline banner below header |

### Platform Requirements

| Platform | Extra setup needed |
|----------|-------------------|
| Android | `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` permissions (auto-added by plugin) |
| iOS | No extra setup — works out of the box |
| Web | Uses `navigator.onLine` — less granular but functional |
| macOS / Linux | Basic connectivity detection |

---

## Models

### MealModel (Item)

```dart
class MealModel {
  final String id;
  final String name;
  final String imageUrl;        // Flutter display key
  final String description;     // "354 Calories, 12g fat, ..."
  final int quantity;
  final ItemStatus itemStatus;  // scheduled | skipped | swapped | moved
  final MealModel? swappedMeal;
  final DateTime? movedDate;
}
```

> **Note:** Backend uses `image`; Flutter uses `imageUrl`. The `fromJson` handles both: `json['imageUrl'] ?? json['image']`.

### OrderModel

```dart
class OrderModel {
  final String id;
  final String orderNumber;
  final String address;
  final String deliverySlotStart, deliverySlotEnd, editableUntil;
  final MealModel meal;                    // primary item (backward compat)
  final List<MealModel> items;             // all items in this order
  final List<String> itemBackendIds;       // backend _id per item
  final OrderStatus status;
  final DateTime date;
}
```

### SubscriptionModel

```dart
class SubscriptionModel {
  final String id, planName, subtitle;
  final List<DateSlot> scheduleDays;       // generated for full subscription period
  final bool isPaused;
  final DateTime? startDate, endDate;
  final int? mealsPerWeek, planDurationWeeks;
}
```

---

## Data Flow: Adding an Item

```
User taps meal in _AddItemSheet
  → controller.addItemToOrder(orderId, MealModel)
    → _requireOnline() check  ←── blocks if offline
    → repository.addItemToOrder(orderId, newItem)
      → repository builds payload with 'image' key (not 'imageUrl')
      → provider.addItemToOrder(orderId, payload)  →  POST /api/orders/:id/items
        ← backend saves item, returns updated order
      ← repository parses JSON → OrderModel
    ← controller._replaceOrder(updated)  →  RxList updates
  ← UI rebuilds via Obx(), new item appears
  ← snackbar: "Item added"
```

### Data Flow: Offline → Online Recovery

```
Device goes offline
  → ConnectivityService.isOnline = false
  → Red "You're offline" snackbar
  → Offline banner appears in schedule_view.dart
  → User tries to skip/swap/move
    → _requireOnline() returns false
    → "This action requires an internet connection" snackbar
  → Device reconnects
    → ConnectivityService.isOnline = true
    → Green "Back online" snackbar
    → Offline banner disappears
    → ever() listener triggers fetchSubscription()
    → Orders reload automatically
```

---

## Configuration

### Backend URL

```dart
// lib/app/data/providers/schedule_api_provider.dart
static const String baseUrl = 'http://192.168.1.41:3000/api';
```

| Environment | URL |
|-------------|-----|
| Android emulator | `http://10.0.2.2:3000/api` |
| iOS simulator | `http://localhost:3000/api` |
| Physical device (Wi-Fi) | `http://<PC-IP>:3000/api` |
| Web (localhost) | `http://localhost:3000/api` |

---

## Running Tests

```bash
flutter test
```

---

## Common Issues

| Problem | Fix |
|---------|-----|
| `Connection refused` | Backend not running — `cd mongooes && npm run dev` |
| `SocketException` | Device not on same Wi-Fi as backend PC |
| Items show no image after add | Ensure backend `addItem` receives `image` key (not `imageUrl`) |
| Date pills only show one week | Check `SubscriptionModel.fromJson` generates dates across full subscription range |
| Theme not applying | Ensure `ThemeService` is registered in `main()` before `runApp()` |
| Offline banner not showing | Ensure `ConnectivityService` is registered in `main()` before `runApp()` |
| Mutations work when offline | `_requireOnline()` guard should block — check `ConnectivityService` is registered |
| Auto-retry not working | Check `ever()` listener in `onInit()` — should call `fetchSubscription()` on reconnection |
