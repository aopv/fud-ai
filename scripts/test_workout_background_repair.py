#!/usr/bin/env python3
"""Synthetic safety tests; no model download or production asset edits."""
import tempfile
import unittest
from pathlib import Path
import numpy as np
from repair_workout_visual_backgrounds import cleanup, ensure_staging, SOURCE, IOS


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


if __name__ == "__main__":
    unittest.main()
