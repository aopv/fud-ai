#!/usr/bin/env python3
"""Synthetic safety tests; no model download or production asset edits."""
import tempfile
import unittest
import hashlib
import json
from pathlib import Path
from unittest.mock import patch
from contextlib import redirect_stdout
import io
import numpy as np
from PIL import Image
from repair_workout_visual_backgrounds import (
    analyze, audit_frame_context, cleanup, ensure_staging, ordered_frames,
    main, unchanged_preflight, RECIPE, SOURCE, IOS,
)


class CleanupTests(unittest.TestCase):
    def sample(self):
        rgba = np.zeros((20, 30, 4), dtype=np.uint8)
        rgba[2:10, 2:10] = [240, 240, 240, 255]
        rgba[12:18, 2:10] = [240, 240, 240, 255]
        rgba[2:18, 15:25] = [55, 55, 55, 255]
        mask = np.zeros((20, 30), dtype=np.uint8)
        mask[12:18, 2:10] = 255
        return rgba, mask

    def test_background_removed_white_detail_and_bench_retained(self):
        rgba, mask = self.sample()
        result, report = cleanup(rgba, mask)
        self.assertTrue((result[2:10, 2:10, 3] == 0).all())
        self.assertTrue((result[12:18, 2:10, 3] == 255).all())
        self.assertTrue((result[2:18, 15:25, 3] == 255).all())

    def test_foreground_guard_in_mixed_component(self):
        rgba, mask = self.sample()
        mask[2:3, 2:10] = 255
        result, _ = cleanup(rgba, mask)
        self.assertTrue((result[2:3, 2:10, 3] == 255).all())
        self.assertTrue((result[3:10, 2:10, 3] == 0).all())

    def test_alpha_only_hidden_neighbors_never_reappear(self):
        rgba, mask = self.sample()
        rgba[0, 0] = [150, 40, 20, 0]
        result, _ = cleanup(rgba, mask)
        np.testing.assert_array_equal(result[..., :3], rgba[..., :3])
        self.assertTrue((result[..., 3] <= rgba[..., 3]).all())
        self.assertEqual(result[0, 0, 3], 0)

    def test_reviewed_protection_and_removal(self):
        rgba, mask = self.sample()
        result, _ = cleanup(rgba, mask, [[3, 13]], [[3, 3]])
        self.assertEqual(result[3, 3, 3], 255)
        self.assertEqual(result[13, 3, 3], 0)

    def test_conflicting_or_invalid_seeds_fail(self):
        rgba, mask = self.sample()
        for seeds, protection in (([[29, 19]], []), ([[3, 3]], [[3, 3]])):
            with self.assertRaises(ValueError):
                cleanup(rgba, mask, seeds, protection)

    def test_shape_mismatch_fails(self):
        rgba, mask = self.sample()
        with self.assertRaises(ValueError):
            cleanup(rgba, mask[:1])

    def test_production_locations_rejected(self):
        for path in (SOURCE, SOURCE/"subdir", IOS, SOURCE.parent):
            with self.assertRaises(ValueError):
                ensure_staging(path, SOURCE)
        with tempfile.TemporaryDirectory() as directory:
            ensure_staging(Path(directory), SOURCE)

    def test_ineligible_preflight_matches_all_prediction_extremes(self):
        # Below the automatic area16 gate, including a component recorded at8.
        rgba = np.zeros((20, 30, 4), dtype=np.uint8)
        rgba[2:5, 2:7] = [240, 240, 240, 255]  #15 pixels
        rgba[12:18, 15:25] = [55, 55, 55, 255]
        analysis = analyze(rgba)
        candidate, report = unchanged_preflight(rgba, analysis)
        self.assertIn("inference_skipped_reason", report)
        np.testing.assert_array_equal(candidate, rgba)
        for value in (0, 63, 127, 192, 255):
            expected, _ = cleanup(rgba, np.full(rgba.shape[:2], value, dtype=np.uint8))
            np.testing.assert_array_equal(candidate, expected)

    def test_area16_still_requires_inference(self):
        rgba = np.zeros((20, 30, 4), dtype=np.uint8)
        rgba[2:6, 2:6] = [240, 240, 240, 255]
        self.assertIsNone(unchanged_preflight(rgba, analyze(rgba)))

    def test_small_seed_override_cannot_be_bypassed(self):
        rgba = np.zeros((20, 30, 4), dtype=np.uint8)
        rgba[2:4, 2:4] = [240, 240, 240, 255]  #Under recorded and automatic area gates.
        for seeds, protected in (([[2, 2]], []), ([], [[2, 2]])):
            self.assertIsNone(unchanged_preflight(rgba, analyze(rgba), seeds, protected))
        result, _ = cleanup(rgba, np.full(rgba.shape[:2], 255, dtype=np.uint8), [[2, 2]])
        self.assertEqual(result[2, 2, 3], 0)

    def test_preflight_validates_invalid_and_conflicting_seeds(self):
        rgba = np.zeros((20, 30, 4), dtype=np.uint8)
        rgba[2:4, 2:4] = [240, 240, 240, 255]
        for seeds, protected in (([[29, 19]], []), ([], [[29, 19]]),
                                 ([[30, 20]], []), ([[-1, 2]], []),
                                 ([[2, 2]], [[2, 2]])):
            with self.assertRaises(ValueError):
                unchanged_preflight(rgba, analyze(rgba), seeds, protected)

    def test_reused_analysis_preserves_cleanup(self):
        rgba, mask = self.sample()
        expected, expected_report = cleanup(rgba, mask)
        result, report = cleanup(rgba, mask, analysis=analyze(rgba))
        np.testing.assert_array_equal(result, expected)
        self.assertEqual(report, expected_report)


class PriorityTests(unittest.TestCase):
    def entries(self):
        return [{"exerciseId": name,
                 "maleFrames": [f"{name}_male_v2_{index}" for index in range(4)],
                 "femaleFrames": [f"{name}_female_v2_{index}" for index in range(4)]}
                for name in ("A", "B", "C", "D")]

    def record(self, exercise="C", flags=None):
        return {"file": f"{exercise}_female_v2_2.png", "exercise_id": exercise,
                "file_sha256": "a"*64,
                "flags": flags if flags is not None else ["suspected_baked_checkerboard"]}

    def test_priority_keeps_every_frame_and_exercise_contiguous(self):
        entries = self.entries()
        default, _ = ordered_frames(entries, {"A", "B", "C", "D"})
        audit = {"images": [self.record("C"), self.record("B", ["large_opaque_pale_region"]),
                            self.record("A", ["possible_edge_clipping"])]}
        ordered, _ = ordered_frames(entries, {"A", "B", "C", "D"}, audit)
        self.assertEqual(len(ordered), 32)
        self.assertEqual(set(ordered), set(default))
        self.assertEqual([ordered[index].split("_")[0] for index in range(0, 32, 8)], ["B", "C", "A", "D"])
        for offset in range(0, 32, 8):
            exercise = ordered[offset].split("_")[0]
            expected, _ = ordered_frames(entries, {exercise})
            self.assertEqual(ordered[offset:offset+8], expected)

    def test_selection_exclusions_and_missing_audit_frames_are_retained(self):
        entries = self.entries()
        ordered, _ = ordered_frames(entries, {"A", "C", "D"}, {"images": [self.record("B"), self.record("C")]})
        expected, _ = ordered_frames(entries, {"A", "C", "D"})
        self.assertEqual(set(ordered), set(expected))
        self.assertEqual(len(ordered), 24)
        self.assertEqual(ordered[0], "C_male_v2_0.png")
        self.assertEqual(ordered[8], "A_male_v2_0.png")

    def test_stale_hash_orders_only_and_is_reported(self):
        ordered, records = ordered_frames(self.entries(), {"A", "C"}, {"images": [self.record()]})
        self.assertEqual(ordered[0], "C_male_v2_0.png")
        context = audit_frame_context(records, "C_female_v2_2.png", "b"*64)
        self.assertFalse(context["source_hash_matches"])
        self.assertEqual(context["authority"], "ordering_only_not_acceptance")
        self.assertEqual(len(ordered), 16)
        self.assertTrue(audit_frame_context(records, "C_female_v2_2.png", "a"*64)["source_hash_matches"])
        self.assertIsNone(audit_frame_context(records, "A_male_v2_0.png", "a"*64)["source_hash_matches"])

    def test_invalid_filename_owner_hash_or_duplicates_fail(self):
        bad_records = [[{**self.record(), "file": "../elsewhere.png"}],
                       [{**self.record(), "exercise_id": "A"}],
                       [{**self.record(), "file_sha256": "bad"}],
                       [{**self.record(), "flags": "suspected_baked_checkerboard"}],
                       [self.record(), self.record()]]
        for records in bad_records:
            with self.assertRaises(ValueError):
                ordered_frames(self.entries(), {"A", "C"}, {"images": records})


class StagingPreflightTests(unittest.TestCase):
    def test_priority_resume_counts_late_queue_cache_and_rechecks_changed_sources(self):
        for change_source_after_scan in (False, True):
            with self.subTest(change_source_after_scan=change_source_after_scan), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source, output = root/"source", root/"staging"
                source.mkdir()
                entries = PriorityTests().entries()[:2]
                names, _ = ordered_frames(entries, {"A", "B"})
                for name in names:
                    Image.new("RGBA", (20, 30), (40, 20, 10, 255)).save(source/name)
                manifest = root/"manifest.json"
                manifest.write_text(json.dumps({"exercises": entries}))
                audit = root/"audit.json"
                audit.write_text(json.dumps({"images": [PriorityTests().record("B")]}))
                argv = ["repair", "--source", str(source), "--manifest", str(manifest), "--output", str(output)]
                with patch("sys.argv", argv+["--exercise", "A"]), redirect_stdout(io.StringIO()):
                    self.assertEqual(main(), 0)
                # Resume all16 but prioritize previously unprocessed B. All8 A
                # candidates must count immediately, although visited last.
                snapshots = []
                real_dumps = json.dumps
                changed = False
                def capture_progress(value, *args, **kwargs):
                    nonlocal changed
                    if isinstance(value, dict) and "completed_candidate_frames" in value:
                        snapshots.append(dict(value))
                        if change_source_after_scan and not changed:
                            Image.new("RGBA", (20, 30), (55, 25, 15, 255)).save(source/"A_male_v2_0.png")
                            changed = True
                    return real_dumps(value, *args, **kwargs)
                with patch("sys.argv", argv+["--priority-audit", str(audit)]), \
                     patch("repair_workout_visual_backgrounds.json.dumps", side_effect=capture_progress), \
                     patch("repair_workout_visual_backgrounds.load_session", side_effect=AssertionError("no inference needed")), \
                     redirect_stdout(io.StringIO()):
                    self.assertEqual(main(), 0)
                self.assertEqual(snapshots[0]["completed_candidate_frames"], 8)
                self.assertEqual(snapshots[0]["queue_frames_visited"], 0)
                self.assertEqual(snapshots[0]["initial_valid_cached_frames"], 8)
                self.assertEqual(snapshots[1]["completed_candidate_frames"], 9)
                self.assertEqual(snapshots[1]["queue_frames_visited"], 1)
                self.assertEqual(snapshots[-1]["completed_candidate_frames"], 16)
                self.assertEqual(snapshots[-1]["queue_frames_visited"], 16)
                self.assertTrue(all(snapshot["completed_candidate_frames"] <= 16 for snapshot in snapshots))
                if change_source_after_scan:
                    invalidated = [snapshot for snapshot in snapshots if snapshot["queue_frames_visited"] == 8]
                    self.assertEqual([snapshot["completed_candidate_frames"] for snapshot in invalidated], [16, 15])
                else:
                    self.assertTrue(all(snapshot["completed_candidate_frames"] == 16 for snapshot in snapshots if snapshot["queue_frames_visited"] >= 8))

    def test_cli_skip_and_resume_never_load_or_cache_a_fake_model_mask(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, output = root/"source", root/"staging"
            source.mkdir()
            entries = PriorityTests().entries()[:1]
            names, _ = ordered_frames(entries, {"A"})
            originals = {}
            for name in names:
                path = source/name
                Image.new("RGBA", (20, 30), (40, 20, 10, 255)).save(path)
                originals[name] = hashlib.sha256(path.read_bytes()).hexdigest()
            manifest = root/"manifest.json"
            manifest.write_text(json.dumps({"exercises": entries}))
            audit = root/"audit.json"
            audit.write_text(json.dumps({"images": [PriorityTests().record("A")]}))
            argv = ["repair", "--source", str(source), "--manifest", str(manifest),
                    "--output", str(output), "--priority-audit", str(audit)]
            with patch("sys.argv", argv), patch("repair_workout_visual_backgrounds.load_session", side_effect=AssertionError("inference must not run")):
                self.assertEqual(main(), 0)
            self.assertFalse(list((output/"masks").iterdir()))
            summary = json.loads((output/"background-report.json").read_text())
            self.assertEqual(summary["frames"], 8)
            self.assertEqual(summary["inference_skipped_frames"], 8)
            self.assertEqual(summary["accepted_exercises"], 0)
            for record in summary["records"]:
                self.assertIsNone(record["mask_sha256"])
                self.assertEqual(record["recipe"], RECIPE)
                self.assertEqual(record["acceptance"], "pending_visual_review")
                np.testing.assert_array_equal(np.asarray(Image.open(output/"images"/record["file"])), np.asarray(Image.open(source/record["file"])))
            self.assertFalse(next(record for record in summary["records"] if record["file"] == "A_female_v2_2.png")["priority_audit"]["source_hash_matches"])
            candidates = {name: (output/"images"/name).read_bytes() for name in names}
            with patch("sys.argv", argv), patch("repair_workout_visual_backgrounds.load_session", side_effect=AssertionError("resume must not load model")):
                self.assertEqual(main(), 0)
            self.assertFalse(list((output/"masks").iterdir()))
            for name in names:
                self.assertEqual((output/"images"/name).read_bytes(), candidates[name])
                self.assertEqual(hashlib.sha256((source/name).read_bytes()).hexdigest(), originals[name])


if __name__ == "__main__":
    unittest.main()
