# SM120 RTX PRO 6000 capture/replay plan

Updated 2026-10-06. This is a technical execution plan, not a workflow gate.
Each milestone is closed only by the concrete bar in its row; cloud-dependent
rows remain open until the cloud host produces the required observation.

## Milestones

| Phase | Milestone | Completion bar | State |
|---|---|---|---|
| P0 | Repository and hardware review | Read current project memory/status, SM120 cards, SimBench/SOL sources, NVBit/NCU paths, and authoritative Blackwell references; record facts versus gaps | complete |
| P1 | Independent workspace | Create this directory, target/config contracts, capture/replay separation, transfer helpers, and an explicit no-driver-mutation boundary | complete |
| P2 | Pro 6000 identity/card | Add a dedicated `rtx_pro_6000_ws` card and loader/schema/Rust identity support; keep unmeasured fields typed gaps | complete — vendor facts + typed gaps, schema validation, `sim-arch` 77-test suite |
| P3 | Cloud preflight and toolchain | On the RTX PRO 6000, record GPU UUID/CC/driver/CUDA/NVBit/NCU/toolchain; build the tracer and one bounded SM120 executable | pending cloud |
| P4 | First vertical | One workload passes correctness and sanitizer, then the same binary produces an NVBit trace and a full-set NCU report with raw CSV | pending cloud |
| P5 | Mechanism matrix | Capture identity, scalar, memory/cache, tensor/quant, async/TMA, cluster/DSMEM, and vendor controls; retain unsupported or timed-out rows | pending cloud |
| P6 | SOLBench crosswalk | Run a staged SM120 slice of FIB/L1/L2/Quant official rows, then expand only after source/build/correctness evidence; add Pro-only counterparts from SimBench | pending cloud |
| P7 | Local replay and model extension | Download captures, validate wire compatibility, replay on the local host using the Pro card, and add only evidence-supported SM120 model capabilities | pending local + cloud |
| P8 | Broad validation | Evaluate held-out workloads and physical-tail/accuracy frontiers separately; document remaining gaps without claiming full hardware completion | pending local + cloud |

## Stage ordering

1. P2 must finish before any cloud trace is treated as a Pro 6000 trace.
2. P3/P4 are a single small vertical; a failed capture is retained and is
   not replaced by a synthetic trace.
3. P5 is organized by mechanism rather than by a scalar score. NCU timing,
   active cycles, instruction counts, and trace facts remain separate.
4. P6 starts with the 26 FlashInfer/FIB rows, representative L1/L2 rows, and
   all Quant rows. The complete official source census is retained in the
   generated catalog even when a row is not yet buildable.
5. P7 is the first point where the local simulator changes. No cloud NCU
   number is used as a tuning input for that same workload.

## Current next check

Complete P2 with the dedicated card and identity lockstep tests. Then run
`cloud/collect_host_info.sh` on the RTX PRO 6000 before building any larger
matrix.

## P2 closeout checks

The local identity/configuration work was checked before leaving P3 open:

* all three architecture cards pass the JSON schema with the installed
  `jsonschema` environment;
* `cargo test -p sim-arch --lib`: 77 passed;
* `cargo test -p sim-sm --lib`: 496 passed;
* `cargo test -p sim-run --lib`: 66 passed;
* focused Python/schema/NVBit/reference checks: 44 passed / 703 subtests;
* every cloud/local shell script passes `bash -n`;
* the local 3090 Ti run of `cloud/00_check_prereqs.sh` correctly refuses the
  non-Pro target (exit 3), so P3 cannot be accidentally collected on SM86.

These are local software/configuration checks, not SM120 hardware evidence.
