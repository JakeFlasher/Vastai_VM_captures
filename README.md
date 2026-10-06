# RTX PRO 6000 Workstation SM120 capture workspace

This directory is an independent, disposable-side-effects workspace for the
cloud RTX PRO 6000 Blackwell Workstation Edition. The cloud host is used for
device-specific compilation, correctness smoke, Nsight Compute, and NVBit
capture. The local RTX 3090 Ti is used for simulator development and replay;
no local replay is expected to execute an SM120 binary.

The workspace deliberately keeps collection and replay separate:

```text
cloud host (SM120)                    local host (SM86)
-------------------                   ------------------
source/build -> correctness ->        downloaded capture/
NVBit trace + NCU report  ------->     trace decoder -> sim-run
```

## Target identity

The target is the **NVIDIA RTX PRO 6000 Blackwell Workstation Edition**:

* compute capability `12.0`, deployment token `sm_120`;
* GB202, 188 SMs, 94 TPCs, 12 GPCs, 24,064 CUDA cores;
* 96 GB ECC GDDR7, 512-bit interface, 1,792 GB/s specified bandwidth;
* 48 resident warps/SM, 32 resident blocks/SM, and 128 KiB shared-memory
  capacity per SM are the published CC 12.0 limits.

These are starting inputs, not a measured simulator card. Runtime identity,
driver/toolkit versions, clocks, power state, MIG state, and NCU metric
availability must be collected on the cloud host before interpreting a run.

The repository card is `arch_profiles/cards/sm_120-rtx-pro-6000-ws.json`.
Missing cache geometry, load policy, latency, issue topology, and clock
crosswalk fields remain typed gaps; this workspace never substitutes values
from the RTX 5060 laptop or SM86.

## Layout

```text
config/target.json              vendor facts and collection defaults
config/ncu_metric_sets.json     full-set and optional focused NCU commands
config/workload_catalog.json    generated 235-row SOL + 72-row SimBench map
cloud/                          scripts intended to run on the paid host
local/                          non-destructive import/inventory helpers
captures/                       NVBit output (created on demand)
profiles/                       .ncu-rep/raw CSV output (created on demand)
metadata/                       host/run text metadata (created on demand)
logs/                           command stdout/stderr (created on demand)
```

Generated outputs are intentionally not prerequisites for simulator runs. A
missing or malformed capture is reported as a run failure, not converted into
a synthetic result.

## First cloud session

Run from a checkout of this repository on the cloud VM (or set `REPO_ROOT`):

```bash
export SM120_CAPTURE_ROOT=/home/jakeshea/sm120_rtx_pro_6000_capture
export REPO_ROOT=/path/to/GPU_simulator_rebase

"$SM120_CAPTURE_ROOT/cloud/collect_host_info.sh"
"$SM120_CAPTURE_ROOT/cloud/build_nvbit_sm120.sh"

# Build and correctness-test one bounded workload first.
make -C "$REPO_ROOT/workloads/simbench_bw/l1/fp32_fma_dep_chain" \
  ARCH_GATE=sm_120

"$SM120_CAPTURE_ROOT/cloud/run_nvbit_capture.sh" \
  --name fp32_fma_dep_chain \
  -- "$REPO_ROOT/workloads/simbench_bw/l1/fp32_fma_dep_chain/fp32_fma_dep_chain_run"

"$SM120_CAPTURE_ROOT/cloud/run_ncu_profile.sh" \
  --name fp32_fma_dep_chain \
  -- "$REPO_ROOT/workloads/simbench_bw/l1/fp32_fma_dep_chain/fp32_fma_dep_chain_run"
```

The NCU wrapper requests the `full` section set, saves an `.ncu-rep`, and
exports raw CSV after the run. NCU may require multiple replay passes and may
report metric-specific unavailability; those messages remain in the logs.
"All metrics" therefore means the full set plus the chip's metric query, not
that every metric is guaranteed to be simultaneously measurable.

## Transfer to the local host

Use a non-destructive rsync pull after a cloud session:

```bash
"$SM120_CAPTURE_ROOT/local/pull_from_cloud.sh" \
  user@cloud-host:/home/jakeshea/sm120_rtx_pro_6000_capture/ \
  /home/jakeshea/sm120_rtx_pro_6000_capture/
"$SM120_CAPTURE_ROOT/local/list_runs.sh"
```

Then copy only the required trace directory into the repository's local
results area and use the existing SM86-compatible protobuf/replay readers.
The simulator must be invoked with the Pro 6000 architecture card once that
card has been checked for the requested replay surface; no SM120 trace should
be relabeled as SM86.

## Boundaries

* No clock, power, persistence, compute-mode, or MIG mutation is performed by
  these scripts.
* NCU output is an independent observation. It is not used to select a
  simulator parameter for the same scored workload.
* A trace, report, or inventory file is ordinary run output, not an approval
  or admission gate.
* CUDA/NVBit toolchain versions are recorded as text; the scripts do not
  install host drivers or mutate the VM.

## Research references

* [NVIDIA CUDA GPU compute-capability table](https://developer.nvidia.com/cuda/gpus)
* [NVIDIA RTX PRO 6000 datasheet](https://www.nvidia.com/content/dam/en-zz/Solutions/data-center/rtx-pro-6000-blackwell-workstation-edition/workstation-blackwell-rtx-pro-6000-workstation-edition-nvidia-us-3519208-web.pdf)
* [NVIDIA RTX Blackwell PRO GPU architecture](https://www.nvidia.com/content/dam/en-zz/Solutions/design-visualization/quadro-product-literature/NVIDIA-RTX-Blackwell-PRO-GPU-Architecture-v1.0.pdf)
* [CUDA Blackwell tuning guide](https://docs.nvidia.com/cuda/archive/12.8.0/blackwell-tuning-guide/index.html)
* [Nsight Compute CLI guide](https://docs.nvidia.com/nsight-compute/NsightComputeCli/index.html)

The staged plan and current milestone are in `PLAN.md`; the operator procedure is in `MANUAL.md`.
