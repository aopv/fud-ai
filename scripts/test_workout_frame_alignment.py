"""Focused safety tests: python -m unittest discover -s scripts -p 'test_workout_frame_alignment.py'."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np
from PIL import Image

from workout_frame_alignment import (
    CANONICAL, UniformTransform, analyze_job, assess_matches, ensure_experiment_output,
    inspect_rgba, least_squares_uniform, render_uniform, sequence_fit, validate_profile,
)


class WorkoutFrameAlignmentTests(unittest.TestCase):
    def anchors(self):
        rng = np.random.default_rng(18)
        left = rng.uniform([180, 600], [300, 720], (35, 2))
        right = rng.uniform([630, 600], [760, 720], (35, 2))
        return np.vstack([left, right]), np.repeat([0, 1], 35)

    def test_recovers_uniform_scale_translation_with_outliers(self):
        points, labels = self.anchors()
        expected = UniformTransform(1.025, -10, -12)
        target = expected.apply(points)
        target[:5] += [130, -80]
        result = assess_matches(points, target, labels, (1024, 768))
        self.assertTrue(result["accepted"], result)
        self.assertAlmostEqual(result["diagnostic_transform"]["scale"], expected.scale, places=4)
        self.assertAlmostEqual(result["diagnostic_transform"]["tx"], expected.tx, places=3)

    def test_only_one_anchor_region_is_not_enough(self):
        points, labels = self.anchors()
        result = assess_matches(points, points + [8, 1], np.zeros_like(labels), (1024, 768))
        self.assertFalse(result["accepted"])
        self.assertIn("anchors_not_independently_distributed", result["reasons"])

    def test_three_named_anchors_cannot_silently_ignore_the_head(self):
        points, labels = self.anchors()
        result = assess_matches(points, points + [8, 1], labels, (1024, 768), required_regions=3)
        self.assertFalse(result["accepted"])
        self.assertIn("anchors_not_independently_distributed", result["reasons"])

    def test_disagreeing_feet_cannot_create_a_fake_zoom(self):
        points, labels = self.anchors()
        target = points.copy()
        target[labels == 0] += [35, 0]
        target[labels == 1] -= [35, 0]
        result = assess_matches(points, target, labels, (1024, 768))
        self.assertFalse(result["accepted"], result)

    def test_rotation_and_nonuniform_scaling_are_rejected(self):
        points, labels = self.anchors()
        angle = np.radians(8)
        rotation = np.array([[np.cos(angle), -np.sin(angle)], [np.sin(angle), np.cos(angle)]])
        for target in (points @ rotation.T, points * [1.1, .9]):
            self.assertFalse(assess_matches(points, target, labels, (1024, 768))["accepted"])

    def test_large_camera_change_is_not_an_automatic_fix(self):
        points, labels = self.anchors()
        result = assess_matches(points, points * .65, labels, (1024, 768))
        self.assertFalse(result["accepted"])
        self.assertIn("large_camera_or_perspective_change", result["reasons"])

    def test_common_union_fit_preserves_real_squat_displacement(self):
        bboxes = [[150, 30, 875, 750], [150, 130, 875, 750], [150, 230, 875, 750], [150, 75, 875, 750]]
        common = sequence_fit(bboxes, [UniformTransform()] * 4, (1024, 768), 24)
        head = np.array([[500, 30], [500, 230]])
        positions = common.apply(head)
        self.assertAlmostEqual(positions[1, 1] - positions[0, 1], 200 * common.scale)
        foot_positions = common.apply(np.tile([[450, 750]], (4, 1)))
        self.assertTrue(np.all(foot_positions == foot_positions[0]))
        for bounds in bboxes:
            points = common.apply(np.array([bounds[:2], bounds[2:]]))
            self.assertGreaterEqual(points.min(), 24 - 1e-5)
            self.assertLessEqual(points[:, 0].max(), 1000 + 1e-5)
            self.assertLessEqual(points[:, 1].max(), 744 + 1e-5)

    def test_premultiplied_warp_does_not_add_hidden_white_fringe(self):
        rgba = np.full((60, 60, 4), 255, np.uint8)
        rgba[..., 3] = 0  # White RGB hidden under transparent exterior.
        rgba[20:40, 20:40] = [100, 0, 0, 255]
        output = render_uniform(rgba, UniformTransform(.9, 3.2, 2.8), (60, 60))
        self.assertEqual(output[..., 1].max(), 0)
        self.assertEqual(output[..., 2].max(), 0)
        self.assertGreater(output[..., 3].max(), 240)

    def test_clipped_rectangle_is_flagged_but_white_rgb_under_alpha_is_not(self):
        rgba = np.full((100, 100, 4), 255, np.uint8)
        rgba[..., 3] = 0
        rgba[20:80, 10:70] = [40, 40, 40, 255]
        result = inspect_rgba(rgba)
        self.assertIn("possible_precropped_flat_boundary", result["flags"])
        self.assertEqual(result["opaque_pale_fraction"], 0)

    def test_canonical_source_cannot_be_output(self):
        for output in (CANONICAL, CANONICAL / "tmp", CANONICAL.parent):
            with self.assertRaises(ValueError):
                ensure_experiment_output(output, CANONICAL)
        ensure_experiment_output(Path("/tmp/workout-registration-example"), CANONICAL)

    def test_unknown_stationary_semantics_never_authorize_writes(self):
        with TemporaryDirectory(prefix="workout-alignment-test-") as temporary:
            root = Path(temporary)
            (root / "source").mkdir()
            paths = []
            for index in range(4):
                rgba = np.zeros((120, 160, 4), np.uint8)
                rgba[30:90, 40:100] = [60, 80, 100, 255]
                path = root / "source" / f"frame-{index}.png"
                Image.fromarray(rgba).save(path)
                paths.append(str(path))
            result = analyze_job({"exercise": "Unknown", "gender": "male", "paths": paths,
                                  "profile": None, "padding": 10, "output": str(root / "out"),
                                  "write_images": True})
            self.assertNotEqual(result["status"], "high_confidence_anchor_alignment")
            self.assertIn("stationary_anchor_semantics_not_reviewed", result["flags"])
            self.assertFalse((root / "out/images").exists())

    def test_reviewed_profile_requires_two_regions(self):
        with self.assertRaises(ValueError):
            validate_profile({"reviewed": True, "regions": []})

    def test_degenerate_anchor_fit_is_rejected(self):
        with self.assertRaises(ValueError):
            least_squares_uniform(np.zeros((3, 2)), np.ones((3, 2)))


if __name__ == "__main__":
    unittest.main()
