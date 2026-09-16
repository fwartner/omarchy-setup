.PHONY: lint test apply diff update verify sync

lint:            ## shellcheck + syntax + exec bits
	@bad=$$(git ls-files -s bootstrap.sh 'scripts/*.sh' 'scripts/mac/*.sh' 'tests/*.sh' | awk '$$1 != "100755" { print $$1, $$4 }'); \
	  if [ -n "$$bad" ]; then echo "not executable in the index:"; echo "$$bad"; exit 1; fi
	@for f in bootstrap.sh scripts/*.sh scripts/mac/*.sh tests/*.sh home/dot_config/omarchy/hooks/post-update.d/*.sh home/dot_bashrc.d/*.sh; do bash -n $$f; done
	@shellcheck -S warning bootstrap.sh scripts/*.sh scripts/mac/*.sh tests/*.sh home/dot_config/omarchy/hooks/post-update.d/*.sh home/dot_bashrc.d/*.sh

test:            ## run the script self-checks
	@./tests/repo-sync-test.sh
	@./tests/bashrc-test.sh
	@./tests/skills-test.sh
	@./tests/bootstrap-mode-test.sh
	@./tests/self-update-test.sh
	@# `cmd && test || echo skipped` reported a FAILING lua test as "skipped (no
	@# lua)" and exited 0. That is how a bindings.lua calling a helper Omarchy 4.x
	@# does not have reached a laptop. If lua is here, the test must be able to fail.
	@if command -v luac >/dev/null 2>&1; then luac -p home/dot_config/hypr/bindings.lua && echo 'bindings.lua: valid Lua'; else echo 'luac: skipped (no lua)'; fi
	@if command -v lua >/dev/null 2>&1; then lua tests/bindings-test.lua; else echo 'bindings-test: skipped (no lua)'; fi

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

