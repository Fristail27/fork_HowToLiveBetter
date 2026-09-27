# HowToLiveBetter translation pipeline
# All commands run from repo root.

PY = .venv/bin/python3
RUFF = .venv/bin/ruff

.PHONY: help sync-upstream digest assemble verify verify-all wave status lint test test-integration ci og update-readme hooks check-commit-msg pages-artifact serve web-build

check-content:  ## CJK-leak, parity, readme-badge checks
	$(PY) tools/check_content.py

ci:  ## Full local CI: test + lint + links + content + build
	@echo "=== Running tests ==="
	$(PY) -m pytest tools/validate/tests/ tools/llm/tests/ -v --ignore=tools/validate/tests/integration
	@echo "=== Integration tests ==="
	$(PY) -m pytest tools/validate/tests/integration/ -v
	@echo "=== Lint ==="
	$(RUFF) check tools/ --select E,F --ignore E501
	@echo "=== Links ==="
	$(PY) tools/check_links.py
	@echo "=== Content ==="
	$(PY) tools/check_content.py
	@echo "=== Build pages ==="
	$(PY) tools/build_pages.py
	@test -f site/en/index.html && test -f site/assets/v2.css

hooks:  ## Install local git hooks (commit-msg style check)
	git config core.hooksPath .githooks
	@echo "✓ core.hooksPath=.githooks (commit-msg enforced)"

check-commit-msg:  ## Validate a message: make check-commit-msg MSG='fix: …'
	@[ -n "$(MSG)" ] || (echo "Usage: make check-commit-msg MSG='type: description'" && exit 1)
	@printf '%s\n' "$(MSG)" | $(PY) tools/check_commit_msg.py --stdin

quality:  ## Content quality gates: readability + bureaucratese (strict)
	@echo "=== Readability ==="
	$(PY) tools/readability.py ru --strict
	@echo "=== Bureaucratese ==="
	$(PY) tools/bureaucratese.py ru --strict

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Upstream sync ──────────────────────────────────────────────

sync-upstream:  ## Fetch upstream CN changes (follow AGENTS.md ritual)
	@echo "→ Follow docs/pipeline/upstream-sync.md"
	git fetch upstream
	git checkout upstream/main -- $$(git ls-tree -r --name-only upstream/main book | grep -E '^book/[0-9]{2}-.*\.md$$')
	git checkout upstream/main -- $$(git ls-tree -r --name-only upstream/main docs | grep -E '^docs/[^/]+\.md$$' ; git ls-tree -r --name-only upstream/main docs/核实记录)
	git show upstream/main:README.md > README.zh.md
	$(PY) tools/strip_zh_readme_ads.py README.zh.md
	$(PY) tools/check_content.py
	@echo "→ Done. Review changes: git diff -- book/ README.zh.md"
	@echo "→ Never checkout ads/, site/, or tools/ from upstream"

# ── Digest ─────────────────────────────────────────────────────

digest:  ## Split CN chapter into units. Usage: make digest CH=01
	@[ -n "$(CH)" ] || (echo "Usage: make digest CH=NN" && exit 1)
	$(PY) tools/make_digest.py $(CH)

# ── Assemble ───────────────────────────────────────────────────

assemble:  ## Assemble translated units into book chapter. Usage: make assemble CH=02 LANG=ru WORKDIR=run/ru/02
	@[ -n "$(CH)" ] || (echo "Usage: make assemble CH=NN LANG=ru|en|es WORKDIR=run/LANG/NN" && exit 1)
	@[ -n "$(LANG)" ] || (echo "Usage: make assemble CH=NN LANG=ru|en|es WORKDIR=..." && exit 1)
	@[ -n "$(WORKDIR)" ] || (echo "Usage: make assemble CH=NN LANG=ru|en|es WORKDIR=..." && exit 1)
	$(PY) tools/assemble.py $(CH) $(WORKDIR) book/$(LANG)/$(shell ls book/$(LANG)/ | grep "^$(CH)-")

# ── Verify ─────────────────────────────────────────────────────

verify:  ## Verify one translated chapter. Usage: make verify CH=01 LANG=ru
	@[ -n "$(CH)" ] || (echo "Usage: make verify CH=NN LANG=ru|en|es" && exit 1)
	@[ -n "$(LANG)" ] || (echo "Usage: make verify CH=NN LANG=ru|en|es" && exit 1)
	$(PY) tools/verify.py $(CH) --lang $(LANG) --json

verify-all:  ## Verify all chapters for a language. Usage: make verify-all LANG=ru
	@[ -n "$(LANG)" ] || (echo "Usage: make verify-all LANG=ru|en|es" && exit 1)
	@for ch in $$(ls book/$(LANG)/ | grep -oE '^[0-9]+' | sort -n | uniq); do \
		echo "=== Chapter $$ch ($(LANG)) ==="; \
		$(PY) tools/verify.py $$ch --lang $(LANG) --json; \
	done

# ── Wave pipeline ───────────────────────────────────────────────

wave:  ## Run assemble+verify for a wave. Usage: make wave WAVE=1
	@[ -n "$(WAVE)" ] || (echo "Usage: make wave WAVE=N" && exit 1)
	@$(PY) -c "import json; w=json.load(open('waves.json')); print('Wave $(WAVE):', w['waves']['$(WAVE)']['chapters'])"
	@$(PY) tools/wave_pipeline.py $$($(PY) -c "import json; print(' '.join(map(str, json.load(open('waves.json'))['waves']['$(WAVE)']['chapters'])))")

# ── Status ─────────────────────────────────────────────────────

status:  ## Show translation dashboard
	$(PY) tools/status.py

# ── Web ────────────────────────────────────────────────────────

web-build:  ## Regenerate site/{lang}/ pages from site/index.html
	$(PY) tools/build_pages.py

og:  ## Regenerate OG PNGs from tools/og/*.html → site/assets/og/
	@mkdir -p site/assets/og
	@for lang in en ru es zh; do \
		"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
			--headless --disable-gpu --hide-scrollbars \
			--force-device-scale-factor=1 --window-size=1200,630 \
			--screenshot=site/assets/og/$$lang.png tools/og/$$lang.html; \
		echo "✓ site/assets/og/$$lang.png"; \
	done

pages-artifact: web-build  ## Stage flat Pages tree in .publish/ (site + book + README*)
	$(PY) tools/pages_artifact.py

serve: pages-artifact  ## Local preview of the Pages artifact on :8000
	@echo "→ http://127.0.0.1:8000/en/"
	cd .publish && $(PY) -m http.server 8000

# ── Quality ────────────────────────────────────────────────────

lint:  ## Lint Python tools
	$(RUFF) check tools/ --select E,F --ignore E501

test:  ## Run unit tests (excludes integration)
	$(PY) -m pytest tools/validate/tests/ tools/llm/tests/ -v --ignore=tools/validate/tests/integration

test-integration:  ## Run integration tests (golden manifests, E2E)
	$(PY) -m pytest tools/validate/tests/integration/ -v

factcheck:  ## Semantic fact-check against CN source. Usage: make factcheck CH=10 LANG=ru
	@[ -n "$(CH)" ] && [ -n "$(LANG)" ] || (echo "Usage: make factcheck CH=NN LANG=ru|en|es" && exit 1)
	$(PY) tools/validate/factcheck.py --chapter $(CH) --lang $(LANG)

style:  ## Style audit (WARN-only). Usage: make style CH=10 LANG=ru
	@[ -n "$(CH)" ] && [ -n "$(LANG)" ] || (echo "Usage: make style CH=NN LANG=ru|en|es" && exit 1)
	$(PY) tools/style_check.py $(CH) $(LANG)

# ── Links ──────────────────────────────────────────────────────

check-links:  ## Validate all relative links in book/ and docs/
	$(PY) tools/check_links.py
