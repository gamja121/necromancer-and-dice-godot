#!/usr/bin/env python3
"""Read-only candidate ink recovery for the 12 highest-priority layered cards.
No image files in assets/ are overwritten. Human approval required before use.
"""
from pathlib import Path
import csv
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SRC=Path("assets/cards/layered")
OUT=Path("card_repair_candidates_12")
OUT.mkdir(exist_ok=True)
NAMES=["hell_mantis","skeleton_cavalry","death_knight","grave_priest",
       "plague_doctor","goblin_chief","scorpion_knight","flesh_golem",
       "ancient_treant","spider_knight","stone_golem","goblin_rider"]
rows=[]
for slug in NAMES:
    original=np.asarray(Image.open(SRC/(slug+".webp")).convert("RGBA")).copy()
    alpha=original[:,:,3]; rgb=original[:,:,:3]
    solid=alpha>=24
    filled=ndi.binary_fill_holes(solid)&(~solid)
    labels,n=ndi.label(filled)
    components=ndi.find_objects(labels)
    masks=[np.zeros_like(solid,dtype=bool),np.zeros_like(solid,dtype=bool)]
    for index,bbox in enumerate(components,1):
        if bbox is None: continue
        sy,sx=bbox
        ys=slice(max(0,sy.start-3),min(alpha.shape[0],sy.stop+3))
        xs=slice(max(0,sx.start-3),min(alpha.shape[1],sx.stop+3))
        local=(labels[ys,xs]==index)
        area=int(local.sum())
        if area>2500:continue
        ring=ndi.binary_dilation(local,iterations=2)&(~local)&(alpha[ys,xs]>=220)
        colors=rgb[ys,xs][ring]
        if len(colors)<4:continue
        light=colors[:,0]*.2126+colors[:,1]*.7152+colors[:,2]*.0722
        ratio=float((light<100).mean());mean=float(light.mean())
        rectangularity=area/max(1,(sy.stop-sy.start)*(sx.stop-sx.start))
        safe=3<=area<=60 and ratio>=.9 and mean<67 and rectangularity>=.25
        review=5<=area<=1700 and ratio>=.75 and mean<86 and rectangularity>=.17
        if safe: masks[0][ys,xs][local]=True
        if review: masks[1][ys,xs][local]=True
    _,idx=ndi.distance_transform_edt(~solid,return_indices=True)
    nearest=original[idx[0],idx[1],:3]
    for mask,label in zip(masks,["safe","review"]):
        candidate=original.copy()
        candidate[mask,:3]=np.minimum(nearest[mask],110).astype(np.uint8)
        candidate[mask,3]=255
        assert np.array_equal(candidate[solid],original[solid])
        Image.fromarray(candidate,"RGBA").save(OUT/(slug+"_"+label+".png"))
    Image.fromarray((masks[1]*255).astype(np.uint8),"L").save(OUT/(slug+"_review_mask.png"))
    rows.append((slug,int(masks[0].sum()),int(masks[1].sum()),round(float(100*masks[1].mean()),4)))
with (OUT/"status.csv").open("w",newline="") as f:
    writer=csv.writer(f);writer.writerow(["slug","safe_pixels","review_pixels","review_pct"])
    writer.writerows(rows)
for row in rows: print("CANDIDATE_12",row)
print("CARD_INK_CANDIDATES_12_COMPLETE",len(rows))
