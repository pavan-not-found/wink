# Launch kit

- `POSTS.md`: copy for X, LinkedIn, Hacker News, Reddit, Product Hunt and a note for friends.
- `LAUNCH-PLAN.md`: the order to do things in, and replies to common questions.
- `wink-launch-1080p.mp4`: the 25-second film (1920×1080, with sound). Use it on X, the site and Product Hunt.
- `wink-launch-vertical-1080x1920.mp4`: the same film recomposed for phones. Use it on LinkedIn, Instagram Reels and YouTube Shorts.
- `images/`: stills for posts. `og.png` is the 1280×640 social preview.

## Re-rendering

The film and stills are [HyperFrames](https://github.com/heygen-com/hyperframes) projects. Every popover you see in them is rendered by Wink itself, so they always match the app.

```sh
# 1. Fresh frames from the app (the times in them come from when you run this)
swift build
.build/debug/Wink --render-video launch/film/assets/app
.build/debug/Wink --render docs/assets/raw

# 2. SF Pro isn't redistributable, so copy it in from your Mac (not committed)
for d in film stills; do
  mkdir -p launch/$d/assets/fonts
  cp /Library/Fonts/SF-Pro-Display-{Regular,Medium,Semibold,Bold}.otf launch/$d/assets/fonts/
done

# 3. Sound, then the film
python3 launch/tools/score.py launch/film/assets/audio/score.wav
cd launch/film && npx hyperframes@0.9.58 render --output renders/wink-launch-1080p.mp4

# 4. Stills: snapshot one frame per still
cd ../stills && npx hyperframes@0.9.58 snapshot --at 0.5,1.5,2.5,3.5,4.5
```

If you re-render the app frames, update the clock in `film/index.html` and `stills/index.html` to the time you rendered at, so the menu bar and the popover agree.
