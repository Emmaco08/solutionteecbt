# Windows vs Android: every feature (D-166, D-167)

The Windows app is the same app as Android (same code, same 101 screens, same server, same account). Every screen is
opened in the Windows layout by `test/desktop_routes_test.dart`; the plugins behind the features run on a real Windows
machine in `integration_test/windows_smoke_test.dart` for every Windows build.

**Same** = works exactly as on Android. **Adapted** = same result, done the computer way. **Not possible** = no
Windows version of that Google service exists. **Setup** = needs one step from the owner.

## Study and exams
| Feature | Windows | How on Windows |
|---|---|---|
| JAMB, WAEC, NECO CBT practice (subjects, years, custom tests, quick test) | Same | Wider layout; question palette always open on the right |
| Timer, auto-submit, resume a test later | Same | |
| Keyboard for CBT | Adapted (extra) | A–E choose, ←/→ move, F flag, C calculator, Ctrl+Enter submit |
| Calculator in tests | Same | |
| Results, review, explanations, JAMB score scaling | Same | |
| Past questions, videos, notes, novels, PDF documents | Same | Video and PDF checked on real Windows |
| Save videos and PDFs offline (Downloads) | Same | Stored in the app's Windows folder |
| Bookmarks, study search, search everywhere | Same | Ctrl+K or Ctrl+F opens search |
| Offline mode (questions, attempts, no-internet banner) | Same | Local database checked on real Windows |
| Screenshot protection in tests and challenges | Adapted | Windows "exclude from capture": screenshots and recordings show the window black |
| Fair play (leaving the challenge screen counts) | Adapted | Switching to another window counts as leaving |

## AI, classes, tutors
| Feature | Windows | How on Windows |
|---|---|---|
| AI tutor chat, history, study plan | Same | Enter sends, Shift+Enter new line |
| Ask the AI with a photo | Adapted | Choose a picture file (laptop cameras are not supported by the photo plugin) |
| Voice questions (speech to text) | Same | Needs a microphone and Windows microphone permission |
| Online classes, programmes, countdowns, join links | Same | Join links open in the browser |
| Request a tutor, chat, photos, voice notes, quizzes | Same | Voice notes use the laptop microphone; photos from files |

## Play, connect, rewards
| Feature | Windows | How on Windows |
|---|---|---|
| Challenges (cash prizes, mock exams, winners, claim prize, appeal) | Same | |
| Leaderboards (weekly to all-time, challenge boards) | Same | |
| XP, streaks, badges, daily claim, invite and earn | Same | |
| Game Zone (all games, ranks, friend codes, arena, Beat the AI, Reading Race) | Same | Sounds play as MP3 on Windows (checked on real Windows) |
| Community (posts, images, replies, follows, mentions, notifications, moderation) | Same | Images from files |
| News (likes, comments, saved, share) | Same | Share uses the Windows share panel |
| Careers and subject combinations, exam countdown | Same | |

## Account, payments, safety
| Feature | Windows | How on Windows |
|---|---|---|
| Email sign-up, 6-digit code, sign-in, reset password | Same | |
| Sign in with Google | Setup | Opens the browser. Owner: add `http://localhost:53682/**` to Supabase redirect URLs, then turn on "Also on the Windows app" in Admin |
| Age rules, parent email, account delete, legal pages | Same | |
| Premium with Paystack (card, transfer, USSD, OPay, bank apps) | Adapted | Paystack opens in the browser; the app confirms by itself and closes the checkout |
| Discount codes | Same | |
| Google Play Billing | Not possible | Play exists only on Android; Windows uses Paystack |
| One account per device, banned devices, appeals, "allow twice" | Same | Computer's hardware id + Windows id (like Android's two ids); virtual machines flagged `vm` |
| Bans, safety bans, maintenance mode, force update | Same | |

## Notifications and app
| Feature | Windows | How on Windows |
|---|---|---|
| Notifications list (bell), switches in Settings | Same | |
| Push notifications | Adapted | While the app is open, even minimised: Windows notification + flashing taskbar; in-app toast when in front. Nothing when the app is fully closed |
| App updates | Adapted | Our own updater downloads the new installer and updates in place |
| Dark mode, reduce motion, data saver | Same | |
| House ads (your own brand campaigns) | Same | |
| Google AdMob ads, "watch a video to unlock or earn" | Not possible | AdMob has no Windows version, so Windows has no AdMob ads and no reward videos |
| Play Store review prompt, Play in-app update | Not possible | Play only |
| App-icon quick actions (long-press icon) | Not possible | Ctrl+K search and the sidebar instead |
| Vibration (haptics) | Not possible | Laptops do not vibrate |
| Keep the screen awake during videos | Same | |
| Window | Extra | Opens maximised on small laptops, minimum size 960 × 640, one window only (opening again brings it forward) |
