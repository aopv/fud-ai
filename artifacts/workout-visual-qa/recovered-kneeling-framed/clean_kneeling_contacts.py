"""Remove only three pixel-grid-reviewed source-native contact remnants."""
import hashlib
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

QA=Path(__file__).resolve().parent.parent
SOURCE=QA/"recovered-kneeling-shadow-cleanup"
OUTPUT=QA/"recovered-kneeling-contact-cleanup"
# Polygons isolate demonstrated residual shadow OUTSIDE the shoe/knee contour.
# Neutral color and darkness guards retain skin, black contour ink and real
# white sole pixels even where the deliberately small polygon brushes an edge.
POLYGONS={
    "male_3":[[[431,271],[437,273],[436,275],[428,277],[428,275]]],
    "female_1":[[[406,263],[412,263],[410,265],[406,265]],
                [[417,269],[420,269],[425,272],[418,272]]],
    "female_2":[[[424,155],[429,156],[427,160],[425,160]],
                [[427,157],[431,157],[434,160],[426,160]],
                [[459,161],[462,161],[468,164],[458,165]]],
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    (OUTPUT/"images").mkdir(parents=True,exist_ok=True)
    frames=json.loads((SOURCE/"reviewed-shadow-seeds.json").read_text())["frames"]
    report={"recipe":"manual-native-contact-polygons-v1","frames":[],
            "predicate":"alpha>0, neutral chroma<=20, minRGB>=55; male shoe patch additionally maxRGB<=185",
            "review":"native 12x pixel grids in recovered-kneeling-framed-v4/diagnostics"}
    for frame in frames:
        source=SOURCE/"images"/frame["file"]
        assert sha(source)==frame["output_sha256"]
        rgba=np.array(Image.open(source).convert("RGBA"));rgb=rgba[:,:,:3].astype(np.int16)
        key=source.stem.split("_On_Knees_")[1].replace("_v2_","_")
        region=np.zeros(rgba.shape[:2],np.uint8)
        for polygon in POLYGONS.get(key,[]):
            cv2.fillPoly(region,[np.array(polygon,np.int32)],1)
        remove=(region>0)&(rgba[:,:,3]>0)&(np.ptp(rgb,axis=2)<=20)&(rgb.min(axis=2)>=55)
        if key=="male_3":
            remove &= rgb.max(axis=2)<=185
        result=rgba.copy();result[remove,3]=0
        # The above precise cuts can isolate 1-pixel shadow crumbs. Delete only
        # tiny neutral islands inside the reviewed contact neighborhoods.
        count,labels,stats,_=cv2.connectedComponentsWithStats((result[:,:,3]>2).astype(np.uint8),8)
        neighborhood=cv2.dilate(region,np.ones((7,7),np.uint8))>0
        detached=np.zeros_like(remove)
        for label in range(1,count):
            x,y,w,h,area=map(int,stats[label])
            if area>8:
                continue
            component=labels[y:y+h,x:x+w]==label
            colors=rgb[y:y+h,x:x+w][component]
            if (np.all(neighborhood[y:y+h,x:x+w][component]) and
                np.all(np.ptp(colors,axis=1)<=20) and np.all(colors.min(axis=1)>=55)):
                detached[y:y+h,x:x+w]|=component
        result[detached,3]=0
        remove|=detached
        assert np.array_equal(result[:,:,:3],rgba[:,:,:3])
        assert np.array_equal(result[~remove],rgba[~remove])
        destination=OUTPUT/"images"/source.name
        Image.fromarray(result).save(destination)
        mask=np.zeros_like(rgba);mask[remove]=[255,30,100,255]
        Image.fromarray(mask).save(OUTPUT/(source.stem+"-removed-pixels.png"))
        report["frames"].append({"file":source.name,"source":str(source),
            "source_sha256":frame["output_sha256"],"output":str(destination),"output_sha256":sha(destination),
            "source_native_polygons":POLYGONS.get(key,[]),"removed_pixels":int(remove.sum()),"rgb_changes":0})
        assert sha(source)==frame["output_sha256"]
    (OUTPUT/"contact-report.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"frames":len(frames),"removed_pixels":sum(f["removed_pixels"] for f in report["frames"])}))


if __name__=="__main__":
    main()
