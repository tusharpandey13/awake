BINDIR ?= $(HOME)/bin

.PHONY: install uninstall test

# symlink, so a replaced script never overwrites one a running supervisor is still reading
install:
	mkdir -p "$(BINDIR)"
	ln -sfn "$(CURDIR)/awake.sh" "$(BINDIR)/awake"
	@case ":$$PATH:" in *":$(BINDIR):"*) ;; *) echo "note: $(BINDIR) is not on PATH" ;; esac

uninstall:
	@if [ -L "$(BINDIR)/awake" ]; then rm "$(BINDIR)/awake"; else echo "no symlink at $(BINDIR)/awake"; fi

test:
	bash tests/run.sh
