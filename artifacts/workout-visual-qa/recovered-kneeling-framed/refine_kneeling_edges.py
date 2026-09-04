"""Candidate-only root edge refinement with per-frame shoe protections."""
import hashlib
import json
import argparse
from pathlib import Path
import sys
import numpy as np
from PIL import Image, ImageDraw

QA = Path(__file__).resolve().parent.parent
REPO = QA.parents[1]
sys.path.insert(0, str(REPO / "scripts"))
from refine_workout_matte_edges import refine

SOURCE = QA / "recovered-kneeling-framed-v2"
OUTPUT = QA / "recovered-kneeling-framed-v3"
SHOE_BOXES = {
    "male_0": [[430, 192, 470, 275]],
    "male_1": [[486, 97, 534, 151], [532, 112, 581, 199]],
    "male_2": [[514, 12, 571, 84], [570, 21, 616, 106]],
    "male_3": [[394, 193, 450, 282]],
    "female_0": [[399, 216, 440, 279], [438, 222, 482, 313]],
    "female_1": [[451, 145, 498, 206], [495, 155, 543, 242]],
    "female_2": [[507, 37, 547, 84], [543, 44, 583, 129]],
    "female_3": [[397, 209, 438, 270], [439, 219, 483, 308]],
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def composite(image, color):
    panel = Image.new("RGBA", image.size, (*color, 255))
    panel.alpha_composite(image)
    return panel.convert("RGB")


def main():
    global SOURCE, OUTPUT
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input",type=Path,default=SOURCE)
    parser.add_argument("--output",type=Path,default=OUTPUT)
    args=parser.parse_args();SOURCE=args.input.resolve();OUTPUT=args.output.resolve()
    if not OUTPUT.is_relative_to(QA) or OUTPUT==SOURCE or OUTPUT.is_relative_to(SOURCE):
        raise ValueError("output must be separate visual-QA staging")
    (OUTPUT / "images").mkdir(parents=True, exist_ok=True)
    framing = json.loads((SOURCE / "framing-report.json").read_text())
    report = {"method": "root refine_workout_matte_edges.refine with reviewed shoe protection boxes", "frames": []}
    contact = {g: Image.new("RGB", (2048,1536), (12,12,14)) for g in ("male", "female")}
    for frame in framing["frames"]:
        source = Path(frame["output"])
        rgba = np.array(Image.open(source).convert("RGBA"))
        digest = sha(source)
        matrix = np.array(frame["affine_matrix"])
        scale = matrix[0,0]
        boxes = []
        for box in SHOE_BOXES[frame["key"]]:
            transformed = np.array(box)*scale + np.tile(matrix[:,2],2)
            boxes.append([max(0,int(np.floor(transformed[0]))), max(0,int(np.floor(transformed[1]))),
                          min(1024,int(np.ceil(transformed[2]))), min(768,int(np.ceil(transformed[3])))])
        result, record = refine(rgba, boxes)
        # Shoe protection rectangles must not change visible pixels in this stage.
        for left,top,right,bottom in boxes:
            assert np.array_equal(result[top:bottom,left:right], rgba[top:bottom,left:right])
        assert np.all(result[:,:,3] <= rgba[:,:,3])
        destination = OUTPUT / "images" / source.name
        image = Image.fromarray(result)
        image.save(destination)
        dark = composite(image, (12,12,14))
        light = composite(image, (245,245,247))
        preview = Image.new("RGB", (2048,768))
        preview.paste(dark,(0,0)); preview.paste(light,(1024,0))
        preview.save(OUTPUT / (source.stem+"-preview.png"))
        gender, index = frame["key"].split("_"); index=int(index)
        contact[gender].paste(dark,((index%2)*1024,(index//2)*768))
        ImageDraw.Draw(contact[gender]).text(((index%2)*1024+12,(index//2)*768+12),frame["key"],fill=(240,240,240))
        record.update({"file":source.name,"source_sha256":digest,"source":str(source),"output":str(destination),
                       "output_sha256":sha(destination),"protected_shoe_boxes":boxes,
                       "rgb_changed_pixels":int(np.any(result[:,:,:3]!=rgba[:,:,:3],axis=2).sum()),
                       "alpha_changed_pixels":int((result[:,:,3]!=rgba[:,:,3]).sum())})
        assert sha(source)==digest
        report["frames"].append(record)
    for gender,image in contact.items():
        image.resize((1024,768),Image.Resampling.LANCZOS).save(OUTPUT/(gender+"-contact.png"))
    (OUTPUT/"edge-refinement-report.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"output":str(OUTPUT),"frames":len(report["frames"]),
                      "edge_pixels_unmatted":sum(r["edge_pixels_unmatted"] for r in report["frames"]),
                      "source_integrity":"All eight input framed-source hashes unchanged; no canonical writes"}))


if __name__=="__main__":
    main()
