#!/usr/bin/env python3
"""Read-only alpha audit of every actively mapped monster card portrait.

Flags alpha voids that may have erased dark ink. Does not edit game assets.
Review flagged images visually: intended gaps between limbs can be transparent.
"""
from __future__ import annotations
import csv
import json
import re
from pathlib import Path
import numpy as np
from scipy import ndimage as ndi
from PIL import Image, ImageDraw, ImageFont

ROOT = Path("assets/cards/layered")
OUT = Path("card_alpha_audit")
OUT.mkdir(exist_ok=True)
source = Path("systems/layered_unit_card.gd").read_text(encoding="utf-8")
part = source.split("const PORTRAITS :=", 1)[1].split("const BACKGROUNDS :=", 1)[0]
mapping = dict(re.findall(r'"([^"]+)"\s*:\s*ROOT\s*\+\s*"([^"]+\.webp)"', part))
# Dragon's card renders the actual combat PNG instead of a layered WebP.
mapping["dragon"] = "../../battle/frames/dragon/attack-01.png"
units = json.loads(Path("data/units.json").read_text(encoding="utf-8"))["units"]

try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
except OSError:
    font = ImageFont.load_default()

results = []
for slug, filename in mapping.items():
    path = ROOT / filename
    if not path.exists():
        results.append({"slug": slug, "name": units.get(slug,{}).get("name",""), "file":filename,"error":"missing"})
        continue
    with Image.open(path) as src:
        rgba = np.asarray(src.convert("RGBA"))
        alpha = rgba[:,:,3]
    height,width = alpha.shape
    opaque = alpha>=32
    rgba_mask = alpha>0
    ys,xs = np.where(rgba_mask)
    if not len(xs):
        results.append({"slug":slug,"name":units.get(slug,{}).get("name",""),"file":filename,"error":"empty alpha"})
        continue
    x1,x2,y1,y2 = int(xs.min()),int(xs.max())+1,int(ys.min()),int(ys.max())+1
    crop = opaque[y1:y2, x1:x2]
    bbox_area = crop.size
    transparent = ~crop
    sealed = ndi.binary_fill_holes(crop) & transparent
    labels,n=ndi.label(sealed)
    areas = np.bincount(labels.ravel())[1:]
    meaningful = np.where(areas>=6)[0]+1
    sealed_count = int(sealed.sum())
    tiny_count = int(((areas >= 6) & (areas < 100)).sum())
    big_count = int((areas>=100).sum())
    central = np.zeros_like(crop, dtype=bool)
    ch,cw = crop.shape
    central[int(ch*.15):int(ch*.85),int(cw*.15):int(cw*.85)] = True
    # Very narrow transparent scratches can still connect to the exterior.
    # Closing only narrow channels is a heuristic; not evidence of error.
    narrow = (ndi.binary_closing(crop,iterations=3) & transparent) & central
    narrow_not_sealed = narrow & ~sealed
    boundary = crop & ~ndi.binary_erosion(crop)
    inner_dark_edge = float(((rgba[y1:y2,x1:x2,:3].mean(2)<42)&boundary).sum()/max(1,boundary.sum()))
    metrics = {
      "slug":slug, "name":units.get(slug,{}).get("name",""),"file":filename,
      "width":width,"height":height,"opaque_pct":round(float(opaque.mean()*100),2),
      "bbox_w":x2-x1, "bbox_h":y2-y1,
      "bbox_coverage_pct":round(float(crop.mean()*100),2),
      "enclosed_clear_area_px":sealed_count,
      "enclosed_clear_pct_of_bbox":round(100*sealed_count/bbox_area,4),
      "enclosed_holes_6px_plus":int(len(meaningful)),
      "small_holes_6_to_99px":tiny_count,
      "large_holes_100px_plus":big_count,
      "largest_clear_hole_px":int(areas.max()) if len(areas) else 0,
      "thin_open_gaps_central_px":int(narrow_not_sealed.sum()),
      "dark_edge_pct":round(100*inner_dark_edge,2),
      "has_alpha": bool((alpha<255).any()),
    }
    # Strongly prioritize mistakenly transparent fine-art texture, as it may
    # masquerade as black outline on black backgrounds.
    score = (
       min(60.0, metrics["enclosed_clear_pct_of_bbox"]*12)
       + min(18.0, tiny_count*.65)
       + min(12.0, big_count*2.5)
       + min(10.0, metrics["thin_open_gaps_central_px"]/150.0)
    )
    metrics["flag_score"] = round(score,2)
    if metrics["enclosed_clear_pct_of_bbox"]>=0.35 and metrics["enclosed_holes_6px_plus"]>=5:
        metrics["alpha_flag"]="high"
    elif metrics["enclosed_clear_pct_of_bbox"]>=0.10 or metrics["enclosed_holes_6px_plus"]>=5:
        metrics["alpha_flag"]="review"
    else:
        metrics["alpha_flag"]="low"
    results.append(metrics)

results.sort(key=lambda x: (-x.get("flag_score",0),x["slug"]))
with (OUT/"all_portrait_metrics.csv").open("w",encoding="utf-8-sig",newline="") as f:
    writer=csv.DictWriter(f,fieldnames=list(results[0].keys()),extrasaction="ignore")
    writer.writeheader()
    writer.writerows(results)
(OUT/"all_portrait_metrics.json").write_text(json.dumps(results,indent=2,ensure_ascii=False),encoding="utf-8")

# Diagnostic sheets with alpha/ink-loss candidates highlighted; no source edits.
def make_sheet(items, filename):
    cell_w,cell_h=250,300
    cols=5
    rows=(len(items)+cols-1)//cols
    sheet=Image.new("RGB",(cols*cell_w,rows*cell_h),(38,33,31))
    draw=ImageDraw.Draw(sheet)
    for i,item in enumerate(items):
        if "error" in item: continue
        with Image.open(ROOT/item["file"]) as im:
            src=im.convert("RGBA")
        src.thumbnail((224,244),Image.Resampling.LANCZOS)
        px=i%cols*cell_w+13
        py=i//cols*cell_h+35
        # Checker-light background makes incorrect ink cutouts visible.
        bg=Image.new("RGBA",src.size,(211,190,161,255))
        bg.alpha_composite(src)
        sheet.paste(bg.convert("RGB"),(px+(224-src.width)//2,py+(244-src.height)//2))
        draw.text((i%cols*cell_w+10,i//cols*cell_h+8),f"{item['slug']} ({item['alpha_flag']})",fill=(255,255,238),font=font)
        draw.text((i%cols*cell_w+10,i//cols*cell_h+280),
                  f"holes={item['enclosed_holes_6px_plus']}  fill={item['enclosed_clear_pct_of_bbox']:.2f}%",
                  fill=(230,230,215),font=font)
    sheet.save(OUT/filename,quality=85,optimize=True)

make_sheet(results[:25],"most_suspicious_sheet.jpg")
make_sheet(results[25:],"remaining_portraits_sheet.jpg")
print("AUDIT_TARGET_COUNT",len(results))
print("AUDIT_ALPHA_FLAG_COUNT",sum(x.get("alpha_flag")=="high" for x in results),sum(x.get("alpha_flag")=="review" for x in results))
for x in results:
    print("ALPHA_AUDIT",json.dumps(x,ensure_ascii=False))
print("ALPHA_AUDIT_COMPLETE",len(results))
