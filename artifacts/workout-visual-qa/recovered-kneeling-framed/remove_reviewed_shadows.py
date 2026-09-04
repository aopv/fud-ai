"""Only manually reviewed native-coordinate neutral shadow components.

No model inference, global gray deletion, or production writes. RGB unchanged.
The explicit labels below are tied to hashes in the generated seed ledger and
were visually reviewed on 3x native-coordinate labeled diagrams. Shoe soles,
metallic highlights, and body/plate linework are not globally thresholded away.
"""
from pathlib import Path
import hashlib
import json
import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
QA = ROOT.parent
SOURCE = QA / "recovered-kneeling-cleanup" / "images"
OUTPUT = QA / "recovered-kneeling-shadow-cleanup"
EXPECTED_SOURCE_SHA256 = {
    "male_0": "0529a32a10a942ad2556740171e13f8dcc7f55c9539ed0c0fc95ef6598a3559c",
    "male_1": "e8e8cc37c44c4dc696fa4d1077aeaafb665948741fc41d2e3b5f046996bafdbe",
    "male_2": "78e10ab3ef136f1986ceb379bb7404a1566b13d4397137c83ee20fc3701bcf3c",
    "male_3": "308ae3bf8b823b4f388dd5c6869a31b3104b422e91e3138e3920d436c51cf201",
    "female_0": "3d20f12826a984c0a06d8e866342f8a1e47a45c71e6d864ce65b92c7a94fba96",
    "female_1": "d01b238382c6ac57ffcb383d22e28f0dccac4998dbbf63e72ece5c865c19eb85",
    "female_2": "f1a380c4bf89d52ffa32824e4489458159ebcc09a510d771e99d438815bc5e35",
    "female_3": "d4fc75cc0b2c20834e321f4ba822139c8d905929385f3522fd2197897de88adc",
}
SELECTED = {
    "male_0": [288, 311, 320, 337, 348, 351, 360, 427, 429],
    "male_1": [281, 282, 336, 345, 462, 483, 559, 561],
    "male_2": [116, 119, 127, 146, 338, 372, 456, 459],
    "male_3": [327, 331, 343, 334, 344, 411, 414],
    "female_0": [437, 461, 488, 512, 555, 557],
    "female_1": [402, 426, 435, 495, 514, 568, 571],
    "female_2": [259, 282, 290, 353, 448, 454, 511, 513],
    "female_3": [412, 432, 446, 492, 494],
}
PROTECTED = {
    "male_0": [149, 158, 199, 209, 217, 238, 269, 294, 347, 356, 365, 392],
    "male_1": [90, 111, 122, 222, 209, 275, 291, 309, 340, 399, 447, 474, 497, 511],
    "male_2": [2, 12, 18, 37, 45, 95, 134, 180, 193, 208, 221, 277, 324, 367, 392, 406],
    "male_3": [155, 249, 147, 190, 204, 215, 226, 248, 266, 337, 353, 367],
    "female_0": [202, 214, 269, 282, 277, 318, 351, 352, 358, 371, 411, 475, 493],
    "female_1": [130, 151, 225, 245, 255, 318, 340, 349, 369, 373, 403, 483, 505],
    "female_2": [49, 76, 124, 133, 181, 266, 293, 294, 324, 346, 322, 412, 457],
    "female_3": [170, 181, 239, 253, 248, 289, 307, 308, 313, 328, 351, 423, 439],
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def closest_member(labels, label, center):
    yy, xx = np.nonzero(labels == label)
    index = np.argmin((xx-center[0])**2 + (yy-center[1])**2)
    return [int(xx[index]), int(yy[index])]


def main():
    (OUTPUT / "images").mkdir(parents=True, exist_ok=True)
    ledger = {"recipe": "reviewed-neutral-shadow-native-v1",
              "component_predicate": "source alpha>=16, minRGB>=100, maxRGB-minRGB<=20; 8-connectivity",
              "warning": "NOT compatible with default pale>=185 recipe; only use exact reviewed source hashes. No global gray removal.",
              "coordinate_space": "native recovered crop; same coordinates as RAW source crop before cleanup",
              "frames": []}
    raw_records = json.loads((QA / "recovered-kneeling-cleanup" / "background-report.json").read_text())["records"]
    for key, selected in SELECTED.items():
        gender, frame = key.split("_")
        name = f"Barbell_Ab_Rollout_-_On_Knees_{gender}_v2_{frame}.png"
        path = SOURCE / name
        digest = sha(path)
        if digest != EXPECTED_SOURCE_SHA256[key]:
            raise ValueError(f"manually reviewed source has changed: {path}")
        rgba = np.array(Image.open(path).convert("RGBA"))
        rgb = rgba[:, :, :3].astype(np.int16)
        eligible = (rgba[:, :, 3] >= 16) & (rgb.min(axis=2) >= 100) & (np.ptp(rgb, axis=2) <= 20)
        _, labels, stats, centers = cv2.connectedComponentsWithStats(eligible.astype(np.uint8), 8)
        if set(selected) & set(PROTECTED[key]):
            raise ValueError(f"overlapping protected/removal labels: {key}")
        output = rgba.copy()
        remove = np.isin(labels, selected)
        output[remove, 3] = 0
        assert np.array_equal(output[:, :, :3], rgba[:, :, :3])
        assert np.all(output[:, :, 3] <= rgba[:, :, 3])
        assert np.array_equal(output[np.isin(labels, PROTECTED[key])], rgba[np.isin(labels, PROTECTED[key])])
        destination = OUTPUT / "images" / name
        Image.fromarray(output).save(destination)
        raw = next(record for record in raw_records if record["file"] == name)
        item = {"file": name, "input": str(path), "input_sha256": digest,
                "raw_source": raw["source"], "raw_source_sha256": raw["source_sha256"],
                "remove_seeds": [closest_member(labels, label, centers[label]) for label in selected],
                "protect_seeds": [closest_member(labels, label, centers[label]) for label in PROTECTED[key]],
                "removed_labels": selected, "protected_labels": PROTECTED[key],
                "removed_pixels": int(remove.sum()), "rgb_changed_pixels": 0,
                "output_sha256": sha(destination), "removed_regions": [],
                "review_status": "pending output review"}
        for label in selected:
            x,y,w,h,area = map(int,stats[label])
            item["removed_regions"].append({"label": label, "bbox": [x,y,x+w,y+h], "area": area})
        assert sha(path) == digest
        ledger["frames"].append(item)
    (OUTPUT / "reviewed-shadow-seeds.json").write_text(json.dumps(ledger, indent=2)+"\n")
    print(json.dumps({"output": str(OUTPUT), "frames": len(ledger["frames"]),
                      "removed_shadow_pixels": sum(f["removed_pixels"] for f in ledger["frames"]),
                      "source_integrity": "All eight input hashes unchanged; only candidate alpha decreased"}))


if __name__ == "__main__":
    main()
