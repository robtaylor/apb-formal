# apb-formal — proof harness.
# Toolchain: Yosys + SymbiYosys + an SMT solver (ADR 0001). `nix develop` or `brew install yosys`.

SBY ?= sby

.PHONY: all prove cover negtest splitter splitter-cover clean

all: prove cover negtest splitter splitter-cover

## Prove the golden Completer is protocol-compliant (k-induction).
prove:
	$(SBY) -f formal/completer.sby prove

## Prove every protocol scenario (C1-C6) is reachable (cover).
cover:
	$(SBY) -f formal/completer.sby cover

## Negative test: the checker must catch the injected non-compliance (sby `expect fail`).
negtest:
	$(SBY) -f formal/negtest.sby

## Real-RTL: prove libfpga apb_splitter compliant (multi-interface harness).
splitter:
	$(SBY) -f formal/splitter.sby prove

## Real-RTL: cover the apb_splitter scenarios.
splitter-cover:
	$(SBY) -f formal/splitter.sby cover

clean:
	rm -rf formal/completer_prove formal/completer_cover formal/completer \
	       formal/splitter_prove formal/splitter_cover formal/splitter \
	       formal/negtest formal/negtest_pslverr formal/negtest_stall
