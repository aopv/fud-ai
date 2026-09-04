#!/usr/bin/env python3
"""Generate a Cursor review canvas from a workout audit batch JSON."""

from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CANVAS_HEADER = '''import {
  Button,
  Callout,
  CollapsibleSection,
  Divider,
  Grid,
  H1,
  H2,
  Link,
  Pill,
  Row,
  Select,
  Stack,
  Stat,
  Table,
  Text,
  TextInput,
  useCanvasAction,
  useCanvasState,
  useHostTheme,
} from "cursor/canvas";
import { useMemo } from "react";

type ReviewDecision = "pending" | "accept_as_is" | "script_fix" | "redraw" | "defer";

type ExerciseRow = {
  index: number;
  exerciseId: string;
  severity: "critical" | "major";
  findings: string[];
  issueTags: string[];
  suggestedRoute: string;
  auditJsonPath: string | null;
  maleContact: string;
  femaleContact: string;
  previewDir: string;
  sourceFrames: string[];
};

const BATCH = '''

CANVAS_FOOTER = ''' as {
  meta: {
    batchNumber: number;
    exerciseCount: number;
    severityCounts: Record<string, number>;
    issueTagCounts: Record<string, number>;
    suggestedRouteCounts: Record<string, number>;
    generatedAt: string;
    workspaceRoot: string;
  };
  exercises: ExerciseRow[];
};

const REVIEW_OPTIONS = [
  { value: "pending", label: "Pending" },
  { value: "accept_as_is", label: "Accept as-is" },
  { value: "script_fix", label: "Script fix" },
  { value: "redraw", label: "Redraw" },
  { value: "defer", label: "Defer" },
];

const SORT_OPTIONS = [
  { value: "index", label: "Batch order" },
  { value: "exerciseId", label: "Exercise name" },
  { value: "severity", label: "Severity" },
  { value: "suggestedRoute", label: "Suggested route" },
  { value: "decision", label: "Your decision" },
];

function severityTone(severity: string): "warning" | "neutral" {
  if (severity === "critical") return "warning";
  if (severity === "major") return "neutral";
  return "neutral";
}

function routeTone(route: string): "info" | "warning" | "neutral" {
  if (route === "script_fix") return "info";
  if (route === "redraw") return "warning";
  if (route === "defer") return "neutral";
  return "neutral";
}

export default function WorkoutAuditBatchReview() {
  const theme = useHostTheme();
  const dispatch = useCanvasAction();
  const [search, setSearch] = useCanvasState("search", "");
  const [severityFilter, setSeverityFilter] = useCanvasState("severityFilter", "all");
  const [tagFilter, setTagFilter] = useCanvasState("tagFilter", "all");
  const [routeFilter, setRouteFilter] = useCanvasState("routeFilter", "all");
  const [sortKey, setSortKey] = useCanvasState("sortKey", "index");
  const [decisions, setDecisions] = useCanvasState<Record<string, ReviewDecision>>("decisions", {});

  const tagOptions = useMemo(
    () => [
      { value: "all", label: "All issue tags" },
      ...Object.keys(BATCH.meta.issueTagCounts)
        .sort()
        .map((tag) => ({ value: tag, label: `${tag} (${BATCH.meta.issueTagCounts[tag]})` })),
    ],
    [],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    let rows = BATCH.exercises.filter((row) => {
      if (severityFilter !== "all" && row.severity !== severityFilter) return false;
      if (tagFilter !== "all" && !row.issueTags.includes(tagFilter)) return false;
      if (routeFilter !== "all" && row.suggestedRoute !== routeFilter) return false;
      if (!q) return true;
      const blob = [row.exerciseId, row.severity, row.suggestedRoute, ...row.issueTags, ...row.findings]
        .join(" ")
        .toLowerCase();
      return blob.includes(q);
    });

    rows = [...rows].sort((a, b) => {
      if (sortKey === "index") return a.index - b.index;
      if (sortKey === "exerciseId") return a.exerciseId.localeCompare(b.exerciseId);
      if (sortKey === "severity") return a.severity.localeCompare(b.severity) || a.index - b.index;
      if (sortKey === "suggestedRoute") return a.suggestedRoute.localeCompare(b.suggestedRoute) || a.index - b.index;
      if (sortKey === "decision") {
        const da = decisions[a.exerciseId] ?? "pending";
        const db = decisions[b.exerciseId] ?? "pending";
        return da.localeCompare(db) || a.index - b.index;
      }
      return a.index - b.index;
    });
    return rows;
  }, [search, severityFilter, tagFilter, routeFilter, sortKey, decisions]);

  const decisionCounts = useMemo(() => {
    const counts: Record<string, number> = { pending: 0 };
    for (const row of BATCH.exercises) {
      const d = decisions[row.exerciseId] ?? "pending";
      counts[d] = (counts[d] ?? 0) + 1;
    }
    return counts;
  }, [decisions]);

  const setDecision = (exerciseId: string, value: string) => {
    setDecisions((prev) => ({ ...prev, [exerciseId]: value as ReviewDecision }));
  };

  return (
    <Stack gap={16} style={{ padding: 16, color: theme.text.primary }}>
      <Stack gap={4}>
        <H1>Workout audit — batch {BATCH.meta.batchNumber}</H1>
        <Text tone="secondary">
          Review production originals on dark/light contact sheets. Audit-only — no repairs run yet.
        </Text>
        <Text tone="tertiary" size="small">
          Generated {BATCH.meta.generatedAt} · {BATCH.meta.exerciseCount} exercises
        </Text>
      </Stack>

      <Grid columns={4} gap={12}>
        <Stat value={BATCH.meta.exerciseCount} label="Exercises in batch" />
        <Stat value={BATCH.meta.severityCounts.critical ?? 0} label="Critical" tone="danger" />
        <Stat value={BATCH.meta.severityCounts.major ?? 0} label="Major" tone="warning" />
        <Stat
          value={`${decisionCounts.pending ?? 0} pending`}
          label="Your review progress"
          tone="info"
        />
      </Grid>

      <Callout tone="info">
        Target: squat-style transparent PNGs readable on light and dark backgrounds with stable 4-frame
        animation. Suggested routes use the local repair scripts first; redraw only when anatomy or
        multi-pose fragments block script fixes.
      </Callout>

      <Stack gap={8}>
        <H2>Filters</H2>
        <Row gap={8} wrap>
          <TextInput
            value={search}
            onChange={setSearch}
            placeholder="Search exercise or finding…"
            style={{ minWidth: 220, flex: 1 }}
          />
          <Select
            value={severityFilter}
            onChange={setSeverityFilter}
            options={[
              { value: "all", label: "All severities" },
              { value: "critical", label: "Critical only" },
              { value: "major", label: "Major only" },
            ]}
            style={{ minWidth: 160 }}
          />
          <Select value={tagFilter} onChange={setTagFilter} options={tagOptions} style={{ minWidth: 180 }} />
          <Select
            value={routeFilter}
            onChange={setRouteFilter}
            options={[
              { value: "all", label: "All routes" },
              ...Object.keys(BATCH.meta.suggestedRouteCounts).map((route) => ({
                value: route,
                label: `${route} (${BATCH.meta.suggestedRouteCounts[route]})`,
              })),
            ]}
            style={{ minWidth: 160 }}
          />
          <Select value={sortKey} onChange={setSortKey} options={SORT_OPTIONS} style={{ minWidth: 160 }} />
        </Row>
        <Text tone="tertiary" size="small">
          Showing {filtered.length} of {BATCH.exercises.length} exercises
        </Text>
      </Stack>

      <Stack gap={8}>
        <H2>Summary table</H2>
        <Table
          headers={["#", "Exercise", "Severity", "Tags", "Suggested route", "Your decision"]}
          rows={filtered.map((row) => [
            String(row.index),
            row.exerciseId,
            row.severity,
            row.issueTags.join(", "),
            row.suggestedRoute,
            decisions[row.exerciseId] ?? "pending",
          ])}
          rowTone={filtered.map((row) => severityTone(row.severity))}
          striped
          stickyHeader
        />
      </Stack>

      <Divider />

      <Stack gap={8}>
        <H2>Exercise details</H2>
        {filtered.map((row) => {
          const decision = decisions[row.exerciseId] ?? "pending";
          return (
            <CollapsibleSection
              key={row.exerciseId}
              title={row.exerciseId}
              count={row.findings.length}
              leading={<Pill tone={severityTone(row.severity)} size="sm">{row.severity}</Pill>}
              trailing={
                <Row gap={8} align="center">
                  <Pill tone={routeTone(row.suggestedRoute)} size="sm">{row.suggestedRoute}</Pill>
                  <Select
                    value={decision}
                    onChange={(value) => setDecision(row.exerciseId, value)}
                    options={REVIEW_OPTIONS}
                    style={{ minWidth: 140 }}
                  />
                </Row>
              }
            >
              <Stack gap={8}>
                <Text weight="semibold">Findings</Text>
                <Stack gap={4}>
                  {row.findings.map((finding, i) => (
                    <Text key={`${row.exerciseId}-f-${i}`} size="small">
                      • {finding}
                    </Text>
                  ))}
                </Stack>
                <Row gap={8} wrap>
                  {row.issueTags.map((tag) => (
                    <Pill key={tag} tone="neutral" size="sm">{tag}</Pill>
                  ))}
                </Row>
                <Row gap={8} wrap>
                  <Button variant="secondary" onClick={() => dispatch({ type: "openFile", path: row.maleContact })}>
                    Male contact sheet
                  </Button>
                  <Button variant="secondary" onClick={() => dispatch({ type: "openFile", path: row.femaleContact })}>
                    Female contact sheet
                  </Button>
                  <Button variant="ghost" onClick={() => dispatch({ type: "openFile", path: row.previewDir })}>
                    Preview folder
                  </Button>
                </Row>
                <Text tone="tertiary" size="small">
                  Source frames (production originals):
                </Text>
                <Stack gap={2}>
                  {row.sourceFrames.map((frame) => (
                    <Link key={frame} href={`file://${frame}`}>
                      {frame.split("/").pop()}
                    </Link>
                  ))}
                </Stack>
              </Stack>
            </CollapsibleSection>
          );
        })}
      </Stack>
    </Stack>
  );
}
'''


def rewrite_path(path: str, old_root: str, new_root: str) -> str:
    if path.startswith(old_root):
        return str(Path(new_root) / Path(path).relative_to(old_root))
    return path


def canvas_exercise(item: dict, old_root: str, new_root: str) -> dict:
    previews = item.get("previewPaths") or {}
    source_frames = item.get("sourceFramePaths") or item.get("sourceFrames") or []
    return {
        "index": item["index"],
        "exerciseId": item["exerciseId"],
        "severity": item["severity"],
        "findings": item.get("findings") or [],
        "issueTags": item.get("issueTags") or [],
        "suggestedRoute": item.get("suggestedRoute") or "defer",
        "auditJsonPath": item.get("auditJsonPath"),
        "maleContact": rewrite_path(previews.get("maleContact", ""), old_root, new_root),
        "femaleContact": rewrite_path(previews.get("femaleContact", ""), old_root, new_root),
        "previewDir": rewrite_path(previews.get("directory", ""), old_root, new_root),
        "sourceFrames": [rewrite_path(p, old_root, new_root) for p in source_frames],
    }


def build_canvas_payload(batch: dict, workspace_root: Path) -> dict:
    old_root = batch.get("workspaceRoot") or str(workspace_root)
    new_root = str(workspace_root.resolve())
    return {
        "meta": {
            "batchNumber": batch["batchNumber"],
            "exerciseCount": batch["exerciseCount"],
            "severityCounts": batch.get("severityCounts") or {},
            "issueTagCounts": batch.get("issueTagCounts") or {},
            "suggestedRouteCounts": batch.get("suggestedRouteCounts") or {},
            "generatedAt": batch.get("generatedAt") or "",
            "workspaceRoot": new_root,
        },
        "exercises": [
            canvas_exercise(item, old_root, new_root) for item in batch.get("exercises") or []
        ],
    }


def find_cursor_canvas_dir() -> Path | None:
    projects = Path.home() / ".cursor" / "projects"
    if not projects.is_dir():
        return None
    matches = sorted(projects.glob("*fud-ai*/canvases"))
    return matches[0] if matches else None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", type=int, default=1)
    parser.add_argument(
        "--batch-json",
        type=Path,
        help="Batch JSON path (default: artifacts/.../batch-NN/batch-NN.json)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Write canvas TSX here (default: artifacts/.../canvas/workout-audit-batch-NN.canvas.tsx)",
    )
    parser.add_argument(
        "--install-canvas",
        action="store_true",
        help="Copy generated canvas into ~/.cursor/projects/<fud-ai>/canvases/",
    )
    parser.add_argument(
        "--canvas-dir",
        type=Path,
        help="Override Cursor canvases directory for --install-canvas",
    )
    args = parser.parse_args()

    batch_json = args.batch_json or (
        ROOT / f"artifacts/workout-visual-qa/review-batches/batch-{args.batch:02d}/batch-{args.batch:02d}.json"
    )
    if not batch_json.is_file():
        raise SystemExit(f"Batch JSON not found: {batch_json}")

    batch = json.loads(batch_json.read_text(encoding="utf-8"))
    payload = build_canvas_payload(batch, ROOT)
    canvas_name = f"workout-audit-batch-{args.batch:02d}.canvas.tsx"
    output = args.output or (
        ROOT / f"artifacts/workout-visual-qa/review-batches/canvas/{canvas_name}"
    )
    output.parent.mkdir(parents=True, exist_ok=True)

    body = json.dumps(payload, indent=2)
    output.write_text(CANVAS_HEADER + body + CANVAS_FOOTER, encoding="utf-8")
    print(f"Wrote {output}")

    if args.install_canvas:
        canvas_dir = args.canvas_dir or find_cursor_canvas_dir()
        if canvas_dir is None:
            raise SystemExit(
                "Could not find ~/.cursor/projects/*fud-ai*/canvases/. "
                "Pass --canvas-dir explicitly."
            )
        canvas_dir.mkdir(parents=True, exist_ok=True)
        dest = canvas_dir / canvas_name
        shutil.copy2(output, dest)
        print(f"Installed canvas to {dest}")


if __name__ == "__main__":
    main()
