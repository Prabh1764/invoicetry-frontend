# ProBilling Frontend

Flutter mobile application for ProBilling with Material 3 design.

## Prerequisites

- Flutter SDK 3.0+ (check with `flutter --version`)
- Dart SDK (comes with Flutter)
- Backend API running (see `/backend/README.md`)

## Setup

1. **Install dependencies:**
```bash
flutter pub get
```

2. **Copy environment file:**
```bash
cp .env.sample .env
```

3. **Configure `.env` with your backend URL:**
```env
BACKEND_BASE_URL=http://localhost:3000
WHATSAPP_DEFAULT_PREFIX=+1
```

**Note:** For Android emulator, use `http://10.0.2.2:3000` instead of `localhost:3000`.
For iOS simulator, `localhost` should work fine.

## Running the App

### Development Mode

```bash
flutter run
```

### Debug Mode

```bash
flutter run --debug
```

### Release Mode

```bash
flutter run --release
```

## Building

### Android APK
```bash
flutter build apk
```

### iOS (requires macOS and Xcode)
```bash
flutter build ios
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # Main app widget
├── router.dart                  # Navigation routing
├── theme/
│   └── app_theme.dart          # Material 3 theme
├── widgets/
│   ├── app_card.dart           # Reusable card widget
│   ├── primary_button.dart     # Primary button style
│   └── tag_chip.dart           # Status tag chips
├── data/
│   ├── models/                 # Data models
│   │   ├── client.dart
│   │   ├── invoice.dart
│   │   ├── invoice_item.dart
│   │   ├── job_template.dart
│   │   └── auth_token.dart
│   ├── services/               # API services
│   │   ├── api_client.dart     # Dio client with interceptors
│   │   ├── auth_service.dart
│   │   ├── client_service.dart
│   │   ├── invoice_service.dart
│   │   ├── job_template_service.dart
│   │   └── pdf_service.dart
│   └── repositories/           # Data repositories
│       ├── auth_repo.dart
│       ├── client_repo.dart
│       ├── invoice_repo.dart
│       └── job_template_repo.dart
└── features/
    ├── auth/                   # Authentication
    │   ├── login_screen.dart
    │   ├── register_screen.dart
    │   └── providers/
    │       └── auth_provider.dart
    ├── home/                   # Dashboard
    │   └── home_screen.dart
    ├── invoices/               # Invoice management
    │   ├── invoice_list_screen.dart
    │   ├── invoice_details_screen.dart
    │   └── edit_invoice_screen.dart
    ├── clients/                # Client management
    │   ├── clients_list_screen.dart
    │   └── edit_client_screen.dart
    ├── jobs/                   # Job templates
    │   ├── job_templates_list_screen.dart
    │   └── edit_job_template_screen.dart
    └── pdf/                    # PDF viewer
        └── pdf_viewer_screen.dart
```

## Features

- **Authentication**: Login/Register with JWT token storage
- **Dashboard**: Home screen with statistics cards
- **Invoice Management**: 
  - List, view, create, and edit invoices
  - Generate PDFs
  - View PDFs in built-in viewer
  - Share via system share and WhatsApp
  - Mark invoices as paid
- **Client Management**: CRUD operations for clients
- **Job Templates**: Manage reusable job templates
- **Material 3 Design**: Premium UI with Google Fonts

## Environment Variables

The app uses `.env` file for configuration:

- `BACKEND_BASE_URL`: Backend API base URL (default: `http://localhost:3000`)
- `WHATSAPP_DEFAULT_PREFIX`: Default country code for WhatsApp links (default: `+1`)

## Testing

Run tests:
```bash
flutter test
```

Run analysis:
```bash
flutter analyze
```

## Troubleshooting

### Backend Connection Issues

- Ensure backend is running on the configured port
- Check that `BACKEND_BASE_URL` in `.env` is correct
- For Android emulator, use `http://10.0.2.2:3000` instead of `localhost:3000`
- Check network connectivity between device/emulator and backend

### Build Issues

- Run `flutter clean` and `flutter pub get`
- Ensure all dependencies are up to date: `flutter pub upgrade`
- Check Flutter version compatibility

### Authentication Issues

- Clear app data and re-login
- Check that JWT token is being stored correctly
- Verify backend JWT_SECRET configuration

## Development

### Adding New Features

1. Create models in `lib/data/models/`
2. Create services in `lib/data/services/`
3. Create repositories in `lib/data/repositories/`
4. Create screens in `lib/features/[feature]/`
5. Add routes in `lib/router.dart`
6. Add providers if needed for state management

### State Management

The app uses Riverpod for state management:
- Providers for dependency injection
- FutureProvider for async data
- StateNotifierProvider for complex state

## License

Proprietary
