.PHONY: install

SKILLS_DIR := ~/.claude/skills

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
