---
name: meta-event-setup
description: Make landing-page buttons work with Meta's Event Setup Tool (事件設定工具) so Pixel events can be set up without code. Triggers on "pixel 事件", "設定事件", "事件設定工具", "Event Setup Tool", "按鈕無法設定 pixel", "Track a new button 灰色", "not compatible with this page", or when adding/changing clickable buttons on a page that loads the Meta Pixel.
---

# Meta Event Setup Tool — button rules

The Event Setup Tool lets the user attach Pixel events (Lead, 購買…) to buttons from Events Manager, with no code. These rules keep a page's buttons selectable by the tool. Apply them whenever you add or change a clickable button on a page that loads the Meta Pixel.

Source: [Troubleshoot the event setup tool for web](https://www.facebook.com/business/help/1208535569271747?id=1205376682832142). Rules marked *(Meta)* come from that article; rules marked *(experience)* are what made a page work in practice but are not stated by Meta.

## 1. A button is a real HTML link or button *(Meta)*

Use `<a href>` or `<button>`, with a meaningful class or ID. Not a `<div onclick>`, and not inside an iframe — buttons in an iframe cannot be set up at all.

## 2. Height between 10 and 600 px *(Meta)*

A whole image card wrapped in one `<a>` can exceed 600 px or be ambiguous. Make only the actual call-to-action clickable:

- **Correct:** `<div class="plan"><img …><a class="apply" href="…"><img …></a></div>`
- **Incorrect:** `<a class="plan" href="…"><img plan…><img button…></a>`

## 3. The button carries text *(Meta says "text or images"; text is what worked)*

The tool labels and matches buttons by their text (`Button text is: "我要申請"`). Image-only buttons were not detected in practice. Give every image button hidden text, and empty the image `alt` so it isn't read twice:

```html
<a class="apply" href="…"><span class="sr-only">我要申請</span><img src="apply-now.webp" alt=""></a>
```

```css
.sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}
```

Reuse an existing `.sr-only` on the page if there is one. Do not use `aria-label` instead — it is not button text.

## 4. Delayed reveal and animation *(unverified guess)*

- A delayed reveal is fine to keep, and is not shown to block detection: a dialog button revealed after 8s was still detected once it had text. Hide it with `visibility:hidden` rather than `opacity:0`, so nothing invisible sits over the page. When setting up the event, tell the user to wait until the button appears before clicking **Track a new button**.
- A looping animation (float, bounce) moves the button while the user clicks it in the tool. Pause it on hover: `.btn:hover{animation-play-state:paused}`.

## 5. Don't also fire the event in code *(Meta)*

If a standard event is already sent in code (e.g. a click listener calling `fbq('track','Lead')`), the tool warns about duplicates and the same click is counted twice. Pick one method per page; when the user wants the tool, remove the code-based event. The base Pixel code (`fbq('init')` + `fbq('track','PageView')`) stays — the tool needs the Pixel to load.

## 6. Behaviour to tell the user

- One button's event applies to **all buttons with the same text** site-wide — four "我要申請" buttons need one setup.
- Changing a button's text later breaks its event; it must be set up again in the tool.
- Gray **Track a new button** means: no detectable buttons, every detected button already has an event, or buttons in an iframe *(Meta)*. The "not compatible with this page / 未偵測到任何按鈕或網址" warning accompanies this; existing events still work.
- The tool needs the deployed URL, not a local file.
- If a button still can't be selected, fall back to **Track URL** — but when every button links to the same external URL (e.g. one LINE link), URL tracking cannot tell them apart.
- After setup, verify with Events Manager → **測試事件 (Test events)**.
