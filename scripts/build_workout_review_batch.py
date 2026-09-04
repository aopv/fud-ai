#!/usr/bin/env python3
"""Build a human review batch from Codex visual audit reports."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "artifacts/workout-visual-qa/review-batches/audit-source"
VECTORS = ROOT / "shared/workout-vectors"

TAG_RULES: list[tuple[str, re.Pattern[str]]] = [
    ("background", re.compile(r"white|checkerboard|opaque|background|floor residue|pale|transparent|alpha|gray ground|near-white", re.I)),
    ("framing", re.compile(r"drift|shift|scale|anchor|framing|enlarge|jump|padding|position vary|geometry change", re.I)),
    ("clipping", re.compile(r"detached|fragment|cut off|truncat|clipped|crop|multi-pose|stacked", re.I)),
    ("anatomy", re.compile(r"wrong|misdepict|anatomy|stump|missing head|three hand|not demonstrate|broken|misrepresent|forked|disconnected bar", re.I)),
    ("padding", re.compile(r"tight padding|canvas boundary|bottom padding|top padding|insufficient.*padding", re.I)),
]

ANATOMY_RE = re.compile(r"wrong|misdepict|anatomy|stump|missing head|three hand|not demonstrate|broken limb|misrepresent|forked|disconnected", re.I)
CLIP_RE = re.compile(r"detached|fragment|multi-pose|stacked clipped|three hand", re.I)


def frame_paths(exercise_id: str) -> list[str]:
    names = [f"{exercise_id}_{gender}_v2_{i}.png" for gender in ("male", "female") for i in range(4)]
    return [str((VECTORS / name).resolve()) for name in names]


def tag_findings(findings: list[str]) -> list[str]:
    blob = " ".join(findings)
    tags = [name for name, pattern in TAG_RULES if pattern.search(blob)]
    return tags or ["other"]


def suggest_route(severity: str, tags: list[str], findings: list[str]) -> str:
    blob = " ".join(findings)
    if severity == "critical" and (ANATOMY_RE.search(blob) or CLIP_RE.search(blob)):
        return "redraw"
    if "background" in tags or "framing" in tags or "padding" in tags:
        if severity == "critical" and ("anatomy" in tags or "clipping" in tags):
            return "redraw"
        return "script_fix"
    if severity == "major" and ("background" in tags or "framing" in tags):
        return "script_fix"
    if severity == "clean":
        return "skip"
    return "defer"


def parse_audit_md(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8")
    rows: list[dict] = []
    for section, group in (("Critical", "critical"), ("Major", "major"), ("Minor", "minor"), ("Clean", "clean")):
        match = re.search(
            rf"## {section} \(\d+\)\s*\n\n\| Exercise \| Findings \| Report \|\n\|[-| ]+\|\n(.*?)(?=\n## |\Z)",
            text,
            re.S,
        )
        if not match:
            continue
        body = match.group(1)
        for line in body.splitlines():
            if not line.startswith("|"):
                continue
            parts = [p.strip() for p in line.strip("|").split("|")]
            if len(parts) < 3 or parts[0] == "Exercise":
                continue
            exercise, findings_text, report_cell = parts[0], parts[1], parts[2]
            report_match = re.search(r"<\s*(.+?)\s*>", report_cell)
            report_path = report_match.group(1) if report_match else None
            findings = [f.strip() for f in findings_text.split(";") if f.strip()]
            rows.append(
                {
                    "exercise": exercise,
                    "group": group,
                    "findings": findings,
                    "report_path": report_path,
                    "audit_complete": True,
                }
            )
    return rows


def load_audit_rows(audit_json: Path | None, audit_md: Path | None) -> list[dict]:
    if audit_json and audit_json.is_file():
        payload = json.loads(audit_json.read_text(encoding="utf-8"))
        if isinstance(payload, dict) and isinstance(payload.get("rows"), list):
            return payload["rows"]
        if isinstance(payload, list):
            return payload
    if audit_md and audit_md.is_file():
        return parse_audit_md(audit_md)
    raise FileNotFoundError("Provide --audit-json or --audit-md with audit rows")


def enrich_from_result(row: dict) -> dict:
    report_path = row.get("report_path")
    if not report_path:
        return row
    path = Path(report_path)
    if not path.is_file():
        return row
    try:
        result = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return row
    issues = result.get("issues_found")
    if isinstance(issues, list) and issues:
        row = dict(row)
        row["findings"] = [str(x) for x in issues if str(x).strip()]
    recommendation = result.get("repair_recommendation") or result.get("recommended_route")
    if recommendation:
        row = dict(row)
        row["worker_recommendation"] = recommendation
    if result.get("source_hashes"):
        row = dict(row)
        row["source_hashes"] = result["source_hashes"]
    row = dict(row)
    row["worker_status"] = result.get("status")
    return row


def select_batch(rows: list[dict], batch_number: int, batch_size: int) -> list[dict]:
    rank = {"critical": 0, "major": 1, "minor": 2, "clean": 3}
    audited = [r for r in rows if r.get("audit_complete") and r.get("group") in rank]
    audited.sort(key=lambda r: (rank[r["group"]], r["exercise"]))
    start = (batch_number - 1) * batch_size
    end = start + batch_size
    return audited[start:end]


def build_entry(row: dict, batch_number: int, index: int, preview_root: Path) -> dict:
    exercise_id = row["exercise"]
    severity = row["group"]
    findings = row.get("findings") or []
    tags = tag_findings(findings)
    route = suggest_route(severity, tags, findings)
    preview_dir = preview_root / exercise_id
    preview_paths = {
        "directory": str(preview_dir.resolve()),
        "maleContact": str((preview_dir / f"{exercise_id}_male-contact.png").resolve()),
        "femaleContact": str((preview_dir / f"{exercise_id}_female-contact.png").resolve()),
        "frames": [
            str((preview_dir / f"{exercise_id}_{gender}_v2_{i}-preview.png").resolve())
            for gender in ("male", "female")
            for i in range(4)
        ],
    }
    return {
        "batchNumber": batch_number,
        "index": index,
        "exerciseId": exercise_id,
        "severity": severity,
        "findings": findings,
        "issueTags": tags,
        "suggestedRoute": route,
        "auditJsonPath": row.get("report_path"),
        "workerRecommendation": row.get("worker_recommendation"),
        "workerStatus": row.get("worker_status"),
        "sourceFramePaths": frame_paths(exercise_id),
        "previewPaths": preview_paths,
        "reviewDecision": "pending",
    }


def write_markdown(batch: dict, path: Path) -> None:
    lines = [
        f"# Batch {batch['batchNumber']:02d} review checklist",
        "",
        f"- Exercises: **{batch['exerciseCount']}** ({batch['severityCounts'].get('critical', 0)} critical, "
        f"{batch['severityCounts'].get('major', 0)} major)",
        f"- Generated: {batch['generatedAt']}",
        "",
        "Mark each exercise in the canvas, or note your decision here.",
        "",
        "| # | Exercise | Severity | Suggested route | Decision |",
        "|---:|---|---|---|---|",
    ]
    for item in batch["exercises"]:
        lines.append(
            f"| {item['index']} | {item['exerciseId']} | {item['severity']} | {item['suggestedRoute']} | pending |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", type=int, default=1)
    parser.add_argument("--batch-size", type=int, default=50)
    parser.add_argument("--audit-json", type=Path, default=SOURCE_DIR / "audit-report.json")
    parser.add_argument("--audit-md", type=Path, default=SOURCE_DIR / "audit-report-excerpt.md")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=ROOT / "artifacts/workout-visual-qa/review-batches",
    )
    args = parser.parse_args()

    rows = load_audit_rows(args.audit_json if args.audit_json.is_file() else None, args.audit_md)
    selected = select_batch(rows, args.batch, args.batch_size)
    if len(selected) < args.batch_size and args.batch == 1:
        raise SystemExit(f"Expected {args.batch_size} exercises for batch 1, found {len(selected)}")

    batch_dir = args.output_dir / f"batch-{args.batch:02d}"
    preview_root = batch_dir / "previews"
    batch_dir.mkdir(parents=True, exist_ok=True)

    exercises = []
    for index, row in enumerate(selected, start=1):
        enriched = enrich_from_result(row)
        exercises.append(build_entry(enriched, args.batch, index, preview_root))

    severity_counts: dict[str, int] = {}
    tag_counts: dict[str, int] = {}
    route_counts: dict[str, int] = {}
    for item in exercises:
        severity_counts[item["severity"]] = severity_counts.get(item["severity"], 0) + 1
        route_counts[item["suggestedRoute"]] = route_counts.get(item["suggestedRoute"], 0) + 1
        for tag in item["issueTags"]:
            tag_counts[tag] = tag_counts.get(tag, 0) + 1

    from datetime import datetime, timezone

    batch = {
        "batchNumber": args.batch,
        "batchSize": args.batch_size,
        "exerciseCount": len(exercises),
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "severityCounts": severity_counts,
        "issueTagCounts": tag_counts,
        "suggestedRouteCounts": route_counts,
        "workspaceRoot": str(ROOT.resolve()),
        "sourceRoot": str(VECTORS.resolve()),
        "exercises": exercises,
    }

    json_path = batch_dir / f"batch-{args.batch:02d}.json"
    json_path.write_text(json.dumps(batch, indent=2) + "\n", encoding="utf-8")
    write_markdown(batch, batch_dir / f"batch-{args.batch:02d}.md")
    print(f"Wrote {json_path} ({len(exercises)} exercises)")


if __name__ == "__main__":
    main()
