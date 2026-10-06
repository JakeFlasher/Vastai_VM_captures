# RTX PRO 6000 Workstation SM120 capture manual

This is the operator manual for a **cloud-only collection / local-only replay**
workflow. It is intentionally broken into small commands and scripts. Do not
replace the steps with a long campaign script until the single-workload path
has been tested on the newly provisioned cloud image.

## 0. Scope and identity rules

* **Cloud collection target:** NVIDIA RTX PRO 6000 Blackwell Workstation
  Edition, CC `12.0`, deployment token `sm_120`, SKU `rtx_pro_6000_ws`.
* **Local development target:** NVIDIA GeForce RTX 3090 Ti, CC `8.6`.
* The historical RTX 5060 laptop (`rtx_5060_laptop`, `sm_120-laptop`) is not a
  substitute for the current live target. Existing 5060 files are retained as
  historical records and must remain labeled.
* Never run an SM120 binary on the 3090 Ti. Never relabel an SM120 trace as
  SM86. Never copy the 5060 card's cache or clock values into the Pro 6000 card.
* NCU is an independent observation. It is not a parameter-selection source
  for the same workload.

The workspace is `/home/jakeshea/sm120_rtx_pro_6000_capture`. Set these in every
cloud shell:

```bash
export SM120_CAPTURE_ROOT=/home/jakeshea/sm120_rtx_pro_6000_capture
export REPO_ROOT=/path/to/GPU_simulator_rebase
```

## 1. Provision the Ubuntu VM without changing GPU state

The cloud image/operator owns the NVIDIA driver, CUDA toolkit, Nsight Compute,
and GPU permissions. Do **not** install a driver, change persistence, lock
clocks, change power limits, reconfigure MIG, or change compute mode from this
workspace.

From the repository-independent workspace:

```bash
"$SM120_CAPTURE_ROOT/cloud/01_install_user_deps.sh"
```

This prints the package list but does not change the VM. If the VM is disposable
and you explicitly want those user-space packages, run:

```bash
"$SM120_CAPTURE_ROOT/cloud/01_install_user_deps.sh" --apply
```

The package script installs only build/support packages (`build-essential`,
`pkg-config`, protobuf development tools, Python venv/pip, `rsync`, and `jq`).
It does not install CUDA, the driver, PyTorch, NVBit, or Nsight Compute.

## 2. Check the new cloud image before touching the repository

```bash
"$SM120_CAPTURE_ROOT/cloud/00_check_prereqs.sh"
```

Expected identity output includes `RTX PRO 6000`, compute capability `12.0`,
and a usable `nvidia-smi`, `nvcc`, and `ncu`. Stop if the output says RTX 5060,
B200, a MIG slice, or another GPU. Save the terminal output with the session
notes.

## 3. Prepare the checkout and Python environment

```bash
"$SM120_CAPTURE_ROOT/cloud/02_prepare_repo.sh"
```

For official SOLBench execution only, prepare the repository's existing
user-space environment (this may download several GB):

```bash
cd "$REPO_ROOT"
uv sync --project tools/sol_execbench
```

For SimBench micro-probes, the CUDA toolkit plus the C++/protobuf packages are
sufficient. Do not install a second CUDA toolkit over the image's configured
one. Record `nvcc --version`, `ncu --version`, and the driver version in the
host metadata before building.

## 4. Capture host facts and NCU metric availability

```bash
"$SM120_CAPTURE_ROOT/cloud/collect_host_info.sh"
```

This writes a timestamped directory under `metadata/` containing:

* GPU name, UUID, CC, driver, P-state, clocks, power, temperature, and MIG mode;
* `nvidia-smi -q` output;
* `nvcc --version`, `ncu --version`, and available chip names;
* the NCU metric query output;
* the repository revision when `REPO_ROOT` is a Git checkout.

A metric missing from the query is not silently replaced. Keep the NCU warning
and unavailable-metric lines with the run.

## 5. Build the SM120 NVBit producer

The tracer build is separate from workload compilation:

```bash
"$SM120_CAPTURE_ROOT/cloud/build_nvbit_sm120.sh"
```

The script builds both `tracer_tool.so` and the optional metric extractor for
`ARCH=sm_120`. If the pinned local protobuf prefix is unavailable on the cloud
image, either provision the repository's `.toolchain/pb` prefix or pass the
cloud paths explicitly:

```bash
CUDA_INSTALL_PATH=/usr/local/cuda \
PROTOC=/path/to/protoc \
PB_PREFIX=/path/to/protobuf-prefix \
NVCC_CCBIN=/usr/bin/g++ \
"$SM120_CAPTURE_ROOT/cloud/build_nvbit_sm120.sh"
```

A build failure is a toolchain problem. Do not work around it by compiling an
SM86 tracer and injecting it into the Pro 6000 process.

## 6. Select one bounded first workload

Regenerate the source inventory after updating the repository checkout:

```bash
python3 "$SM120_CAPTURE_ROOT/scripts/build_workload_catalog.py" \
  --repo-root "$REPO_ROOT" \
  --out "$SM120_CAPTURE_ROOT/config/workload_catalog.json"
```

Use the generated catalog before selecting a large matrix:

```bash
python3 - <<'PY'
import json
p = json.load(open('/home/jakeshea/sm120_rtx_pro_6000_capture/config/workload_catalog.json'))
print(p['source_census'])
for c in p['campaigns']:
    print(c['id'], c.get('rows', c.get('source_filter')))
PY
```

The recommended first workload is the existing SimBench scalar probe:

```bash
export WDIR="$REPO_ROOT/workloads/simbench_bw/l1/fp32_fma_dep_chain"
export WBIN="$WDIR/fp32_fma_dep_chain_run"
```

Do not begin with FP4/NVFP4, TMA, cluster, or a 200+ workload fan-out. Those
are later mechanism rows and may require a separate `sm_120f` or `sm_120a`
compile target.

## 7. Build one workload for the baseline SM120 target

```bash
"$SM120_CAPTURE_ROOT/cloud/03_build_workload.sh" \
  --dir "$WDIR" --arch-gate sm_120
```

For an explicitly selected feature probe, use a separate output/build
invocation and record why the feature is being tested:

```bash
"$SM120_CAPTURE_ROOT/cloud/03_build_workload.sh" \
  --dir "$WDIR" --arch-gate sm_120f
```

Do not assume that a successful `sm_120` build proves `sm_120f`/`sm_120a`
feature availability, or that a feature-specific compile proves runtime
support. Keep feature rows separate in the catalog.

## 8. Run correctness, then Compute Sanitizer

Run the ordinary workload first:

```bash
"$SM120_CAPTURE_ROOT/cloud/04_run_correctness.sh" \
  --name fp32_fma_dep_chain -- "$WBIN"
```

Then run a bounded memcheck:

```bash
"$SM120_CAPTURE_ROOT/cloud/05_run_memcheck.sh" \
  --name fp32_fma_dep_chain -- "$WBIN"
```

The scripts record the exact command, stdout, stderr, and exit code. A clean
process exit without the expected correctness output is not a correctness
result. A memcheck failure stops this workload from entering the trace/NCU
matrix until the source issue is understood.

## 9. Save static binary/SASS facts

```bash
"$SM120_CAPTURE_ROOT/cloud/06_dump_sass.sh" \
  --binary "$WBIN" \
  --out "$SM120_CAPTURE_ROOT/metadata/sass_fp32_fma_dep_chain"
```

Inspect the output for the actual embedded code targets. Keep static SASS
separate from dynamic NVBit instruction counts; they answer different questions.

## 10. Capture the dynamic NVBit trace

```bash
"$SM120_CAPTURE_ROOT/cloud/run_nvbit_capture.sh" \
  --name fp32_fma_dep_chain \
  -- "$WBIN"
```

A successful capture should contain `dynamic_trace.pb`, `stats.csv`, enhanced
launch metadata, allocation metadata, and the tracer sidecars. Inspect without
modifying it:

```bash
TRACE_DIR=$(find "$SM120_CAPTURE_ROOT/captures/fp32_fma_dep_chain" \
  -type f -name dynamic_trace.pb -printf '%h\n' | sort | tail -n 1)
"$REPO_ROOT/tools/nvbit_tracer/tracer_tool/trace_printer" "$TRACE_DIR"
```

If `dynamic_trace.pb` is absent, keep the failed directory and logs. Do not
manufacture a replay input from `stats.csv` alone.

The tracer uses the repository protobuf runtime when present. If the process
fails to load the protobuf libraries, retry only after setting:

```bash
export LD_LIBRARY_PATH="$REPO_ROOT/.toolchain/pb/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

## 11. Profile the same binary with Nsight Compute

Run NCU separately from NVBit; do not combine the two injectors in one process:

```bash
"$SM120_CAPTURE_ROOT/cloud/run_ncu_profile.sh" \
  --name fp32_fma_dep_chain -- "$WBIN"
```

The wrapper requests `--set full`, `--target-processes all`,
`--profile-from-start on`, `--launch-skip 0`, and one matching launch by
default. It writes:

```text
profiles/fp32_fma_dep_chain/<timestamp>/
  command.txt
  ncu-report.ncu-rep
  ncu.stdout
  ncu.stderr
  raw.csv
  raw_export.stderr
  exit_code.txt
```

For a multi-kernel application, add an exact filter and/or launch count:

```bash
"$SM120_CAPTURE_ROOT/cloud/run_ncu_profile.sh" \
  --name solbench_problem_001 \
  --kernel-name 'regex:.*rmsnorm.*' \
  --launch-count 1 -- /path/to/application --args
```

NCU may replay a kernel many times internally to collect the full set. A
nonzero NCU exit, a metric-unavailable warning, or a timeout remains part of
the result; do not report it as a complete profile.

## 12. Repeat only after the first vertical is understood

For a chosen workload, the minimum useful vertical is:

1. same binary correctness;
2. same binary Compute Sanitizer;
3. same binary NVBit capture;
4. same binary NCU full-set report/raw CSV;
5. static SASS and command metadata.

Repeat NCU only after the first report has the intended kernel and launch. Use
five repetitions for a timing observation when the cloud budget permits, but
keep raw reports for every repetition. Do not fit simulator parameters during
this collection stage.

## 13. Expand the mechanism matrix in bounded groups

Use `config/workload_catalog.json` and move one campaign group at a time:

* `sm120_identity_and_scalar`: scalar FMA, divergence, register/local memory;
* `sm120_memory_and_cache`: scalar/vector copies, shared banks, L2 working set,
  prefetch/persisting controls, DRAM streams;
* `sm120_tensor_and_quant`: FP16/BF16/TF32/INT8 first, then FP8 and explicit
  FP4/FP6/NVFP4 feature probes;
* `sm120_async_cluster`: `cp.async`, TMA, DSMEM, cluster reductions;
* `sm120_solbench_fib`: all 26 FlashInfer/FIB definitions, source/build first;
* representative L1/L2 rows, then full category expansion;
* all 33 Quant definitions, retaining FP8/NVFP4 build and runtime dispositions.

The 16 `pro6000_specialized_counterparts` rows in the catalog are not claimed
SOLBench replacements. They are targeted SM120 controls for feature behavior
that the official SOLBench source population does not isolate cleanly.

## 14. Transfer captures to the local 3090 Ti

From the local host, pull without deleting local files:

```bash
"$SM120_CAPTURE_ROOT/local/pull_from_cloud.sh" \
  user@cloud-host:/home/jakeshea/sm120_rtx_pro_6000_capture/ \
  /home/jakeshea/sm120_rtx_pro_6000_capture/
"$SM120_CAPTURE_ROOT/local/02_check_import.sh"
"$SM120_CAPTURE_ROOT/local/list_runs.sh"
```

If the transfer is interrupted, rerun the same command. The pull script does
not use `--delete`. Keep the cloud directory until the local inventory has
been inspected.

## 15. Decode and replay locally

On the local repository host:

```bash
cd "$REPO_ROOT"
source tools/nvbit_tracer/pinned_build_env.sh
TRACE_DIR=/path/to/downloaded/captures/<name>/<timestamp>

tools/nvbit_tracer/tracer_tool/trace_printer "$TRACE_DIR"
```

Replay is intentionally a separate step. The current `sim-run` path accepts an
architecture card and mode explicitly; use the Pro card only after the trace
reader has a compatible SM120 control/wire path:

```bash
./sim/target/release/sim-run \
  --trace "$TRACE_DIR" \
  --control /path/to/control-sidecar.json \
  --arch-card arch_profiles/cards/sm_120-rtx-pro-6000-ws.json \
  --mode flat
```

A typed unsupported-control or typed research-gap error is useful evidence at
this stage. It is not permission to substitute the SM86 card. Only after a
trace/replay seam is supported should a narrow SM120 simulator change be made.

## 16. Troubleshooting map

| Symptom | First check | Correct response |
|---|---|---|
| Wrong GPU name/CC | `00_check_prereqs.sh` and host metadata | Stop; do not relabel the run |
| `nvcc` rejects `sm_120f/a` | toolkit version and feature row | Use baseline `sm_120` or record a feature compile blocker |
| NVBit cannot load protobuf | `LD_LIBRARY_PATH` and `.toolchain/pb/lib` | Fix runtime library path; retain the failed log |
| no `dynamic_trace.pb` | capture stderr, timeout, launch filter | Keep as capture failure; do not synthesize a trace |
| NCU metric unavailable | `metadata/ncu-metrics.txt`, `ncu.stderr` | Keep typed unavailable metrics; use a focused section only if justified |
| NCU timeout | launch filter/count and workload size | Reduce one bounded launch; do not call the partial report complete |
| memcheck error | `logs/<name>/memcheck_*` | Fix or exclude the source row before profiling |
| Pro card has no L2/L1 model field | `arch_profiles/cards/sm_120-rtx-pro-6000-ws.json` | Preserve typed gap; wait for a live probe |
| local replay rejects SM120 | simulator control/card support | Add the smallest evidence-supported seam; never fall back to SM86 facts |

## 17. End-of-session checklist

```bash
"$SM120_CAPTURE_ROOT/local/list_runs.sh" > "$SM120_CAPTURE_ROOT/logs/session_inventory.txt"
find "$SM120_CAPTURE_ROOT/captures" -name dynamic_trace.pb -print
find "$SM120_CAPTURE_ROOT/profiles" -name '*.ncu-rep' -print
find "$SM120_CAPTURE_ROOT/metadata" -type f -maxdepth 2 -print
```

Update `PLAN.md` by marking only the phase whose concrete bar passed. Record
failed builds, timeouts, missing metrics, and unsupported feature rows in the
next phase's notes. Do not turn a clean checklist into a broad SM120 accuracy,
scheduling, or physical-completion claim.
