"""Pin exact visually accepted kneeling candidates; never copy production assets."""
from pathlib import Path
import hashlib
import json
from PIL import Image
import numpy as np

QA=Path(__file__).resolve().parent.parent
REPO=QA.parents[1]
FINAL=QA/"recovered-kneeling-framed-v5"
EXERCISE="Barbell_Ab_Rollout_-_On_Knees"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    review=FINAL/"final-review.md"
    if "Acceptance: **background_and_framing**" not in review.read_text():
        raise ValueError("no explicit completed visual acceptance")
    records=json.loads((FINAL/"polish-report.json").read_text())["frames"]
    entry={"exercise_id":EXERCISE,"acceptance":"background_and_framing",
           "review_record_path":str(review.relative_to(REPO)),"review_record_sha256":sha(review),"frames":[]}
    checks=[]
    for gender in ("male","female"):
        for index in range(4):
            name=f"{EXERCISE}_{gender}_v2_{index}"
            candidate=FINAL/"images"/(name+".png")
            record=next(r for r in records if r["file"]==candidate.name)
            assert sha(candidate)==record["output_sha256"]
            assert sha(Path(record["source"]))==record["source_sha256"]
            original=REPO/"shared/workout-vectors"/(name+".png")
            image=Image.open(candidate)
            assert image.mode=="RGBA" and image.size==(1024,768)
            alpha=np.array(image.getchannel("A"))
            assert alpha.min()==0 and alpha.max()==255
            assert not np.any(alpha[0]) and not np.any(alpha[-1]) and not np.any(alpha[:,0]) and not np.any(alpha[:,-1])
            entry["frames"].append({"asset_name":name,"candidate_path":str(candidate.relative_to(REPO)),
                                    "candidate_sha256":sha(candidate),"original_shared_sha256":sha(original)})
            checks.append({"file":candidate.name,"RGBA":True,"size":[1024,768],"zero_visible_edge_pixels":True,
                           "candidate_matches_viewed_stage_hash":True,"visual_acceptance":"background_and_framing"})
    manifest={"schema_version":1,"exercises":[entry]}
    (FINAL/"promotion-manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    (FINAL/"integrity-report.json").write_text(json.dumps({"frames":8,"canonical_writes":0,"checks":checks},indent=2)+"\n")
    print(json.dumps({"manifest":str(FINAL/"promotion-manifest.json"),"frames":8,"canonical_writes":0}))


if __name__=="__main__":
    main()
