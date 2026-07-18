# MedTrack EAM Platform

Enterprise Asset Management for Medical Equipment — built with Flutter + Supabase.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter 3.22+ (Android, Windows, macOS) |
| State Management | flutter_bloc (BLoC pattern) |
| Navigation | GoRouter 14 (typed, auth-guarded) |
| Backend | Supabase (PostgreSQL + Auth + Storage + RLS) |
| Design | Material 3 Expressive · Monotonic Dark Theme · Inter font |

---

## Project Structure

```
lib/
├── core/
│   ├── constants/       # AppConstants, AppStrings
│   ├── router/          # GoRouter + auth guard
│   ├── shell/           # AppShell (NavigationRail / NavigationBar)
│   ├── theme/           # AppTheme, AppColors, AppRadius, AppSpacing
│   └── utils/           # Responsive, AppFeedback
│
├── features/
│   ├── auth/            # Login · AuthBloc · UserProfile · AuthRepository
│   ├── clients/         # Clients list · Client detail · ClientsBloc · CRUD form
│   ├── dashboard/       # Analytics · DashboardBloc
│   ├── engineers/       # EngineersBloc · engineer form sheet
│   └── machines/        # Machine list · Machine detail · MachinesBloc · Invoice viewer
│
├── shared/
│   ├── extensions/      # DateTime, String, int helpers
│   └── widgets/         # AppButton, StatusChip, EmptyState, ConfirmDialog, RoleGuard
│
└── main.dart            # DI root, BLoC providers, MaterialApp.router
```

---

## Supabase Setup

### 1 — Create a Supabase project

Go to [supabase.com](https://supabase.com) → New project.

### 2 — Run migrations (in order)

Open **SQL Editor** → paste and run each file:

```
supabase/migrations/001_initial_schema.sql   # tables, RLS, storage bucket
supabase/migrations/002_seed_data.sql        # sample hospitals + machines
```

### 3 — Create test users

In **Authentication → Users → Invite user**:

| Email | Password | Role |
|---|---|---|
| admin@dme.com | Admin1234! | admin |
| viewer@dme.com | View1234! | user |

After creating the admin user, promote their role:

```sql
UPDATE public.profiles
SET role = 'admin'
WHERE id = '<uuid-from-auth-users>';
```

### 4 — Configure Flutter

In `lib/core/constants/app_constants.dart`, replace:

```dart
static const String supabaseUrl     = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

With your project URL and anon key from **Settings → API**.

---

## Running the App

```bash
# Install dependencies
flutter pub get

# Android
flutter run -d android

# Windows desktop
flutter run -d windows

# macOS desktop
flutter run -d macos
```

---

## RBAC Summary

| Action | Admin | User (View-Only) |
|---|---|---|
| View clients, machines, engineers | ✅ | ✅ |
| Create / Edit / Delete clients | ✅ | ❌ |
| Create / Edit / Delete machines | ✅ | ❌ |
| Upload / view invoices | ✅ | ✅ read |
| Manage engineer assignments | ✅ | ❌ |

Role is stored in `profiles.role` (PostgreSQL ENUM: `admin` | `user`) and enforced at the database layer via Row Level Security policies. The Flutter `RoleGuard` widget hides UI controls from non-admin users as a secondary layer.

---

## Key Design Decisions

- **Monotonic dark palette** — deep blacks (#0A0A0A scaffold) with a single Electric Indigo accent (#6C63FF) for all primary actions, matching medical-tech precision aesthetics.
- **Inter font** — clean, highly legible at all sizes; no decorative display faces.
- **Warranty lifecycle bar** — green → amber (≤3 months) → red (expired) with months-remaining counter, giving at-a-glance status without opening detail screens.
- **Signed URLs** — invoice PDFs are never publicly accessible; Supabase Storage generates 1-hour signed URLs on demand.
- **Responsive shell** — NavigationRail (width ≥ 900 px, desktop/tablet) automatically switches to NavigationBar (mobile), zero layout code duplication.
- **BLoC** — unidirectional data flow; every screen event triggers a state change that rebuilds only the affected widget subtree.

---

## Adding Invoice Upload (Admin Flow)

In `MachineDetailScreen`, wire the upload button:

```dart
final picker = FilePicker.platform;
final result = await picker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
if (result != null) {
  final bytes = result.files.first.bytes!;
  final path  = await repo.uploadInvoice(
    machineId: machine.id,
    fileBytes: bytes,
    fileName: result.files.first.name,
  );
  // Then update the machine record with the storage path:
  await repo.updateMachine(machine.copyWith(invoiceUrl: path));
}
```

---

## License

Private / Internal — DME Bangladesh
