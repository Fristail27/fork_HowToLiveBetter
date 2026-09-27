# Add a chapter

When a new CN chapter appears (via upstream sync) or a chapter needs translation into a new language, follow this checklist.

## Prerequisites

- Upstream CN chapter exists at `book/NN-*.md`
- `tools/langs.json` has the target language registered
- `waves.json` includes this chapter in a wave

## Steps

### 1. Digest

Split the CN chapter into translatable units:

```bash
make digest CH=NN
```

This creates `tools/digest/NN/units/` with per-item `.md` files and a `blocks.json` with byte-faithful blocks (tags + sources).

### 2. Translate

Translate each unit in `tools/digest/NN/units/`:

```
tools/digest/NN/units/00.md  → head (chapter intro)
tools/digest/NN/units/01.md  → first item (replace §TAG§/§SRC§ placeholders)
tools/digest/NN/units/02.md  → second item
...
```

Translation conventions: [TRANSLATION.md](../../TRANSLATION.md). Per-language style rules: `tools/rules/{lang}.json`.

Store translated units under `run/{lang}/NN/units/`.

### 3. Assemble

Rebuild the translated chapter from units + byte-faithful blocks:

```bash
make assemble CH=NN LANG=ru WORKDIR=run/ru/NN
```

Output: `book/{lang}/NN-*.md` — the assembled chapter in target language format.

### 4. Verify

Run integrity checks against the CN original:

```bash
make verify CH=NN LANG=ru
```

Checks: heading count, tag count, source line byte-identity, CJK leakage, banned calques.

### 5. Status

Update `translations.json` — mark the chapter as `done` for this language.

```bash
make status
```

### 6. Build pages

Regenerate per-language HTML:

```bash
make web-build
```

### 7. README and OG preview

Audit README chapter lists and OG preview images:

```bash
python3 tools/update_readme.py
```

If README chapter counts are wrong, regenerate:

```bash
python3 tools/update_readme.py --fix
```

OG previews: regenerate `og-{lang}.png` from `tools/og-{lang}.html` when chapter count changes:

```bash
# Example: open tools/og-en.html in browser, screenshot → og-en.png
# Future: automated via headless browser
```

### 8. Quality gates

```bash
make ci          # tests + lint + links + content + build
make quality     # readability + bureaucratese (informational)
```

### 9. Commit

```bash
git checkout -b translation/NN-{lang}
git add book/{lang}/ translations.json
git commit -m "translation({lang}): chapter NN — {title}"
```

## Do not

- Edit CN source files (`book/NN-*.md`) — they come from upstream
- Skip verify step — broken chapters block CI
- Forget to update `translations.json` — it's the single source of truth for pipeline status
- Overwrite root `README.md` with CN content — use `README.zh.md`