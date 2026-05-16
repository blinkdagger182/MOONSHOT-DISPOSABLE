# Disposable App - Setup Guide

## Database Setup (Supabase)

Since you chose not to auto-apply integrations, here's how to set up your Supabase database:

### Step 1: Execute the Schema SQL

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** in the sidebar
3. Click **New Query**
4. Copy the entire contents of `/supabase/schema.sql`
5. Paste it into the SQL editor
6. Click **Run**

This will create:
- `events` table - stores event metadata
- `photos` table - stores uploaded photos with metadata
- `guests` table - tracks event guests and their info
- `photo_likes` table - engagement tracking
- Row Level Security (RLS) policies - ensures data privacy
- Indexes - improves query performance

### Step 2: Add Environment Variables

1. Get your Supabase credentials:
   - Go to **Project Settings** → **API**
   - Copy `Project URL` and `Anon Key`

2. Create `.env.local` in the root directory with:
   ```
   NEXT_PUBLIC_SUPABASE_URL=your_project_url
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
   ```

3. Restart the dev server (`pnpm dev`)

## Project Structure

```
app/
  auth/
    callback/route.ts       - Supabase auth callback
  about/page.tsx           - About page
  privacy/page.tsx         - Privacy policy
  terms/page.tsx           - Terms of service
  page.tsx                 - Homepage
  layout.tsx               - Root layout with Tailwind CSS
  globals.css              - Global styles
events/
  [eventId]/
    page.tsx              - Dynamic event page (guest view)
lib/
  supabase/
    client.ts             - Browser Supabase client
    server.ts             - Server-side Supabase client
    middleware.ts         - Session management
middleware.ts             - Root middleware for auth
supabase/
  schema.sql              - Database schema and RLS policies
```

## Database Tables Overview

### events
- `id` - Unique identifier
- `user_id` - Event organizer (owner)
- `title` - Event name
- `event_type` - wedding, party, celebration, etc.
- `expires_at` - When photos expire
- `is_public` - Shareable with guests

### photos
- `id` - Photo identifier
- `event_id` - Parent event
- `user_id` - Photo uploader
- `photo_url` - Stored in Supabase Storage
- `expires_at` - Auto-delete timestamp

### guests
- `id` - Guest record ID
- `event_id` - Parent event
- `guest_code` - Unique code for anonymous access
- `email` / `phone` - Optional contact info

## Next Steps

1. ✅ Database schema created
2. Next: Build event pages with real-time gallery
3. Next: Add PWA for offline support
4. Next: Deploy to Vercel

## Security Notes

- All tables have Row Level Security (RLS) enabled
- Users can only see their own events
- Public events are viewable by anyone with the link
- Anonymous guests can upload photos without authentication
- Photos auto-delete after expiration (can be enabled via cron jobs)
