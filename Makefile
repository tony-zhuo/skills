.PHONY: install install-all

SKILLS_DIR := ~/.claude/skills
SKILLS := $(wildcard *-skill)

install:
ifndef SKILL
	@echo "Usage: make install SKILL=<folder-name>"
	@echo "Example: make install SKILL=go-backend-skill"
	@echo ""
	@echo "Available skills:"
	@ls -d *-skill/ 2>/dev/null | sed 's/\///'
else
	@mkdir -p $(SKILLS_DIR)
	@cp -r $(SKILL) $(SKILLS_DIR)/
	@echo "Installed $(SKILL) to $(SKILLS_DIR)/$(SKILL)"
endif

install-all:
	@mkdir -p $(SKILLS_DIR)
	@for skill in $(SKILLS); do \
		cp -r $$skill $(SKILLS_DIR)/; \
		echo "Installed $$skill to $(SKILLS_DIR)/$$skill"; \
	done
	@echo "All skills installed."
