# Disposable - Migration Complete

Your event photo sharing app has been successfully migrated from static HTML to a modern Next.js 15 + Supabase stack!

## What Was Built

### Phase 1: Next.js 15 + Supabase Foundation
- Modern React framework with TypeScript
- Supabase client setup for auth & database
- Tailwind CSS for styling
- Environment variables configured

### Phase 2: Database Schema & Security
- PostgreSQL tables: `events`, `photos`, `guests`, `photo_likes`
- Row Level Security (RLS) policies for data privacy
- Performance indexes for scalability
- See `supabase/schema.sql` for the full schema

### Phase 3: Marketing Pages
- Homepage with hero section and feature showcase
- About page explaining the concept
- Privacy policy & terms of service
- Support page with FAQs
- All pages use consistent branding and navigation

### Phase 4: Dynamic Event Pages
- Real-time photo gallery with Supabase Realtime subscriptions
- Guest-friendly interface (no login required)
- Photo upload API endpoint (`/api/photos/upload`)
- Responsive image grid with metadata
- Event expiration handling

### Phase 5: PWA Capabilities
- Installable app for iOS & Android
- Offline support with service workers
- App manifest with proper metadata
- Home screen icons and splash screens

## Project Structure

```
app/
  auth/                    - Authentication pages
  events/[eventId]/        - Dynamic event gallery pages
  about/, privacy/, terms/, support/  - Marketing pages
  api/
    photos/upload/         - Photo upload endpoint
  page.tsx                 - Homepage
  layout.tsx               - Root layout with PWA metadata
  globals.css              - Tailwind & global styles

lib/supabase/
  client.ts                - Browser Supabase client
  server.ts                - Server Supabase client
  middleware.ts            - Session management

supabase/
  schema.sql               - Database schema & RLS policies

public/
  manifest.json            - PWA manifest
  icon-192.png, icon-512.png  - App icons
```

## Next Steps

### 1. Set Up Supabase Database (REQUIRED)
1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Create a new query and paste the contents of `supabase/schema.sql`
4. Execute the query to create all tables and RLS policies

### 2. Add Environment Variables (REQUIRED)
Create `.env.local` in the root directory:
```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
```

Get these values from your Supabase project settings → API

### 3. Test Locally
```bash
pnpm dev
# Visit http://localhost:3000
```

### 4. Deploy to Vercel (Recommended)
```bash
pnpm run build
```

Then either:
- Push to GitHub and connect to Vercel (automatic deployments)
- Or use `vercel` CLI to deploy manually

### 5. Configure Storage Bucket
In Supabase dashboard:
1. Create a new storage bucket named `event-photos`
2. Set it to public (allow read-only access)
3. Set up a policy to allow uploads from `public.photos` table

## Key Features & APIs

### Photo Upload
```
POST /api/photos/upload
- multipart/form-data
- Fields: file, eventId, caption (optional), guestCode (optional)
- Returns: { photo: { id, photo_url, caption, created_at } }
```

### Database Tables
- **events** - Event metadata (title, type, expiration)
- **photos** - Photo records with URLs and metadata
- **guests** - Guest information and tracking
- **photo_likes** - Engagement tracking (optional)

### Real-time Updates
Photo uploads appear instantly via Supabase Realtime subscriptions on event pages.

## Security

- Row Level Security (RLS) enabled on all tables
- Anonymous guests can upload without authentication
- Event organizers can only see/manage their own events
- Public events visible to anyone with the link
- Photos auto-expire after configured time

## Customization

### Colors
Edit `tailwind.config.ts` to change:
- Primary: `#097456` (green)
- Secondary: `#FFB27E` (orange)
- Accent: `#E8D7FF` (purple)

### Branding
- Homepage copy in `app/page.tsx`
- App name in `public/manifest.json`
- Meta tags in `app/layout.tsx`

## Troubleshooting

**Dev server not starting?**
- Ensure `.env.local` is set up
- Run `pnpm install` to verify dependencies
- Check for port conflicts (default: 3000)

**Photos not uploading?**
- Verify Supabase storage bucket is public
- Check event hasn't expired
- Verify photo limit not reached

**Realtime not working?**
- Ensure Realtime is enabled in Supabase settings
- Check browser console for connection errors

## Performance Notes

- Images are stored in Supabase Storage
- Supabase Realtime for live gallery updates
- Tailwind CSS for optimized styling
- ISR (Incremental Static Regeneration) ready for pages

## Next Features to Build

1. **User Dashboard** - Event management for hosts
2. **Photo Editing** - In-app filters and effects
3. **Analytics** - Engagement metrics for events
4. **Sharing** - Direct share to social media
5. **Notifications** - Real-time alerts for new photos

## Support

For questions or issues, refer to:
- Supabase docs: https://supabase.com/docs
- Next.js docs: https://nextjs.org/docs
- Tailwind docs: https://tailwindcss.com/docs

---

**Migration completed:** Next.js 15 + Supabase + PWA ready for deployment!
