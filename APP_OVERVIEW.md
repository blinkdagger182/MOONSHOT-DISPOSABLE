# Tetamu — App Overview

## What it is

Tetamu is a disposable camera app for events. A host creates an event and shares a QR code. Guests scan it — on iOS they get an App Clip, on Android they get a web camera — and take photos that go into a shared gallery the host controls.

---

## Repositories & Remotes

| Remote | Repo | Owner |
|--------|------|-------|
| `origin` | `blinkdagger182/MOONSHOT-DISPOSABLE` | Rizhan (main) |
| `tetamuapp` | `blinkdagger182/tetamuapp` | Rizhan (web-only, Clementine's web code) |
| `upstream` | `Clementine951/MOONSHOT-DISPOSABLE` | Clementine (original iOS + web) |

> **Note:** `tetamuapp` remote carries Clementine's older static web code. Our `public/` folder is the newer, more functional version (full camera experience). Do NOT wholesale merge from tetamuapp — it would downgrade the web app.

---

## Project Structure

```
MOONSHOT-DISPOSABLE/
├── Disposable/                   iOS Xcode project
│   ├── Disposable/               Main iOS app target
│   │   ├── DisposableApp.swift   App entry point, tab routing, deep link handling
│   │   ├── AppDelegate.swift     Firebase initialization
│   │   ├── HomeView.swift        Host dashboard — event controls, QR, gallery share
│   │   ├── CreateEvent.swift     3-step event creation wizard + QR share card
│   │   ├── CameraView.swift      Guest/host camera UI (wraps CameraModel)
│   │   ├── CameraModel.swift     AVFoundation capture session
│   │   ├── CameraPreview.swift   UIViewRepresentable for camera feed
│   │   ├── GalleryView.swift     Photo gallery with reveal gating
│   │   ├── JoinEventView.swift   Guest join flow (name + terms)
│   │   ├── SettingsView.swift    Event settings, account, leave/end event
│   │   ├── AppTypography.swift   Satoshi font helpers
│   │   └── Disposable.entitlements  Associated domains for App Clip + universal links
│   └── DisposableClip/           App Clip target (iOS only)
│       ├── DisposableClipApp.swift  App Clip entry, extracts eventId from URL
│       ├── BrowserClipExperience.swift  WKWebView loading tetamu.app clip flow
│       └── DisposableClip.entitlements  appclips: associated domains
├── public/                       Firebase Hosting web app (served from tetamu.app)
│   ├── html/template.html        Guest web camera UI (full camera + voice notes)
│   ├── js/template.js            Full camera logic: Firebase, capture, upload, voice, gallery
│   ├── css/template.css          Camera UI styles
│   ├── .well-known/apple-app-site-association   AASA for App Clip triggering
│   ├── apple-app-site-association               Root-level AASA copy
│   └── html/{about,privacy,terms,support}.html  Marketing/legal pages
├── functions/                    Firebase Cloud Functions (minimal, lint only currently)
├── firebase.json                 Firebase Hosting config + /clip rewrite rule
└── APP_OVERVIEW.md               This file
```

---

## Core Data Flow

### Event Creation (iOS Host)
1. Host fills 3-step wizard in `CreateEvent.swift` (details → settings → share)
2. On submit: writes to Firestore `events/{eventId}` + `events/{eventId}/participants` (role: organizer)
3. `eventId` = `"{eventName}_{UUID}"` — human-readable but unique
4. Persists event to `UserDefaults` so app restores on relaunch
5. Generates QR encoding `https://tetamu.app/clips?eventId={eventId}`

### Guest Joining (QR Scan)
| Platform | Flow |
|----------|------|
| iOS | AASA at `tetamu.app` triggers App Clip / main app routing |
| Android / browser | `tetamu.app` serves the guest camera experience |
| Main app installed (iOS) | Universal link → `onOpenURL` in `DisposableApp.swift` → navigates to `JoinEventView` |

### Photo Capture
- **iOS native**: `CameraModel` → `AVCaptureSession` → JPEG to Firebase Storage `events/{eventId}/{filename}.jpg` → URL saved to Firestore `events/{eventId}/images`
- **Web**: `getUserMedia` → canvas capture → optional vintage filter → JPEG blob to Firebase Storage → same Firestore path
- **Voice notes**: Web only → `MediaRecorder` → `.webm` to Storage `events/{eventId}/voice/` → Firestore `events/{eventId}/voiceNotes`

### Gallery & Reveal
- `GalleryView.swift` listens to `events/{eventId}/images` snapshot
- Reveal gating: if `reveal == "At the end"` and `now < startTime + duration`, photos are hidden until time passes
- Web mirrors same reveal logic in `template.js → applyRevealState()`

---

## Firebase Schema

```
events/
  {eventId}/
    eventId:            String
    eventName:          String
    userName:           String  (host name)
    location:           String
    duration:           Int     (hours: 12/24/48/72)
    reveal:             String  ("Immediately" | "At the end")
    numberOfPhotos:     Int     (shots per guest)
    guestLimit:         Int
    allowVoiceNotes:    Bool
    voiceNoteMaxSeconds: Int
    filterStyle:        String  ("none" | "vintage")
    startTime:          Timestamp

    participants/
      {autoId}/
        name:           String
        role:           String  ("organizer" | "participant" | "guest")
        userId:         String  (UUID)
        photosTaken:    Int
        photosTakenWeb: Int
        source:         String  ("web" | absent for native)
        joinedAt:       Timestamp

    images/
      {autoId}/
        url:            String  (Firebase Storage download URL)
        owner:          String  (guest name)
        source:         String  ("web-camera" | native)
        timestamp:      Timestamp

    voiceNotes/
      {autoId}/
        url:            String
        owner:          String
        source:         "web-voice"
        timestamp:      Timestamp
```

---

## Firebase Storage Layout

```
events/
  {eventId}/
    {guestName}_{timestamp}.jpg     (photos)
    voice/
      {guestName}_voice_{timestamp}.webm
```

---

## URL Scheme & Deep Linking

| URL | Purpose |
|-----|---------|
| `https://tetamu.app/clips?eventId=xxx` | **QR / join URL** — opens the current Tetamu join flow |
| `tetamu://` | iOS universal link (handled by `onOpenURL` in `DisposableApp`) |

AASA config at `public/.well-known/apple-app-site-association`:
- App Clip ID: `8H5C9P92ZB.com.riskcreatives.tetamu.clip`
- Main app ID: `8H5C9P92ZB.com.riskcreatives.tetamu`
- Both handle paths: `/clip*`

---

## iOS App Tabs

| Tab | View | Available |
|-----|------|-----------|
| Home | `HomeView` | Always |
| Camera | `CameraView` | Only when in event |
| Gallery | `GalleryView` | Only when in event |
| Settings | `SettingsView` | Always |

---

## Key Dependencies

| Dependency | Used by | Purpose |
|-----------|---------|---------|
| Firebase Firestore | iOS + Web | Event data, participants, image metadata |
| Firebase Storage | iOS + Web | Photo and voice note storage |
| Firebase Hosting | Web | Serves `tetamu.app` |
| AVFoundation | iOS | Camera capture |
| CoreImage | iOS | QR code generation |
| WKWebView | App Clip | Loads web guest experience |
| JSZip | Web | Bulk photo download |
| Satoshi font | iOS | Custom typography |

---

## Pending / Planned

- **Supabase migration**: Replace Firebase Firestore + Storage with Supabase (PostgreSQL + Supabase Storage). Requires credentials in `.env` at repo root.
- **Web framework**: Possible migration of guest web experience to Next.js (TBD — no Next.js code exists yet).
- **Android deep linking**: Firebase rewrite for `/clip` added; Android App Links (Digital Asset Links) not yet configured if needed beyond browser fallback.
