# Disposable - Event Photo Sharing App

A modern, ephemeral photo sharing app for weddings, parties, and events. Guests can upload photos instantly via web links—no app download needed. Photos auto-delete after the event, keeping memories exclusive and authentic.

## Tech Stack

- **Frontend:** Next.js 15, React 19, TypeScript, Tailwind CSS
- **Backend:** Supabase (PostgreSQL, Auth, Realtime, Storage)
- **Infrastructure:** Vercel deployment
- **PWA:** Installable on iOS & Android

## Quick Start

### Prerequisites
- Node.js 18+
- Supabase account (free tier works)
- pnpm (or npm/yarn)

### Installation

1. **Clone or download this project**
2. **Install dependencies:**
   ```bash
   pnpm install
   ```

3. **Set up Supabase:**
   - Create a new Supabase project at supabase.com
   - Copy `supabase/schema.sql` into Supabase SQL Editor
   - Execute the query to create tables & RLS policies

4. **Configure environment variables:**
   Create `.env.local`:
   ```
   NEXT_PUBLIC_SUPABASE_URL=your_project_url
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
   ```
   Get these from Supabase Project Settings → API

5. **Run development server:**
   ```bash
   pnpm dev
   ```
   Visit `http://localhost:3000`

## Project Features

### For Event Hosts (iOS/Android App)
- Create events with custom settings
- Generate shareable QR codes & links
- View real-time photo uploads
- Set photo expiration times
- Manage guest lists
- Download memories before they expire

### For Guests (Web Browser)
- No app download required
- Tap link or scan QR code to join event
- Take photos with retake option
- Add captions or just upload
- View gallery in real-time
- React with likes/engagement

### Technical Features
- Real-time photo gallery with Supabase Realtime
- Row Level Security for data privacy
- Automatic photo expiration
- PWA installation on mobile
- Responsive design (mobile-first)
- Fast page loads with ISR

## Project Structure

```
disposable/
├── app/                      # Next.js App Router
│   ├── auth/                 # Auth pages & callback
│   ├── events/[eventId]/     # Event gallery page (dynamic)
│   ├── about/                # Marketing pages
│   ├── privacy/
│   ├── terms/
│   ├── support/
│   ├── page.tsx              # Homepage
│   ├── layout.tsx            # Root layout with PWA setup
│   └── globals.css           # Global styles
│
├── lib/
│   └── supabase/             # Supabase clients & middleware
│       ├── client.ts         # Browser client
│       ├── server.ts         # Server client
│       └── middleware.ts     # Auth session management
│
├── public/
│   ├── manifest.json         # PWA manifest
│   ├── icon-192.png          # App icon
│   └── icon-512.png
│
├── supabase/
│   └── schema.sql            # Database schema & RLS policies
│
├── SETUP.md                  # Database setup guide
├── MIGRATION.md              # Migration details from static HTML
├── next.config.ts            # Next.js config with PWA
├── tailwind.config.ts        # Tailwind configuration
└── package.json              # Dependencies
```

## Key APIs & Endpoints

### `/api/photos/upload`
Upload a photo to an event gallery.

**Request:**
```
POST /api/photos/upload
Content-Type: multipart/form-data

Fields:
- file (File): Image to upload
- eventId (string): Event UUID
- caption (string, optional): Photo caption
- guestCode (string, optional): Anonymous guest code
```

**Response:**
```json
{
  "photo": {
    "id": "uuid",
    "photo_url": "https://...",
    "caption": "...",
    "created_at": "2026-05-15T10:30:00Z"
  }
}
```

### Database Tables

**events**
- `id`, `user_id` (owner), `title`, `description`
- `event_type` (wedding | party | celebration | other)
- `expires_at` (when photos auto-delete)
- `is_public` (shareable with guests)

**photos**
- `id`, `event_id`, `user_id` (uploader)
- `photo_url`, `caption`, `created_at`
- `expires_at` (auto-deleted after this)

**guests**
- `id`, `event_id`, `guest_code` (for anonymous access)
- `email`, `phone`, `name`

**photo_likes**
- `id`, `photo_id`, `user_id`, `created_at`

## Development

### Available Scripts

```bash
pnpm dev          # Start dev server (http://localhost:3000)
pnpm build        # Build for production
pnpm start        # Start production server
pnpm lint         # Run ESLint
```

### Styling

- Tailwind CSS for utility-first styling
- Custom colors in `tailwind.config.ts`:
  - Primary (green): `#097456`
  - Secondary (orange): `#FFB27E`
  - Accent (purple): `#E8D7FF`

### Adding New Pages

Create new files in `app/` using Next.js App Router:

```tsx
// app/new-page/page.tsx
export default function NewPage() {
  return <main>Page content</main>
}
```

## Deployment

### Deploy to Vercel (Recommended)

1. **Push to GitHub**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git push origin main
   ```

2. **Connect to Vercel**
   - Visit vercel.com/dashboard
   - Import GitHub repo
   - Add environment variables
   - Deploy

3. **Or use Vercel CLI**
   ```bash
   pnpm global add vercel
   vercel
   ```

### Environment Variables on Vercel

Add in Vercel project settings:
```
NEXT_PUBLIC_SUPABASE_URL=your_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_key
```

## Security

- All database tables have Row Level Security (RLS) enabled
- Users can only access their own events
- Anonymous guests can upload without authentication
- Photos expire automatically
- Sensitive data is protected by RLS policies

## Browser Support

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Mobile Safari (iOS 14+)
- Chrome Mobile (Android 6+)

## PWA Installation

Users can install the app on their home screen:

**iOS:**
1. Open in Safari
2. Tap Share → Add to Home Screen

**Android:**
1. Open in Chrome
2. Tap Menu → Install app

## Troubleshooting

**Q: Photos aren't appearing in gallery?**
A: Check that Supabase Realtime is enabled and photo upload API returned successfully.

**Q: Event page shows "Event not found"?**
A: Verify the event ID in the URL and that the event exists in your Supabase database.

**Q: Can't upload photos?**
A: Check that the `event-photos` storage bucket is public in Supabase and RLS policies allow uploads.

**Q: Dev server crashes on startup?**
A: Ensure `.env.local` is properly configured with Supabase credentials.

## Performance Optimization

- Images stored in Supabase (CDN delivery)
- Tailwind CSS minified (~15KB)
- Server-side rendering for SEO
- ISR for static pages
- Lazy loading on images

## Future Enhancements

- Event creation dashboard for hosts
- Photo editing tools (filters, effects)
- Analytics dashboard (view counts, engagement)
- Social media sharing integration
- Downloadable photo collections
- Event reminders & invitations

## License

MIT - Feel free to use this for your own projects!

## Support

For issues or questions:
- Check `SETUP.md` for database setup help
- See `MIGRATION.md` for architecture details
- Review Supabase docs: https://supabase.com/docs
- Next.js docs: https://nextjs.org/docs

---

Built with Next.js 15 + Supabase + Tailwind CSS
