# Launch posts

Everything below is ready to paste. Attach the file named next to each post.
Files: `launch/wink-launch-1080p.mp4` (the 25 s film), `launch/images/*.png`.

---

## X (Twitter): the launch post

Attach: `wink-launch-1080p.mp4`

> I kept walking around with my MacBook half open so a recording wouldn't stop.
>
> So I built Wink. Pick how long in the menu bar, close the lid, and your Mac keeps going. When the time is up, it sleeps like normal.
>
> Free and open source: github.com/pavan-parallel/wink

### Replies under it (post as a thread, one at a time)

**Reply 1.** Attach `images/icon-states.png`

> The menu bar icon is the timer. It's an eye under a lid, and the lid comes down as your time runs out. When it shuts, your Mac is back to sleeping normally.

**Reply 2.** No attachment

> How it works: with the lid open, Wink holds the same power assertion as caffeinate. With the lid shut on battery, macOS only listens to pmset disablesleep. Wink asks for your password once and adds a rule that allows exactly that command, on and off, and nothing else.

**Reply 3.** Attach `images/pmset-banner.png`

> I built it after finding out my Mac hadn't slept in days, because of a sudo pmset command I ran once and forgot about. Wink always lets go: at the end of the timer, at 15% battery, if the Mac runs very hot, and even if Wink crashes.

**Reply 4.** No attachment

> If you leave Claude Code or Codex running for long stretches, two hooks keep your Mac awake while the agent works and let it sleep when it's done. The snippet is in the README.

---

## X: three other ways to open (use one later in the week)

1. Product first. Attach `images/hero.png`

> Close your MacBook. Whatever's running keeps running.
>
> Wink is a free Mac app that keeps your laptop awake with the lid shut, for exactly as long as you pick, then lets it sleep.

2. For developers. Attach the film

> My coding agent now keeps working when I close the laptop and walk to a meeting. Wink is free and open source, and it takes two Claude Code hooks to wire up.

3. The forgotten command. Attach `images/pmset-banner.png`

> If you ever ran sudo pmset disablesleep 1, your Mac probably hasn't slept since. I made a menu bar app that does the same job with a timer and always turns sleep back on.

---

## LinkedIn

Attach: the film

> I kept walking between rooms with my MacBook half open, because closing the lid would stop a voice recording or a long task I had running.
>
> The fix most people know is a Terminal command, sudo pmset disablesleep 1. I ran it once and forgot about it. My Mac didn't sleep properly for days.
>
> So I built Wink, a small menu bar app for macOS. You drag a ruler to choose how long, from fifteen minutes to a week, press Keep awake, and close the lid. When the time is up, your Mac goes back to sleeping normally.
>
> Most of the work went into the design. Ten preset buttons became one ruler, with 8 am always on it so overnight is a single drag. The menu bar icon became the timer: an eye whose lid comes down as time runs out.
>
> It's free and open source, and it stops on its own at low battery or if the Mac gets very hot. If you try it, I'd like to hear what's missing.
>
> github.com/pavan-parallel/wink

---

## Hacker News (Show HN)

Title:

> Show HN: Wink, a menu bar timer that keeps a closed MacBook awake

URL: `https://github.com/pavan-parallel/wink`

First comment (post right after submitting):

> I made this because I kept carrying my laptop half open so long jobs wouldn't stop, and because I'd once left sudo pmset disablesleep 1 on and forgotten about it.
>
> How it works: with the lid open it holds a PreventUserIdleSystemSleep assertion, the same as caffeinate. With the lid shut on battery, assertions are ignored, so it toggles pmset disablesleep. That needs root, so the first run installs /etc/sudoers.d/wink, which allows exactly pmset -a disablesleep 0 and pmset -a disablesleep 1 for your user and nothing else. Settings has a button to remove it.
>
> It records when it turned sleep off, so it only ever turns back off what it turned on. A small watcher process restores sleep within two seconds if Wink is killed. It also stops at a battery threshold and on critical thermal state.
>
> It's Swift and SwiftUI, about 1,700 lines, MIT licensed, no network access. It isn't notarized yet, so the DMG needs a right-click and Open the first time. I'd love feedback on the sudoers approach in particular, and on anything that would make you trust it more.

---

## Reddit: r/macapps

Title:

> I made Wink, a free menu bar app that keeps your MacBook running with the lid closed, on a timer (open source)

Body (attach `images/hero.png` and the film):

> I kept carrying my laptop half open between rooms so recordings and long jobs wouldn't stop, so I built this.
>
> You pick a duration on a ruler (15 minutes to a week, or forever, with 8 am always on it), press Keep awake, and close the lid. The menu bar icon is the timer: an eye whose lid comes down as time runs out. When it's done, your Mac sleeps normally again.
>
> A few things I cared about:
>
> It works with the lid closed on battery, which caffeinate can't do. It asks for your password once to allow exactly one pmset command, and the README shows the one-line rule it adds.
>
> It always lets go: when the timer ends, at a battery level you choose, if the Mac gets critically hot, and even if the app crashes.
>
> If you ran sudo pmset disablesleep 1 at some point and forgot, it notices and offers to turn normal sleep back on.
>
> It's free, MIT licensed and makes no network requests. Feedback welcome, especially on the design.
>
> github.com/pavan-parallel/wink

---

## Product Hunt

Name: Wink

Tagline (under 60 characters):

> Close your MacBook. Whatever's running keeps running.

Description:

> Wink is a free, open-source menu bar app that keeps your Mac awake with the lid open or shut, for exactly as long as you choose. Drag a ruler, press Keep awake, close the lid. When the time is up, your Mac sleeps normally again.

Maker's first comment:

> I built Wink after carrying my laptop half open between rooms one too many times. The design started as ten preset buttons and ended as one ruler, with 8 am always on it, because "overnight" is what most people actually want. The menu bar icon is the timer: an eye whose lid comes down as time runs out. It's open source, so you can read exactly what it changes on your system. I'd love to hear what you'd use it for.

Gallery, in order: the film, `hero.png`, `states.png`, `icon-states.png`, `pmset-banner.png`.

---

## A message for friends and family

> Hey! I made a small Mac app called Wink. If you've ever had to keep your laptop open so a download, call recording or upload wouldn't stop, it fixes that: you pick how long, close the lid, and it keeps going. It's free. Would you try it and tell me if anything is confusing?
>
> Install: open Terminal and paste this
> curl -fsSL https://raw.githubusercontent.com/pavan-parallel/wink/main/scripts/install.sh | bash
>
> Or download it here: pavan-parallel.github.io/wink
