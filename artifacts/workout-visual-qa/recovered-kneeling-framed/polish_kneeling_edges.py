"""Bounded candidate-only darker neutral rim unmix for eight reviewed frames.

The source already has the broad reviewed backgrounds removed. This pass never
segments the whole image. It only unmattes a <=3px exterior rim where neutral
pixels are substantially lighter than a dark two-pixel interior sample. All
reviewed shoe rectangles are protected. Source anatomy and frame geometry stay
unchanged. Outputs need individual visual review before any promotion.
"""
from pathlib import Path
import hashlib
import json
import argparse
import cv2
import numpy as np
from scipy.ndimage import distance_transform_edt
from PIL import Image, ImageDraw

QA = Path(__file__).resolve().parent.parent
SOURCE = QA / "recovered-kneeling-framed-v3"
OUTPUT = QA / "recovered-kneeling-framed-v4"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def composite(image, color):
    panel = Image.new("RGBA",image.size,(*color,255))
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
    (OUTPUT/"images").mkdir(parents=True,exist_ok=True)
    (OUTPUT/"diagnostics").mkdir(exist_ok=True)
    sources = json.loads((SOURCE/"edge-refinement-report.json").read_text())["frames"]
    report = {"recipe":"reviewed-dark-neutral-rim-v1", "frames":[],
              "scope":"only <=3px exterior neutral rim; no geometry change; shoe protections unchanged"}
    contact={g:Image.new("RGB",(2048,1536),(12,12,14)) for g in ("male","female")}
    for source_record in sources:
        source=Path(source_record["output"])
        expected=source_record["output_sha256"]
        assert sha(source)==expected
        rgba=np.array(Image.open(source).convert("RGBA"))
        alpha=rgba[:,:,3].astype(np.float32)/255.
        visible=alpha>.03
        interior=cv2.erode(visible.astype(np.uint8),np.ones((5,5),np.uint8))>0
        distance,indices=distance_transform_edt(~interior,return_indices=True)
        rgb=rgba[:,:,:3].astype(np.float32)
        foreground=rgb[indices[0],indices[1]]
        neutral=(rgb.min(axis=2)>=70)&(np.ptp(rgb,axis=2)<=24)
        edge=visible & ~interior & (distance<=3) & neutral
        for left,top,right,bottom in source_record["protected_shoe_boxes"]:
            edge[top:bottom,left:right]=False
        difference=255-foreground
        weights=np.maximum(difference-25,0)
        inferred=np.sum((255-rgb)*weights,axis=2)/np.maximum(np.sum(difference*weights,axis=2),1)
        inferred=np.clip(inferred,0,1)
        accepted=edge & (inferred<.90) & (foreground.min(axis=2)<100) & ((rgb.mean(axis=2)-foreground.mean(axis=2))>25)
        result=rgba.copy()
        result[accepted,:3]=np.rint(foreground[accepted]).astype(np.uint8)
        result[accepted,3]=np.rint(alpha[accepted]*inferred[accepted]*255).astype(np.uint8)
        assert np.array_equal(result[~accepted],rgba[~accepted])
        assert np.all(result[:,:,3]<=rgba[:,:,3])
        for left,top,right,bottom in source_record["protected_shoe_boxes"]:
            assert np.array_equal(result[top:bottom,left:right],rgba[top:bottom,left:right])
        destination=OUTPUT/"images"/source.name
        image=Image.fromarray(result); image.save(destination)
        dark=composite(image,(12,12,14));light=composite(image,(245,245,247))
        preview=Image.new("RGB",(2048,768));preview.paste(dark,(0,0));preview.paste(light,(1024,0))
        preview.save(OUTPUT/(source.stem+"-preview.png"))
        change=rgba.copy();change[accepted,:3]=[255,30,100];change[accepted,3]=255
        composite(Image.fromarray(change),(12,12,14)).save(OUTPUT/"diagnostics"/(source.stem+"-changed.png"))
        gender,index=source.stem.split("_On_Knees_")[1].split("_v2_");index=int(index)
        contact[gender].paste(dark,((index%2)*1024,(index//2)*768))
        ImageDraw.Draw(contact[gender]).text(((index%2)*1024+12,(index//2)*768+12),f"{gender}_{index}",fill=(240,240,240))
        record={"file":source.name,"source":str(source),"source_sha256":expected,
                "output":str(destination),"output_sha256":sha(destination),
                "edge_pixels_changed":int(accepted.sum()),
                "protected_shoe_boxes":source_record["protected_shoe_boxes"],
                "geometry_unchanged":True,"review_status":"pending"}
        assert sha(source)==expected
        report["frames"].append(record)
    for gender,image in contact.items():
        image.resize((1024,768),Image.Resampling.LANCZOS).save(OUTPUT/(gender+"-contact.png"))
    (OUTPUT/"polish-report.json").write_text(json.dumps(report,indent=2)+"\n")
    # Magnified true-alpha composites for the previously identified contact marks.
    for key,box in {"male_3":[870,500,950,550],"female_1":[690,490,775,540],"female_2":[640,495,780,545]}.items():
        gender,index=key.split("_")
        p=OUTPUT/"images"/f"Barbell_Ab_Rollout_-_On_Knees_{gender}_v2_{index}.png"
        crop=Image.open(p).crop(box)
        panel=Image.new("RGB",(crop.width*2,crop.height))
        panel.paste(composite(crop,(12,12,14)),(0,0));panel.paste(composite(crop,(245,245,247)),(crop.width,0))
        panel.resize((panel.width*6,panel.height*6),Image.Resampling.NEAREST).save(OUTPUT/"diagnostics"/(key+"-contact-closeup.png"))
    for key,box in {"male_3":[414,260,449,282],"female_1":[397,259,449,279],"female_2":[403,149,486,177]}.items():
        gender,index=key.split("_")
        p=QA/"recovered-kneeling-shadow-cleanup/images"/f"Barbell_Ab_Rollout_-_On_Knees_{gender}_v2_{index}.png"
        crop=Image.open(p).crop(box)
        panel=composite(crop,(225,225,225)).resize((crop.width*12,crop.height*12),Image.Resampling.NEAREST)
        draw=ImageDraw.Draw(panel)
        for x in range((box[0]+4)//5*5,box[2],5):
            px=(x-box[0])*12
            draw.line((px,0,px,panel.height),fill=(90,70,70),width=1)
            draw.text((px+1,0),str(x),fill=(255,50,100),stroke_width=1,stroke_fill=(0,0,0))
        for y in range((box[1]+4)//5*5,box[3],5):
            py=(y-box[1])*12
            draw.line((0,py,panel.width,py),fill=(90,70,70),width=1)
            draw.text((0,py+1),str(y),fill=(255,50,100),stroke_width=1,stroke_fill=(0,0,0))
        panel.save(OUTPUT/"diagnostics"/(key+"-native-contact-grid.png"))
    print(json.dumps({"output":str(OUTPUT),"frames":len(report["frames"]),"rim_pixels":sum(r["edge_pixels_changed"] for r in report["frames"])}))


if __name__=="__main__":
    main()
