.PHONY: lint test apply diff update verify sync

lint:            ## shellcheck + syntax
	@for f in bootstrap.sh scripts/*.sh scripts/mac/*.sh tests/*.sh home/dot_config/omarchy/hooks/post-update.d/*.sh home/dot_bashrc.d/*.sh; do bash -n $$f; done
	@shellcheck -S warning bootstrap.sh scripts/*.sh scripts/mac/*.sh tests/*.sh home/dot_config/omarchy/hooks/post-update.d/*.sh home/dot_bashrc.d/*.sh

test:            ## run the script self-checks
	@./tests/repo-sync-test.sh
	@./tests/bashrc-test.sh
	@./tests/skills-test.sh
	@./tests/bootstrap-mode-test.sh
	@command -v luac >/dev/null 2>&1 && luac -p home/dot_config/hypr/bindings.lua && echo 'bindings.lua: valid Lua' || true
	@command -v lua >/dev/null 2>&1 && lua tests/bindings-test.lua || echo 'bindings-test: skipped (no lua)'

sync:            ## clone/refresh every repo in packages/repos.txt
	@./scripts/repo-sync.sh

apply:           ## chezmoi apply from this checkout
	chezmoi apply --source $(CURDIR)/home

diff:            ## what chezmoi would change
	chezmoi diff --source $(CURDIR)/home

update:          ## git pull + apply (what the post-update hook does)
	git pull --ff-only && $(MAKE) apply

verify:          ## post-install checks
	./scripts/verify.sh

