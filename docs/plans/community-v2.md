# Community v2 (update 2 of 3, D-155)

Owner's brief: "Community should be like X/Twitter": its own full-screen space, a friendlier AI check (greetings and
friendly chat allowed; still no adult content, politics, sports betting/gossip and other bad content), compose as its
own page, the best UI and animation.

## Scope

### App (Flutter) — a separate full-screen space, entered from Study → Community (and search)
- **Own shell**: bottom bar Home · Explore · Notifications · Profile, a gold compose button floating above it, a back
  arrow to leave Community. Hides on scroll down, returns on scroll up (like X).
- **Home**: For you / Following tabs (sticky), "N new posts" pill that slides in live, pull to refresh, endless scroll.
- **Post cell (X style)**: photo or initials, name, @handle, time, subject chip, text with $maths$ and #topics, up to
  4 pictures in a grid, quote-post card, actions: reply, repost (repost / quote), like (heart burst + haptic + rolling
  count), bookmark, share. "Being checked" and "Not shown: reason" states for the author only.
- **Post page**: the post large, then replies as a thread (reply to a reply, one level shown with "Show replies"),
  reply box pinned at the bottom.
- **Compose page**: full screen, avatar, big text box (500 characters, a ring that fills), add up to 4 photos, subject
  picker, maths preview toggle, @solutiontee to ask the AI, "Post" button; reply and quote modes reuse it.
- **Explore**: search (posts, people, #topics), trending #topics today, subjects grid, who to follow.
- **Notifications**: likes, replies, reposts, quotes, follows, mentions, SolutionTee AI answers, and "your post is
  shown / not shown"; grouped ("Tolu and 3 others liked your post"), live, unread dot on the tab.
- **Profile**: header banner (navy with subject pattern), photo or initials, name, @handle, bio, school/state (optional),
  joined date, following / followers (lists), tabs Posts · Replies · Likes · Bookmarks (own only); edit profile page.
- Respect "reduce motion", data saver (pictures load on tap), offline cached feed.

### Server (Supabase)
- New: `community_reposts` (repost or quote), `community_bookmarks`, `community_profiles` (handle, bio, show_photo,
  header style), `community_notifications`, comment `parent_id` (threads) and comment likes, post `images text[]`
  (up to 4), `quote_of`, hashtags (`community_tags`) for trending; feed/search/profile RPCs; live notifications on
  the student's own `user:<id>` channel (already used by the tutor banner).
- **AI check, friendlier**: allow greetings, friendly chat, motivation, school life, jokes about studying; still block
  sexual content, politics, betting and sports gossip, religion fights, bullying/insults, contacts and links, scams
  and selling, exam "expo", self-harm (with a kind message), spam. Handles and bios are checked too.
- Limits stay admin-editable; reports and auto-hide stay; Admin → Community gains reposts/quotes and profiles.

### Website
- Admin → Community: shows quotes, threads and pictures sets; profile check queue (handles, bios).

## Data / security
- Everything through RLS + security-definer RPCs as today; blocked users never see each other anywhere (feed, search,
  notifications, profiles). Pictures stay private (`c/<user id>/…`, signed only when the post is shown).
- Students' contact details are never shown. Profile photos: **owner decision** (see below).

## Owner decisions
1. **Profile photos in Community** for students (many are 13–17): (a) initials only, as today; (b) each student can
   choose to show their profile photo (off by default); (c) on for everyone. Recommended: (b), with under-18s' photos
   shown only to other students, never on the public web.
2. **@handles**: students pick a unique @handle (checked by the AI, changeable once a month). A handle is made for
   everyone from their first name first.

## Test plan
- RLS: blocked users invisible in feed, search, notifications and profiles; a pending or rejected post is visible only
  to its author; bookmarks private.
- AI check: greetings and friendly posts pass; politics, betting, sexual content, contacts, "expo" are rejected (live
  test, test posts removed).
- Widget tests: shell tabs, post cell states, compose limits, like animation off with reduce motion.
- Realtime: new-post pill and notification badge arrive without reopening.
