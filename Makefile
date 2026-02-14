.PHONY: install install-all

SKILLS_DIR := ~/.claude/skills
SKILLS := $(wildcard *-skill)
SKILL_FILES := $(wildcard *-skill.md) $(filter-out README.md,$(wildcard *.md))

install:
ifndef SKILL
	@echo "Usage: make install SKILL=<folder-name-or-file>"
	@echo "Example: make install SKILL=go-backend-skill"
	@echo "Example: make install SKILL=commit.md"
	@echo ""
	@echo "Available skills:"
	@ls -d *-skill/ 2>/dev/null | sed 's/\///'
	@ls *.md 2>/dev/null | grep -v README.md
else
	@mkdir -p $(SKILLS_DIR)
	@rm -rf $(SKILLS_DIR)/$(SKILL)
	@cp -r $(SKILL) $(SKILLS_DIR)/
	@echo "Installed $(SKILL) to $(SKILLS_DIR)/$(SKILL)"
endif

install-all:
	@mkdir -p $(SKILLS_DIR)
	@for skill in $(SKILLS); do \
		rm -rf $(SKILLS_DIR)/$$skill; \
		cp -r $$skill $(SKILLS_DIR)/; \
		echo "Installed $$skill to $(SKILLS_DIR)/$$skill"; \
	done
	@for f in $(SKILL_FILES); do \
		cp $$f $(SKILLS_DIR)/; \
		echo "Installed $$f to $(SKILLS_DIR)/$$f"; \
	done
	@echo "All skills installed."
