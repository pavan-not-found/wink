# Wink launch plan

Goal: 100 to 200 people download Wink in the first few days.

## 1. Before anything goes public (about 15 minutes, needs you)

1. **Try it for real.** Wink is installed in Applications, and the eye is in your menu bar.
   - Click the eye, leave it on 2 hours, press Keep awake. macOS asks for your password once. That's the lid-closed permission.
   - Play some music or start a recording, close the lid for a minute, open it. It should still be running, and the menu bar should show the amber eye with time counting down.
   - Press the stop button. Your Mac sleeps normally again.
2. **Your Mac has been set to never sleep since your old `pmset` command.** When the popover shows "Your Mac is set to never sleep", press "Turn normal sleep back on" once you no longer need it. (I left it alone because another task was running overnight.)
3. **Confirm the name.** Everything says Wink. If you change it, the name lives in `Resources/Info.plist`, `Sources/Wink`, the README, `docs/index.html`, `launch/POSTS.md` and the film's end card.
4. **Fill in your GitHub profile.** The account is `pavan-not-found`. Add a photo, your name, a one-line bio and your X handle, because people who click through from a post will look at who made it.

## 2. Publishing (I can do these once you say go)

- [ ] Create the public repo and push.
- [ ] Tag `v1.0.0`. The GitHub Action builds Wink and attaches `Wink.dmg` and `Wink.zip` to the release. (Or I upload the build that's already in `dist/`.)
- [ ] Turn on GitHub Pages from the `docs/` folder, so the site is live at `pavan-not-found.github.io/wink`.
- [ ] Set the repo's social preview image to `docs/assets/og.png` (Settings → Social preview; this one is manual).
- [ ] Add repo topics: `macos`, `menubar`, `swiftui`, `caffeinate`, `sleep`, `productivity`.
- [ ] Optional: publish the Homebrew cask from `packaging/homebrew/wink.rb`.

## 3. The one upgrade that matters most: notarization

Right now macOS shows "Apple could not verify Wink" the first time someone opens the DMG. Developers will right-click and open it. Friends and family often won't. An Apple Developer account ($99 a year) removes the warning completely:

```sh
SIGN_ID="Developer ID Application: Your Name (TEAMID)" scripts/build.sh
scripts/notarize.sh
```

The install command (`curl … | bash`) already avoids the warning, so lead with that until you're notarized.

## 4. Posting schedule

Times are IST. US mornings get the most reach for X and Hacker News.

| When | Where | What |
|---|---|---|
| Day 1, 7:00 pm (8:30 am ET) | X | Launch post with the film, then the four replies over the next hour |
| Day 1, 7:15 pm | LinkedIn | The LinkedIn post with the film |
| Day 1, evening | WhatsApp and DMs | The friends and family message, sent personally to 20 to 30 people |
| Day 1, 9:00 pm | r/macapps | The Reddit post |
| Day 2, 6:30 pm (8:00 am ET) | Hacker News | Show HN, then the first comment straight away. Stay around for two hours to answer |
| Days 3 to 5 | X | One of the three alternative posts each day, with a different image |
| Week 2 | Product Hunt | Once you have early users and, ideally, notarization |

All the copy is in `launch/POSTS.md`. The film is `launch/wink-launch-1080p.mp4`, and stills are in `launch/images/`.

## 5. Tracking downloads

```sh
gh api repos/pavan-not-found/wink/releases --jq '.[].assets[] | "\(.name): \(.download_count)"'
```

Install-script downloads count as `Wink.zip`, and DMG downloads as `Wink.dmg`. Stars and traffic are under the repo's Insights tab.

## 6. Replies for the questions people will ask

**"Is a sudoers rule safe?"** It allows exactly two commands for your user, `pmset -a disablesleep 0` and `pmset -a disablesleep 1`, nothing else, and you can read the file. Settings has a Remove button.

**"Why not Amphetamine?"** Amphetamine is great and does a lot more. Wink does one thing with one gesture, and it's open source.

**"Won't it overheat in a bag?"** It's warmer than sleeping. Wink stops at critical heat and at your battery limit, and for long runs it's best to leave the laptop somewhere with air.

**"Does it work on Intel / older macOS?"** Yes on Intel. It needs macOS 14 Sonoma or later.

**"Why does macOS warn me?"** It isn't notarized yet. Right-click and Open, or use the install command.
