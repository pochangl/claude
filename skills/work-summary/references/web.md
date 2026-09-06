# Web capture (Playwright)

Use the `mcp__playwright__browser_*` tools. If they are unavailable in the
session, say so and fall back to a one-off `npx playwright` script rather than
skipping the screenshots.

## 1. Serve the working tree

Start the dev server in the background (Bash `run_in_background: true`) and read
the port off its output — do not assume 3000:

```bash
npm run dev        # or pnpm dev / yarn dev / vite / python3 -m http.server
```

Poll until it answers before navigating:

```bash
curl -sf -o /dev/null http://localhost:<port> && echo up
```

A pure static site can be opened with a `file://` URL and no server at all.

## 2. Drive the page

```
browser_resize        1280 x 800 for desktop; 390 x 844 to show a mobile layout
browser_navigate      http://localhost:<port>/<route>
browser_snapshot      read the accessibility tree, then click/type by its refs
browser_click / browser_type / browser_fill_form / browser_select_option
browser_wait_for      wait for text or a state, never a fixed sleep
```

Seed whatever state the change needs to be visible (log in, create the row,
toggle the flag). A screenshot of an empty state proves nothing.

Check `browser_console_messages` before capturing: a page that threw is not a
screenshot of working code.

## 3. Capture

```
browser_take_screenshot  filename: <abs path>/summarize/<slug>/screenshots/01-login.png
                         fullPage: true    for a whole page/document view
                         element + ref     to frame one component
```

Pass an absolute path so the file lands in the summary folder. Prefer PNG.
Rewrite the path as `screenshots/01-login.png` in the manifest.

## 4. Clean up

`browser_close`, and stop the dev server only if you started it.
