#!/usr/bin/env python3
"""Alternative review-only shadow reconstruction for known damaged card ink.

Requires visual review; opaque repairs cannot be proved correct without the
pre-key original. Never writes to assets/cards/layered or the default branch.
"""
from pathlib import Path
from PIL import Image
import numpy as np
from scipy import ndimage as ndi
import json
ROOT=Path("assets/cards/layered")
OUTPUT=Path("card_shadow_ink_review")
OUTPUT.mkdir(exist_ok=True)
logs=[]
for stem in ["hell_mantis","skeleton_cavalry"]:
    with Image.open(ROOT/(stem+".webp")) as img:
        original=np.array(img.convert("RGBA"))
    rgb=original[:,:,:3]
    alpha=original[:,:,3]
    body=alpha>24
    holes=ndi.binary_fill_holes(body)&(~body)
    groups,n=ndi.label(holes)
    areas=np.bincount(groups.ravel())
    # Restore only completely enclosed transparent interior islands of
    # moderate size. Exterior openings, leg gaps and large silhouette
    # breaks remain untouched. Some enclosed holes may still be intended:
    # **human art review remains mandatory before any asset replacement**.
    repair=(groups>0)&(areas[groups]>=12)&(areas[groups]<=3000)
    _, nearest=ndi.distance_transform_edt(~body,return_indices=True)
    neighbor=rgb[tuple(nearest)].astype(np.float32)
    ink=(neighbor*0.25+np.array([8.0,7.0,5.0])*0.75).astype(np.uint8)
    candidate=original.copy()
    candidate[repair,:3]=ink[repair]
    candidate[repair,3]=255
    candidate_image=Image.fromarray(candidate,"RGBA")
    candidate_image.save(OUTPUT/(stem+"_preview_only.png"),optimize=True)
    candidate_image.save(OUTPUT/(stem+"_preview_only.webp"),format="WEBP",lossless=True,method=6)
    # Light paper background reveals lost outlines much more clearly than
    # the black preview most developers originally reviewed.
    w,h=candidate_image.size
    for label,color in [("paper",(199,169,139,255)),("dark",(35,28,26,255))]:
        bg=Image.new("RGBA",(w,h),color)
        before=Image.alpha_composite(bg,Image.fromarray(original,"RGBA")).convert("RGB")
        after=Image.alpha_composite(bg,candidate_image).convert("RGB")
        duo=Image.new("RGB",(w*2,h))
        duo.paste(before,(0,0))
        duo.paste(after,(w,0))
        duo.thumbnail((1900,1500),Image.Resampling.LANCZOS)
        duo.save(OUTPUT/(stem+"_before_after_"+label+".jpg"),quality=92)
    Image.fromarray((repair*255).astype("uint8")).save(OUTPUT/(stem+"_restored_pixel_mask.png"))
    logs.append({"slug":stem.replace("_","-"),"pixel_changes":int(repair.sum()),
                 "fraction_pct":round(100*float(repair.mean()),4),
                 "status":"Candidate only; original source not recovered; intended holes may be filled"})
(OUTPUT/"review_status.json").write_text(json.dumps(logs,indent=2,ensure_ascii=False),encoding="utf-8")
print("REVIEW_ONLY_INK_CANDIDATES",json.dumps(logs,ensure_ascii=False))
