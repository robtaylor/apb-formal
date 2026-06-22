# apb-formal — proof harness.
# Toolchain: Yosys + SymbiYosys + an SMT solver (ADR 0001). `nix develop` or `brew install yosys`.

SBY ?= sby

.PHONY: all prove cover clean

all: prove cover

## Prove the golden Completer is protocol-compliant (k-induction).
prove:
	$(SBY) -f formal/completer.sby prove

## Prove every protocol scenario (C1-C6) is reachable (cover).
cover:
	$(SBY) -f formal/completer.sby cover

clean:
	rm -rf formal/completer_prove formal/completer_cover
