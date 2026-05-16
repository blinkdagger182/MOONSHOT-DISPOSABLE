# Disposable App - Post-Migration Checklist

## Immediate Setup (Required)

- [ ] **1. Get Supabase Credentials**
  - Create account at supabase.com if you haven't
  - Create new project (free tier is fine)
  - Go to Project Settings → API
  - Copy Project URL and Anon Key

- [ ] **2. Create `.env.local`**
  - Create file in project root: `touch .env.local`
  - Add:
    ```
    NEXT_PUBLIC_SUPABASE_URL=your_project_url_here
    NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key_here
    ```
  - Save file (keep it secure!)

- [ ] **3. Execute Database Schema**
  - Go to Supabase dashboard
  - Click "SQL Editor" in sidebar
  - Click "New Query"
  - Open `supabase/schema.sql` from project
  - Copy entire content into SQL editor
  - Click "Run"
  - Wait for success message ✓

- [ ] **4. Create Storage Bucket**
  - In Supabase dashboard, go to Storage
  - Click "New bucket"
  - Name: `event-photos`
  - Make it public (allow read-only access)
  - Click "Create bucket"

## Testing Locally

- [ ] **5. Install Dependencies**
  ```bash
  pnpm install
  ```

- [ ] **6. Start Dev Server**
  ```bash
  pnpm dev
  ```

- [ ] **7. Test Homepage**
  - Open http://localhost:3000
  - Should see homepage with features
  - Check navigation links work
  - Try clicking buttons

- [ ] **8. Test Navigation**
  - Visit `/about` - should load
  - Visit `/privacy` - should load
  - Visit `/terms` - should load
  - Visit `/support` - should load

- [ ] **9. Test Event Page (Mock)**
  - Visit `/events/00000000-0000-0000-0000-000000000000`
  - Should show "Event not found" (expected without real event)

## Before Deployment

- [ ] **10. Review Documentation**
  - Read README.md
  - Read SETUP.md
  - Read MIGRATION.md
  - Understand the architecture

- [ ] **11. Environment Variables**
  - Verify `.env.local` is in `.gitignore` (should be)
  - Never commit `.env.local` to Git

- [ ] **12. Build for Production**
  ```bash
  pnpm build
  ```
  - Should complete without errors

- [ ] **13. Test Production Build**
  ```bash
  pnpm start
  ```
  - Verify pages load correctly

## Deployment to Vercel

- [ ] **14. Create Vercel Account**
  - Visit vercel.com
  - Sign up (connect with GitHub recommended)

- [ ] **15. Push Code to GitHub**
  ```bash
  git init
  git add .
  git commit -m "Disposable app - Next.js migration"
  git branch -M main
  git remote add origin https://github.com/YOUR_USERNAME/disposable.git
  git push -u origin main
  ```

- [ ] **16. Deploy to Vercel**
  - Go to vercel.com/new
  - Import GitHub repository
  - Select "disposable" repo
  - Choose Next.js framework
  - Environment variables section:
    - Add `NEXT_PUBLIC_SUPABASE_URL`
    - Add `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - Click "Deploy"

- [ ] **17. Wait for Deployment**
  - Vercel will build and deploy automatically
  - Takes 1-2 minutes typically
  - Get deployment URL when done

- [ ] **18. Test Live Deployment**
  - Visit your Vercel deployment URL
  - Verify all pages load
  - Check mobile responsiveness
  - Test PWA installation (if on mobile)

## Supabase Production Setup (Optional)

- [ ] **19. Enable Backups** (optional but recommended)
  - Supabase dashboard → Backups
  - Enable daily backups

- [ ] **20. Set Up Monitoring** (optional)
  - Monitor API usage
  - Set up alerts for storage quota

## Post-Launch

- [ ] **21. Custom Domain** (optional)
  - In Vercel dashboard → Settings → Domains
  - Add your custom domain
  - Configure DNS records

- [ ] **22. Create Events in App**
  - Once you have user auth, create test events
  - Generate QR codes
  - Test guest photo uploads

- [ ] **23. Monitor Performance**
  - Check Vercel Analytics
  - Monitor Supabase usage
  - Track real-time gallery updates

- [ ] **24. Set Up Notifications** (optional)
  - Email for event expiration
  - Photo upload notifications
  - Admin alerts

## Customization (Optional)

- [ ] **25. Update Branding**
  - Change colors in `tailwind.config.ts`
  - Update app name in `public/manifest.json`
  - Update homepage copy in `app/page.tsx`

- [ ] **26. Add Custom Icons**
  - Replace `icon-192.png` and `icon-512.png`
  - Update manifest.json with new icon URLs

- [ ] **27. Update Metadata**
  - Edit `app/layout.tsx` for SEO tags
  - Update social media preview text

- [ ] **28. Add Analytics** (optional)
  - Supabase provides usage stats
  - Can add Vercel Analytics
  - Can add Google Analytics

## Future Features (Not Yet Built)

- [ ] User Dashboard for event hosts
- [ ] Photo editing tools
- [ ] Advanced analytics
- [ ] Email notifications
- [ ] Mobile apps (iOS/Android)
- [ ] Social media integration
- [ ] Premium tiers/payments

## Troubleshooting Guide

### Dev Server Won't Start
- [ ] Check `.env.local` exists and is valid
- [ ] Run `pnpm install` to verify dependencies
- [ ] Check port 3000 is not in use
- [ ] Delete `.next` folder and rebuild

### Supabase Connection Error
- [ ] Verify `.env.local` has correct URL and key
- [ ] Check Supabase project is not paused
- [ ] Verify schema.sql was executed successfully

### Photos Not Uploading
- [ ] Check `event-photos` bucket exists and is public
- [ ] Verify event hasn't expired
- [ ] Check browser console for errors

### Realtime Not Working
- [ ] Enable Realtime in Supabase project settings
- [ ] Check WebSocket connection in browser DevTools
- [ ] Verify RLS policies allow queries

### Build Fails on Vercel
- [ ] Check environment variables are set
- [ ] Review Vercel build logs
- [ ] Ensure Node.js version is compatible

## Support Resources

- **Supabase Issues:** https://supabase.com/docs
- **Next.js Issues:** https://nextjs.org/docs
- **Vercel Deployment:** https://vercel.com/docs/concepts/deployments/overview
- **Tailwind CSS:** https://tailwindcss.com/docs

## Success Criteria

You'll know the migration was successful when:

✓ Dev server starts with `pnpm dev`  
✓ Homepage loads at http://localhost:3000  
✓ All pages (about, privacy, terms, support) are accessible  
✓ Event page loads (shows "Event not found" for invalid ID)  
✓ Deployment to Vercel completes without errors  
✓ Live site is accessible at your Vercel URL  
✓ PWA is installable on mobile  
✓ Real-time photo gallery works when events exist  

## Final Notes

- **This is a complete migration** from static HTML to a production-ready Next.js app
- **Database is ready** with RLS policies for multi-tenant support
- **PWA is configured** for mobile installation
- **All documentation is included** for future reference
- **You control the timeline** - set up Supabase when ready

---

**Estimated Time to Full Production:** 30-60 minutes total  
**Difficulty Level:** Easy (following this checklist)  
**Support:** Refer to SETUP.md, README.md, and MIGRATION.md

Good luck! You've got this. 🚀
