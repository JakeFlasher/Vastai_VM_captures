#!/usr/bin/env python3
"""Build the SM120 cloud campaign catalog from the repository source trees.

This is an inventory generator, not an execution gate. It records the complete
official SOL-ExecBench population and the existing SimBench mechanism rows so
cloud runs can be staged without pretending that every source is buildable or
that every feature is available on the workstation.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path
from typing import Any


def source_class(solution: dict[str, Any], root: Path) -> str:
    languages = solution.get("spec", {}).get("languages", [])
    if "cutlass" in languages:
        return "cutlass"
    cu_text = "\n".join(
        str(item.get("content", ""))
        for item in solution.get("sources", [])
        if str(item.get("path", "")).endswith((".cu", ".cuh", ".cpp", ".h"))
    )
    if not cu_text:
        return "unknown"
    if re.search(r"__global__|__device__|cuda[A-Za-z]+|<cuda", cu_text):
        return "custom_cuda"
    return "pure_aten_or_host_stub"


def official_inventory(repo: Path) -> list[dict[str, Any]]:
    benchmark = repo / "tools/sol_execbench/data/benchmark"
    baseline_root = repo / "workloads/sol_execbench_baselines"
    rows: list[dict[str, Any]] = []
    for category_dir in sorted(p for p in benchmark.iterdir() if p.is_dir()):
        category = category_dir.name
        for problem in sorted(p for p in category_dir.iterdir() if p.is_dir()):
            definition = json.loads((problem / "definition.json").read_text())
            workloads = [
                json.loads(line)
                for line in (problem / "workload.jsonl").read_text().splitlines()
                if line.strip()
            ]
            baseline_dirs = sorted(
                baseline_root.glob(f"*/{problem.name}/*/solution.json")
            )
            baseline_records = []
            for solution_path in baseline_dirs:
                solution = json.loads(solution_path.read_text())
                source_files = [
                    str(solution_path.parent / item.get("path", ""))
                    for item in solution.get("sources", [])
                ]
                marker_text = "\n".join(
                    Path(path).read_text(errors="replace")
                    for path in source_files
                    if Path(path).is_file()
                )
                baseline_records.append(
                    {
                        "path": str(solution_path.parent.relative_to(repo)),
                        "languages": solution.get("spec", {}).get("languages", []),
                        "source_class": source_class(solution, repo),
                        "sm86_marker": "sm_86" in marker_text or "sm_86" in solution_path.read_text(),
                    }
                )
            rows.append(
                {
                    "category": category,
                    "slug": problem.name,
                    "description": definition.get("description", ""),
                    "workload_count": len(workloads),
                    "axis_keys": sorted(
                        {key for row in workloads for key in row.get("axes", {})}
                    ),
                    "baseline_present": bool(baseline_records),
                    "baseline_variants": baseline_records,
                    "sm120_action": "source_review_then_build_correctness_trace_ncu",
                }
            )
    return rows


def simbench_inventory(repo: Path) -> list[dict[str, Any]]:
    suite = repo / "workloads/simbench_bw"
    roster = tomllib.loads((suite / "roster.toml").read_text())
    matrix = tomllib.loads((suite / "platform_matrix.toml").read_text())
    platform_by_slug = {row["slug"]: row for row in matrix.get("rows", [])}
    rows = []
    for row in roster.get("rows", []):
        slug = row["slug"]
        platform = platform_by_slug.get(slug, {})
        rows.append(
            {
                "slug": slug,
                "level": row.get("level"),
                "domain": row.get("domain"),
                "family": row.get("family"),
                "precision": row.get("primary_precision"),
                "arch_gate": row.get("arch_gate", []),
                "platforms": platform.get("platforms", "unlisted"),
                "reason": platform.get("reason", ""),
                "pro6000_role": (
                    "control_or_cross_arch"
                    if platform.get("platforms") in {"both", "either"}
                    else "pro6000_specialized"
                    if platform.get("platforms") == "rtx_pro_6000_blackwell"
                    else "not_targeted"
                ),
            }
        )
    return rows


PRO_SPECIALIZED = [
    "fp8_e4m3_qmma_dep_chain",
    "fp8_e5m2_saturation",
    "fp6_e3m2_mma_dep_chain",
    "fp6_e2m3_saturation",
    "fp4_e2m1_mma_dep_chain",
    "nvfp4_blockscale_gemm",
    "sparse_2to4_fp8_gemm",
    "tma_tensor_copy_2d",
    "dsmem_pairwise_latency",
    "dsmem_ring_bandwidth",
    "cluster_remote_reduction",
    "cluster_rmsnorm_dsmem_bf16",
    "l2_persisting_window_sweep",
    "l2_prefetch_hint_sweep",
    "carveout_sensitivity_probe",
    "vendor_fp8_matmul_cublaslt",
]

CAMPAIGNS = [
    {
        "id": "sm120_identity_and_scalar",
        "purpose": "identity, launch envelope, and basic scalar issue",
        "rows": ["fp32_fma_dep_chain", "warp_divergence_reconvergence", "register_spill_local_mem"],
    },
    {
        "id": "sm120_memory_and_cache",
        "purpose": "global/shared/L2/DRAM mechanism controls",
        "rows": [
            "global_scalar_32b_copy", "global_vectorized_64b_copy", "global_vectorized_128b_copy",
            "shared_bank_conflict_stride", "l2_thrash_pointer_chase", "working_set_capacity_sweep",
            "l2_prefetch_hint_sweep", "l2_persisting_window_sweep", "dram_stream_stride_mix",
            "dram_streaming_dot_product",
        ],
    },
    {
        "id": "sm120_tensor_and_quant",
        "purpose": "safe tensor paths first, then explicitly gated FP8/FP6/FP4/NVFP4 probes",
        "rows": [
            "bf16_hmma_gemm_traceable", "fp16_hmma_gemm_traceable", "tf32_hmma_gemm_traceable",
            "int8_imma_gemm_traceable", "sparse_2to4_bf16_gemm", "sparse_2to4_int8_gemm",
            *PRO_SPECIALIZED[:7],
        ],
    },
    {
        "id": "sm120_async_cluster",
        "purpose": "cp.async/TMA, cluster, DSMEM, and synchronization boundaries",
        "rows": [
            "cp_async_shared_tile_copy", "tma_tensor_copy_2d", "dsmem_pairwise_latency",
            "dsmem_ring_bandwidth", "cluster_remote_reduction", "cluster_rmsnorm_dsmem_bf16",
        ],
    },
    {
        "id": "sm120_solbench_fib",
        "purpose": "all 26 FlashInfer/FIB source families, staged by source/build/correctness",
        "source_filter": {"category": "FlashInfer-Bench"},
    },
    {
        "id": "sm120_solbench_l1_representative",
        "purpose": "representative custom, CUTLASS, memory, attention, MoE, and vision rows before full L1 expansion",
        "source_filter": {"category": "L1", "count": 16},
    },
    {
        "id": "sm120_solbench_l2_representative",
        "purpose": "representative fused transformer, MoE, Mamba, diffusion, and vision rows before full L2 expansion",
        "source_filter": {"category": "L2", "count": 16},
    },
    {
        "id": "sm120_solbench_quant_all",
        "purpose": "all 33 Quant rows; FP8 and NVFP4 rows retain separate feature/build dispositions",
        "source_filter": {"category": "Quant"},
    },
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    repo = args.repo_root.resolve()
    official = official_inventory(repo)
    simbench = simbench_inventory(repo)
    counts: dict[str, int] = {}
    for row in official:
        counts[row["category"]] = counts.get(row["category"], 0) + 1
    payload = {
        "schema_version": 1,
        "target": {
            "arch_id": "sm_120",
            "sku": "rtx_pro_6000_ws",
            "device": "NVIDIA RTX PRO 6000 Blackwell Workstation Edition",
        },
        "source_census": {
            "official_solbench_total": len(official),
            "official_solbench_by_category": counts,
            "simbench_mechanism_rows": len(simbench),
            "note": "Inventory only; source presence is not execution evidence.",
        },
        "campaigns": CAMPAIGNS,
        "pro6000_specialized_counterparts": [
            {
                "slug": slug,
                "why": "SM120 feature/control counterpart not represented by a single official SOLBench row.",
                "status": "source_and_live_probe_required",
            }
            for slug in PRO_SPECIALIZED
        ],
        "official_solbench": official,
        "simbench_rows": simbench,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"wrote {len(official)} SOL rows and {len(simbench)} SimBench rows to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
