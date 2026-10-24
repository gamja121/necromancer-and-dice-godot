#!/usr/bin/env python3
"""Create review-only, conservative pinhole fixes for two known bad cut-outs.

Do NOT alter the repository original. Only restore isolated transparent islands
fully surrounded by mostly dark opaque neighbors. Do NOT close open cavities,
wings, bone gaps, cutout silhouettes, or large transparent holes.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
from scipy import ndimage as ndi
import json

OUTPUT=Path("card_repair_candidates")
OUTPUT.mkdir(exist_ok=True)
names=["hell_mantis","skeleton_cavalry"]
report=[]
for stem in names:
    source=Path("assets/cards/layered")/(stem+".webp")
    original=Image.open(source).convert("RGBA")
    a=np.array(original).copy()
    rgb=a[:,:,:3]
    alpha=a[:,:,3]
    # Alpha mask at a low threshold prevents partial-alpha antialias from
    # being mistaken for a detached fully transparent pinhole.
    body=alpha>=24
    holes=ndi.binary_fill_holes(body) & (~body)
    labels,n=ndi.label(holes)
    bounds=ndi.find_objects(labels)
    accepted=np.zeros(holes.shape,dtype=bool)
    candidates=[]
    for i,bbox in enumerate(bounds,1):
        if bbox is None: continue
        component=(labels[bbox]==i)
        area=int(component.sum())
        if area<1 or area>25: continue
        sy,sx=bbox
        ext=(slice(max(0,sy.start-3),min(a.shape[0],sy.stop+3)),
             slice(max(0,sx.start-3),min(a.shape[1],sx.stop+3)))
        local=(labels[ext]==i)
        surround=ndi.binary_dilation(local,iterations=2) & (~local) & (alpha[ext]>224)
        sample=rgb[ext][surround]
        if len(sample)<8: continue
        luminance=sample[:,0]*.2126+sample[:,1]*.7152+sample[:,2]*.0722
        # Only fill tiny pinholes inside almost-black ink regions. Better to
        # miss a damaged stroke than cover a deliberately missing part.
        darkness=float(np.mean(luminance<95))
        if darkness<0.75: continue
        median=np.median(sample,axis=0).astype(np.uint8)
        # Fully isolated pixels are treated as restoration of existing ink.
        local_mask=accepted[ext]
        local_mask[local]=True
        candidates.append({"area":area,"position":[int(sx.start),int(sy.start)],"surround_dark_pct":round(darkness*100,1)})
    restored=a.copy()
    # Filled pixels inherit the local opaque dark ink color, not a hard-coded
    # artificial black stroke. Preserve every pixel not explicitly accepted.
    changed=0
    ys,xs=np.nonzero(accepted)
    for y,x in zip(ys,xs):
        around=rgb[max(0,y-2):y+3,max(0,x-2):x+3]
        around_a=alpha[max(0,y-2):y+3,max(0,x-2):x+3]
        usable=around[around_a>=224]
        if not len(usable):continue
        color=np.median(usable,axis=0).astype(np.uint8)
        restored[y,x,:3]=color
        restored[y,x,3]=255
        changed+=1
    candidate=Image.fromarray(restored,"RGBA")
    candidate.save(OUTPUT/(stem+"_candidate.png"),optimize=True)
    # Checker and dark-paper comparison. Magnification keeps thin edges visible.
    w,h=original.size
    check=Image.new("RGBA",(w,h),(200,171,139,255))
    base=Image.alpha_composite(check,original).convert("RGB")
    fixed=Image.alpha_composite(check,candidate).convert("RGB")
    dark=Image.new("RGBA",(w,h),(35,28,26,255))
    before_dark=Image.alpha_composite(dark,original).convert("RGB")
    after_dark=Image.alpha_composite(dark,candidate).convert("RGB")
    pages=[]
    for first,second in [(base,fixed),(before_dark,after_dark)]:
        compare=Image.new("RGB",(w*2,h),(250,248,244))
        compare.paste(first,(0,0));compare.paste(second,(w,0))
        compare.thumbnail((1900,1500),Image.Resampling.LANCZOS)
        pages.append(compare)
    pages[0].save(OUTPUT/(stem+"_before_after_light.jpg"),quality=93)
    pages[1].save(OUTPUT/(stem+"_before_after_dark.jpg"),quality=93)
    mask=Image.fromarray((accepted*255).astype(np.uint8),"L")
    mask.save(OUTPUT/(stem+"_repair_mask.png"))
    report.append({
      "slug":stem.replace("_","-"),"pixels_changed":changed,
      "fraction_of_image_pct":round(changed/(w*h)*100,5),
      "isolated_small_holes":len(candidates),
      "untouched_enclosed_holes":int(n-len(candidates)),
      "algorithm":"Only tiny enclosed holes <=25px, dark surrounding ink >=75%; no large/open holes touched",
      "source":str(source),
      "candidate":str(OUTPUT/(stem+"_candidate.png"))
    })
(OUTPUT/"repair_scope.json").write_text(json.dumps(report,indent=2,ensure_ascii=False))
for row in report:print("REPAIR_CANDIDATE",json.dumps(row,ensure_ascii=False))
print("CONSERVATIVE_CARD_REPAIR_COMPLETE",len(report))
