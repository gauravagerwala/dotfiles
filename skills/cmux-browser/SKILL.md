---
name: cmux-browser
description: Use when controlling or inspecting a browser panel in cmux.
compatibility: Requires macOS cmux with the cmux CLI available on PATH and browser automation enabled.
---

# cmux Browser Automation

Use cmux's browser CLI rather than screen-coordinate computer use whenever possible. Prefer accessibility snapshots, semantic locators, CSS selectors, and explicit page-state verification.

## Rules

- Use browser surfaces, never terminal surfaces.
- If no suitable browser exists, open one with `cmux browser open`.
- Snapshot before interacting: `snapshot --interactive --compact`.
- Prefer accessible roles/names, labels, placeholders, and stable selectors.
- Take a fresh snapshot after navigation or major page changes; snapshot refs are not durable.
- Verify URL, title, or expected text after every important action.
- Treat “first result” as literal first visible result unless the user specifies “first organic result”; do not silently skip sponsored results.
- Confirm before purchases, messages, consequential form submissions, uploads, downloads, credential entry, or destructive actions.
- Never bypass CAPTCHA, MFA, access controls, or anti-bot protections.

## Discover or create a browser

The focused cmux surface may be a terminal. In that case `cmux browser identify` fails. First run:

```bash
cmux identify
```

Use a surface only when its `is_browser_surface` value is true. If none exists, open one:

```bash
cmux browser open https://www.google.com --focus true
```

Save the returned `surface:<id>` reference. For a new tab in an existing browser:

```bash
cmux browser --surface <surface> tab new
cmux browser --surface <surface> tab list
```

After opening or switching a tab, run `url`, `get title`, and a fresh snapshot.

## Standard workflow

### Inspect

```bash
cmux browser --surface <surface> snapshot --interactive --compact
cmux browser --surface <surface> get url
cmux browser --surface <surface> get title
```

For pages whose snapshot omits useful content:

```bash
cmux browser --surface <surface> snapshot --interactive --max-depth 10
cmux browser --surface <surface> get text --selector body
```

### Navigate and wait

```bash
cmux browser --surface <surface> goto 'https://example.com' --snapshot-after
cmux browser --surface <surface> wait --load-state complete --timeout 15
```

### Search

For simple web searches, direct search URLs are more reliable than guessing search-form selectors:

```bash
cmux browser --surface <surface> goto 'https://www.google.com/search?q=<url-encoded-query>' --snapshot-after
cmux browser --surface <surface> wait --load-state complete --timeout 15
```

If form interaction is required, inspect first and then use a stable selector:

```bash
cmux browser --surface <surface> fill 'textarea[name="q"]' --text 'query'
cmux browser --surface <surface> press Enter --snapshot-after
```

If Enter does not submit, click the visible search button or use direct URL navigation as a fallback.

### Locate and interact

Use `find` where helpful:

```bash
cmux browser --surface <surface> find role link --name 'Documentation'
cmux browser --surface <surface> find role button --name 'Submit'
cmux browser --surface <surface> find label 'Search'
```

Then act with a selector from the latest snapshot:

```bash
cmux browser --surface <surface> click '<selector>' --snapshot-after
cmux browser --surface <surface> fill '<selector>' --text '<value>'
cmux browser --surface <surface> press Enter --snapshot-after
cmux browser --surface <surface> select --selector '<selector>' --value '<value>'
cmux browser --surface <surface> scroll --dy 600
```

### Verify navigation

```bash
cmux browser --surface <surface> wait --load-state complete --timeout 15
cmux browser --surface <surface> get url
cmux browser --surface <surface> get title
```

If a DOM click does not navigate, check for a dialog or new tab, take a fresh snapshot, and retry once. If the destination URL is known, direct navigation is an acceptable fallback; mention that fallback when relevant.

## Search-result selection

When asked to click a search result:

1. Search and wait for the results page.
2. Inspect the snapshot and/or `get text --selector body`.
3. Resolve visible matching links and their URLs.
4. Identify sponsored versus organic results.
5. Select the literal first visible matching result unless the user specified organic/non-sponsored.
6. Click it and verify navigation.
7. If clicking fails, navigate to the resolved URL and report the fallback if useful.

Do not silently substitute an organic result for a sponsored first result.

## Extraction

Prefer targeted extraction:

```bash
cmux browser --surface <surface> get text --selector 'main'
cmux browser --surface <surface> get text --selector 'article'
cmux browser --surface <surface> get attr --selector 'a.result' --attr href
cmux browser --surface <surface> get count --selector 'a'
```

Use `body` only when targeted selectors are unavailable.

## Dialogs, downloads, and screenshots

```bash
cmux browser --surface <surface> dialog accept
cmux browser --surface <surface> dialog dismiss
cmux browser --surface <surface> screenshot --out /tmp/cmux-browser.png
```

Do not accept dialogs or download files automatically unless requested. Confirm before uploads/downloads involving sensitive data.

Use screenshots and `input mouse` only as a last resort for canvas/custom-rendered controls. Prefer DOM/accessibility automation, then page inspection or `eval`, then visual actions.

## Failure recovery

1. Take a fresh snapshot.
2. Check URL and title.
3. Look for consent banners, login pages, dialogs, loading state, or a new tab.
4. Wait for a selector, text, URL, or load state.
5. Retry with a semantic locator or stable CSS selector.
6. Use `get text` or `eval` for inspection/fallback.
7. Use a screenshot/visual action only when DOM automation cannot work.

Useful waits:

```bash
cmux browser --surface <surface> wait --selector '<selector>' --timeout 15
cmux browser --surface <surface> wait --text 'Expected text' --timeout 15
cmux browser --surface <surface> wait --url-contains 'example.com' --timeout 15
```

Do not loop indefinitely. After two failed strategies, report the blocker and ask for guidance if the action is consequential.

## Reporting

Report briefly:

- What was done
- Resulting URL or title when useful
- Any ambiguity, fallback, or blocked action

Authoritative command details:

```bash
cmux browser --help
cmux docs browser
```
