.PHONY: lint apply diff update verify

lint:            ## shellcheck + syntax
	@for f in bootstrap.sh scripts/*.sh home/dot_config/omarchy/hooks/post-update.d/*.sh home/dot_bashrc.d/*.sh; do bash -n $$f; done
	@shellcheck -S warning bootstrap.sh scripts/*.sh home/dot_config/omarchy/hooks/post-update.d/*.sh home/dot_bashrc.d/*.sh

apply:           ## chezmoi apply from this checkout
	chezmoi apply --source $(CURDIR)/home

diff:            ## what chezmoi would change
	chezmoi diff --source $(CURDIR)/home

update:          ## git pull + apply (what the post-update hook does)
	git pull --ff-only && $(MAKE) apply

verify:          ## post-install checks
	./scripts/verify.sh

