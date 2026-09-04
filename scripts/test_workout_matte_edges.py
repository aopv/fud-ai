import unittest
import numpy as np
from refine_workout_matte_edges import refine


class MatteTests(unittest.TestCase):
    def sample(self):
        rgba = np.zeros((40, 40, 4), np.uint8)
        rgba[8:32, 8:32] = [40, 40, 40, 255]
        rgba[8, 8:32] = [225, 225, 225, 255]
        return rgba

    def test_thin_white_matte_unmixed_but_interior_preserved(self):
        rgba = self.sample()
        output, report = refine(rgba)
        self.assertGreater(report["edge_pixels_unmatted"], 0)
        self.assertLess(output[8, 20, 3], 100)
        np.testing.assert_array_equal(output[12:28, 12:28], rgba[12:28, 12:28])
        self.assertTrue((output[..., 3] <= rgba[..., 3]).all())

    def test_real_broad_white_detail_preserved(self):
        rgba = self.sample()
        rgba[22:32, 8:32, :3] = 240
        output, _ = refine(rgba)
        np.testing.assert_array_equal(output[26:32, 15:25], rgba[26:32, 15:25])

    def test_reviewed_edge_protection(self):
        rgba = self.sample()
        output, _ = refine(rgba, [[8, 8, 32, 10]])
        np.testing.assert_array_equal(output[8, 8:32], rgba[8, 8:32])

    def test_only_neutral_detached_small_speck_removed(self):
        rgba = self.sample()
        rgba[2:4, 2:4] = [200, 200, 200, 255]
        rgba[2:4, 35:37] = [200, 30, 30, 255]
        output, report = refine(rgba)
        self.assertEqual(report["speck_pixels_removed"], 4)
        self.assertTrue((output[2:4, 2:4, 3] == 0).all())
        np.testing.assert_array_equal(output[2:4, 35:37], rgba[2:4, 35:37])


if __name__ == "__main__":
    unittest.main()
