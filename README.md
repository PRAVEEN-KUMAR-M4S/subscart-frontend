# SubsCart

A meal subscription management app built with **Flutter** (frontend) and **Node.js + Express + MongoDB** (backend). Users can browse their weekly meal schedule, skip/swap/move individual items, reschedule deliveries, and manage their subscription — all from a clean mobile UI with dark/light mode support.

---

## Table of Contents

- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Backend Setup](#backend-setup)
- [Frontend Setup](#frontend-setup)
- [API Reference](#api-reference)
- [Data Models](#data-models)
- [Environment Variables](#environment-variables)

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Flutter App                     │
│  (GetX state management + Dio HTTP client)       │
└──────────────────┬──────────────────────────────┘
                   │ REST API
┌──────────────────▼──────────────────────────────┐
│              Node.js / Express                   │
│  (REST API, CORS, request logging)               │
└──────────────────┬──────────────────────────────┘
                   │ Mongoose ODM
┌──────────────────▼──────────────────────────────┐
│              MongoDB Atlas                        │
│  (Subscription → Orders → Items)                 │
└─────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer        | Technology                                           |
| ------------ | ---------------------------------------------------- |
| Frontend     | Flutter 3.x, Dart 3.10+                              |
| State        | GetX (reactive state, DI, routing)                  |
| HTTP Client  | Dio                                                  |
| Connectivity | connectivity_plus (live offline/online detection)    |
| Backend      | Node.js, Express 5                                   |
| Database     | MongoDB (Atlas), Mongoose 9                          |
| Dev Tools    | Nodemon (backend hot-reload)                         |

---

## Project Structure

```
subscart/
├── lib/
│   ├── main.dart                              # App entry point
│   ├── app/
│   │   ├── data/
│   │   │   ├── providers/
│   │   │   │   └── schedule_api_provider.dart  # Dio HTTP calls
│   │   │   └── repositories/
│   │   │       └── schedule_repository.dart    # Data layer (error handling)
│   │   ├── modules/
│   │   │   └── schedule/
│   │   │       ├── bindings/
│   │   │       │   └── schedule_binding.dart   # GetX DI setup
│   │   │       ├── controllers/
│   │   │       │   └── schedule_controller.dart # Business logic
│   │   │       ├── models/
│   │   │       │   ├── meal_model.dart          # Item/meal model
│   │   │       │   ├── order_model.dart         # Order model
│   │   │       │   └── subscription_model.dart  # Subscription + DateSlot
│   │   │       └── views/
│   │   │           ├── schedule_view.dart       # Main screen
│   │   │           └── widgets/
│   │   │               ├── bottom_action_bar.dart
│   │   │               ├── date_pill_row.dart
│   │   │               ├── meal_item_card.dart
│   │   │               ├── order_card.dart
│   │   │               ├── schedule_header.dart
│   │   │               └── subscription_actions_row.dart
│   │   ├── routes/
│   │   │   ├── app_pages.dart
│   │   │   └── app_routes.dart
│   │   └── services/
│   │       └── theme_service.dart              # Dark/light mode toggle
│
├── mongooes/                                   # Backend (Express + Mongoose)
│   ├── index.js                                # Server entry point
│   ├── config/
│   │   └── db.js                               # MongoDB connection
│   ├── controllers/
│   │   ├── itemController.js                   # GET /api/items
│   │   ├── orderController.js                  # Orders + per-item CRUD
│   │   └── subscriptionController.js           # Subscriptions + slots
│   ├── models/
│   │   ├── Item.js                             # Item catalog
│   │   ├── Order.js                            # Orders + items sub-documents
│   │   └── Subscription.js                     # Subscription plan
│   ├── routes/
│   │   ├── itemRoutes.js
│   │   ├── orderRoutes.js
│   │   └── subscriptionRoutes.js
│   ├── seeds/
│   │   └── seed.js                             # Database seeder
│   └── .env                                    # Environment config
```

---

## Backend Setup

### Prerequisites

- Node.js ≥ 18
- MongoDB Atlas account (or local MongoDB)

### Install & Run

```bash
cd mongooes

# Install dependencies
npm install

# Seed the database (creates sample subscription, 30 orders, 25 items)
node seeds/seed.js

# Start development server (with hot-reload)
npm run dev

# Or start production
npm run serve
```

Server runs at `http://localhost:3000` (also accessible on LAN via `http://<your-ip>:3000`).

### Backend Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| **Subscriptions** | | |
| `GET` | `/api/subscriptions` | List all subscriptions |
| `GET` | `/api/subscriptions/:id` | Get subscription by ID |
| `POST` | `/api/subscriptions/:id/pause` | Toggle pause/resume |
| `POST` | `/api/subscriptions/:id/slots` | Add a new schedule day |
| **Orders** | | |
| `GET` | `/api/subscriptions/:id/orders?date=` | Get orders for a date |
| `GET` | `/api/subscriptions/:id/orders?startDate=&endDate=` | Get orders in range |
| `PATCH` | `/api/orders/:id/skip` | Skip an entire order |
| `PATCH` | `/api/orders/:id/swap` | Swap the primary meal |
| `PATCH` | `/api/orders/:id/move` | Reschedule to a new date |
| `PATCH` | `/api/orders/:id/reschedule` | Change delivery time slot |
| **Per-Item** | | |
| `PATCH` | `/api/orders/:orderId/items/:itemId/skip` | Remove an item from order |
| `PATCH` | `/api/orders/:orderId/items/:itemId/swap` | Swap a specific item |
| `PATCH` | `/api/orders/:orderId/items/:itemId/move` | Move item to another order |
| `POST` | `/api/orders/:orderId/items` | Add a new item to order |
| **Items** | | |
| `GET` | `/api/items` | List all available items |

---

## Frontend Setup

### Prerequisites

- Flutter SDK ≥ 3.10
- Android Studio / Xcode (for emulators)
- Physical device on same Wi-Fi as backend (for LAN testing)

### Install & Run

```bash
# Install dependencies
flutter pub get

# Update the backend IP address in:
# lib/app/data/providers/schedule_api_provider.dart
# Change baseUrl to your machine's LAN IP (e.g. http://192.168.1.41:3000/api)

# Run on connected device/emulator
flutter run
```

### Frontend Features

- **Schedule view** — scrollable date pills, order cards with items
- **Per-item actions** — Skip (removes item), Swap (pick new meal), Move (transfer to another order)
- **Add items** — tap "Add Item" to pick from the full catalog
- **Reschedule** — pick a new date + time with validation
- **Dark/Light mode** — toggle from the ⋮ menu in the header
- **Pull to refresh** — reloads orders for the selected date

---

## Data Models

### Subscription

```
{
  _id, userId, planName, mealsPerWeek, planDurationWeeks,
  scheduleDays: ["Mon","Tue",...], startDate, endDate,
  status: "active"|"paused"
}
```

### Order

```
{
  _id, subscriptionId, date, dayLabel, dateNum,
  status: "scheduled"|"skipped"|"swapped"|"moved",
  address, deliverySlot: { startTime, endTime, editableUntil },
  meal: { name, image, description },          // primary item
  items: [{                                     // multiple items
    _id, name, image, description, quantity,
    itemStatus: "scheduled"|"skipped"|"swapped"|"moved",
    swappedMeal: { name, image, description },
    movedDate, movedToOrderId, movedFromOrderId
  }]
}
```

### Item

```
{
  _id, name, image, description, isAvailable
}
```

---

## Environment Variables

Create a `.env` file in `mongooes/`:

```env
PORT=3000
MONGODB_URI=mongodb+srv://<user>:<password>@<cluster>.mongodb.net/<dbname>
```

---

## License

ISC
