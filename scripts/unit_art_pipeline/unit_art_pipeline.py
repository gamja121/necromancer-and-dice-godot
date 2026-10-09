"""Deterministic unit-art preparation; does not generate artwork or change game rules."""
import argparse
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from PIL import Image, ImageChops
import PIL

PROJECT = Path(__file__).resolve().parents[2]
MOTIONS = ("attack", "hit", "death")
RESAMPLE = Image.Resampling.LANCZOS

def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def signature(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()

def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))

def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)

def resolve(base, value):
    path = Path(value)
    return (base / path).resolve() if not path.is_absolute() else path.resolve()

def box(image, threshold=64):
    result = image.getchannel("A").point(lambda x: 255 if x >= threshold else 0).getbbox()
    if result is None:
        raise ValueError("Empty or fully transparent frame")
    return result

def rgba(path):
    with Image.open(path) as image:
        if "A" not in image.getbands():
            raise ValueError(f"True alpha channel required: {path}; remove the background before this pipeline.")
        return image.convert("RGBA")

def checked_crop(image, rect):
    x, y, w, h = map(int, rect)
    if min(x, y) < 0 or min(w, h) <= 0 or x+w > image.width or y+h > image.height:
        raise ValueError(f"Crop outside source: {rect} / {image.size}")
    return image.crop((x, y, x+w, y+h))

def silhouette_cells(sheet, spec, names):
    """Extract independent generated poses without cropping a neighboring grid cell."""
    from collections import deque
    from PIL import ImageFilter
    width, height = sheet.size
    alpha = sheet.getchannel("A").tobytes()
    seen = bytearray(width*height)
    parts = []
    for start in range(width*height):
        if seen[start] or alpha[start] < 64:
            continue
        seen[start] = 1
        pending = deque([start])
        pixels = []
        left,right,top,bottom = width,-1,height,-1
        while pending:
            at = pending.popleft()
            x,y = at%width,at//width
            pixels.append(at)
            left,right,top,bottom = min(left,x),max(right,x),min(top,y),max(bottom,y)
            for neighbor in (at-1,at+1,at-width,at+width):
                if 0<=neighbor<width*height and abs(neighbor%width-x)<=1 and not seen[neighbor] and alpha[neighbor]>=64:
                    seen[neighbor]=1
                    pending.append(neighbor)
        if len(pixels)>=int(spec.get("min_component_pixels",500)):
            parts.append((left,top,right+1,bottom+1,pixels))
    columns,rows = map(int,spec.get("grid",[5,5]))
    if len(parts)!=len(names):
        raise ValueError(f"Expected {len(names)} independent poses, found {len(parts)}; check touching sprites or disconnected limbs")
    ordered=[]
    grounded = spec.get("row_grouping") == "grounded_bottom"
    ranked = sorted(parts,key=lambda p:p[3]) if grounded else []
    for row in range(rows):
        group = ranked[row*columns:(row+1)*columns] if grounded else [p for p in parts if int(((p[1]+p[3])/2)/(height/rows))==row]
        group.sort(key=lambda p:p[0])
        if len(group)!=columns:
            raise ValueError(f"Generated row {row+1} has {len(group)} silhouettes instead of {columns}")
        ordered.extend(group)
    order=spec.get("order",list(range(1,len(names)+1)))
    prepared=tuple(map(int,spec["prepared_canvas"]))
    floor=int(spec["prepared_floor"])
    if not 0<floor<=prepared[1] or prepared[0]<width/columns:
        raise ValueError("Invalid prepared_canvas/prepared_floor")
    cells={}
    for name,index in zip(names,order):
        left,top,right,bottom,pixels=ordered[int(index)-1]
        crop=(max(0,left-4),max(0,top-4),min(width,right+4),min(height,bottom+4))
        cut=sheet.crop(crop)
        mask_bytes=bytearray(cut.width*cut.height)
        for at in pixels:
            x,y=at%width-crop[0],at//width-crop[1]
            mask_bytes[y*cut.width+x]=255
        # Preserve a two-pixel antialias fringe; exclude every other silhouette.
        mask=Image.frombytes("L",cut.size,bytes(mask_bytes)).filter(ImageFilter.MaxFilter(5))
        cut.putalpha(ImageChops.multiply(cut.getchannel("A"),mask))
        column=(int(index)-1)%columns
        offset=(round(crop[0]-column*(width/columns)+(prepared[0]-width/columns)/2),
                floor-(bottom-crop[1]))
        safe=box(cut,16)
        if safe[0]+offset[0]<2 or safe[1]+offset[1]<2 or safe[2]+offset[0]>prepared[0]-2 or safe[3]+offset[1]>prepared[1]-2:
            raise ValueError(f"{name}: silhouette exceeds prepared_canvas; increase padding/canvas")
        cell=Image.new("RGBA",prepared)
        cell.paste(cut,offset)
        cells[name]=cell
    print(f"SILHOUETTES {len(cells)}; grounded source alignment enabled; grid x motion preserved")
    return cells


def context(args):
    config_path = Path(args.config).resolve()
    cfg = read_json(config_path)
    slug = cfg["slug"]
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug):
        raise ValueError("slug must be a safe game unit name")
    out = Path(args.output).resolve() if args.output else PROJECT / "source_assets" / "unit_art_pipeline" / slug
    ignored = PROJECT / "source_assets"
    if out == PROJECT or (PROJECT in out.parents and out != ignored and ignored not in out.parents):
        raise ValueError("Build output must be outside runtime assets; use source_assets or an external work directory")
    spec = cfg["input"]
    counts = spec["counts"]
    if set(counts) != set(MOTIONS) or any(not isinstance(counts[m], int) or counts[m] <= 0 for m in MOTIONS):
        raise ValueError("counts must contain positive attack/hit/death counts")
    canvas = cfg["output"]["canvas"]
    if len(canvas) != 2 or min(canvas) < 1:
        raise ValueError("Invalid output canvas")
    impact = cfg.get("timing", {}).get("impact_frame", math.ceil(counts["attack"]/2))
    if not isinstance(impact, int) or not 1 <= impact <= counts["attack"]:
        raise ValueError("impact_frame is outside attack sequence")
    for field, motion in (("attack_delays","attack"),("death_delays","death")):
        values = cfg.get("timing", {}).get(field)
        if values is not None and (not isinstance(values,list) or len(values)!=counts[motion] or any(not isinstance(v,(int,float)) or v<=0 for v in values)):
            raise ValueError(f"{field} must match its motion count and contain positive seconds")
    interval = cfg.get("timing", {}).get("hit_interval",0.135)
    if not isinstance(interval,(int,float)) or interval<=0:
        raise ValueError("hit_interval must be positive")
    base = config_path.parent
    source = resolve(base, spec["path"])
    names = [f"{motion}-{i:02d}.png" for motion in MOTIONS for i in range(1, counts[motion]+1)]
    inputs = {}
    if spec["mode"] == "frames":
        for name in names:
            path = source / name
            inputs[str(path)] = digest(path)
    elif spec["mode"] == "sheet":
        inputs[str(source)] = digest(source)
    else:
        raise ValueError("input.mode must be frames or sheet")
    for name, override in cfg.get("overrides", {}).items():
        if name + ".png" not in names:
            raise ValueError(f"Unknown override frame: {name}")
        path = resolve(base, override["path"])
        inputs[str(path)] = digest(path)
    enhancement = cfg.get("enhance", {})
    tool = Path(args.upscaler).resolve() if args.upscaler else None
    tool_key = {}
    if enhancement.get("enabled", False):
        if not tool or not tool.is_file():
            raise ValueError("enhance.enabled requires --upscaler pointing to an existing local executable")
        model = enhancement.get("model", "realesrgan-x4plus")
        models = Path(args.models).resolve() if args.models else tool.parent / "models"
        if not re.fullmatch(r"[a-zA-Z0-9_-]+", model):
            raise ValueError("Invalid model name")
        tool_key = {"executable": digest(tool), "model": model,
                    "bin": digest(models / (model+".bin")), "param": digest(models / (model+".param"))}
    key = signature({"schema":1, "pipeline":digest(__file__), "config":cfg, "inputs":inputs, "tool":tool_key, "pillow":PIL.__version__})
    return cfg, base, source, out, names, inputs, key, tool_key

def prepare(cfg, base, source, out, names, inputs):
    folder = out / "prepared"
    folder.mkdir(parents=True, exist_ok=True)
    previous = read_json(out / "prepare_cache.json") if (out / "prepare_cache.json").exists() else {}
    cache = {}
    sheet = rgba(source) if cfg["input"]["mode"] == "sheet" else None
    spec = cfg["input"]
    if sheet:
        columns, rows = map(int, spec.get("grid", [5,5]))
        if min(columns, rows) < 1 or sheet.width % columns or sheet.height % rows:
            raise ValueError("Sheet dimensions must divide exactly by input.grid; use rects for irregular sheets")
        order = spec.get("order", list(range(1,len(names)+1)))
        if len(order) != len(names):
            raise ValueError("order length must match all motion counts")
        cell = (sheet.width//columns, sheet.height//rows)
    segmented = silhouette_cells(sheet,spec,names) if sheet and spec.get("segmentation")=="alpha_components" else None
    reused = 0
    for i, name in enumerate(names):
        rect = None
        if sheet:
            rect = spec.get("rects", {}).get(name[:-4])
            if rect is None:
                index = int(order[i])-1
                if not 0 <= index < columns*rows:
                    raise ValueError("Sheet order index outside grid")
                rect = [index%columns*cell[0], index//columns*cell[1], *cell]
            input_path = source
        else:
            input_path = source / name
        override = cfg.get("overrides", {}).get(name[:-4])
        if override:
            input_path = resolve(base, override["path"])
        item_key = signature({"hash":inputs[str(input_path)], "crop":rect, "override":override, "segmentation":{k:spec.get(k) for k in ("segmentation","prepared_canvas","prepared_floor","min_component_pixels","row_grouping")}})
        dest = folder / name
        old = previous.get(name, {})
        if old.get("key") == item_key and dest.exists() and digest(dest) == old.get("sha256"):
            reused += 1
        else:
            image = rgba(input_path)
            if override:
                if override.get("crop"):
                    image = checked_crop(image, override["crop"])
                if sheet:
                    expected = segmented[name].size if segmented else (int(rect[2]), int(rect[3]))
                else:
                    with Image.open(source / name) as original:
                        expected = original.size
                if image.size != expected:
                    if "paste" not in override:
                        raise ValueError(f"{name}: override must match source cell or specify an explicit paste offset")
                    cell_image = Image.new("RGBA", expected)
                    x,y = map(int, override["paste"])
                    if x < 0 or y < 0 or x+image.width > expected[0] or y+image.height > expected[1]:
                        raise ValueError(f"{name}: override does not fit source cell")
                    cell_image.paste(image, (x,y))
                    image = cell_image
            elif sheet:
                image = segmented[name] if segmented else checked_crop(image, rect)
            box(image)
            if not sheet and not override:
                shutil.copy2(input_path, dest)
            else:
                image.save(dest)
        cache[name] = {"key":item_key, "sha256":digest(dest)}
    write_json(out / "prepare_cache.json", cache)
    print(f"PREPARE {len(names)} frames; reused {reused}")
    return folder

def enhance(cfg, args, folder, out, names, tool_key):
    if not cfg.get("enhance", {}).get("enabled", False):
        print("ENHANCE skipped: existing pixels retained")
        return None
    spec = cfg["enhance"]
    model = spec.get("model", "realesrgan-x4plus")
    tool = Path(args.upscaler).resolve()
    models = Path(args.models).resolve() if args.models else tool.parent / "models"
    cache_dir = out / "enhanced"
    cache_dir.mkdir(parents=True, exist_ok=True)
    old = read_json(out / "enhance_cache.json") if (out / "enhance_cache.json").exists() else {}
    cache = {}
    missing = []
    for name in names:
        key = signature({"source":digest(folder/name), "tool":tool_key, "scale":4})
        target = cache_dir / name
        record = old.get(name,{})
        if record.get("key") == key and target.exists() and digest(target) == record.get("sha256"):
            cache[name] = record
        else:
            missing.append((name,key))
    if missing:
        job = out / "jobs" / dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
        incoming, outgoing = job / "input", job / "output"
        incoming.mkdir(parents=True)
        outgoing.mkdir()
        for name,_ in missing:
            image = rgba(folder / name)
            background = Image.new("RGBA", image.size, (24,24,24,255))
            Image.alpha_composite(background,image).convert("RGB").save(incoming / name)
        command = [str(tool), "-i",str(incoming),"-o",str(outgoing),"-m",str(models),
                   "-n",model,"-s","4","-t","128","-g",str(args.gpu),"-j","1:2:1","-f","png"]
        with (job / "upscale.log").open("w",encoding="utf-8") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, cwd=tool.parent)
        if result.returncode:
            raise RuntimeError(f"Upscale failed; see {job / 'upscale.log'}")
        for name,key in missing:
            with Image.open(outgoing / name) as image:
                with Image.open(folder/name) as original:
                    if image.size != (original.width*4, original.height*4):
                        raise ValueError(f"Unexpected upscale dimensions: {name}")
            shutil.copy2(outgoing/name,cache_dir/name)
            cache[name] = {"key":key,"sha256":digest(cache_dir/name)}
            write_json(out / "enhance_cache.json", cache | {k:v for k,v in old.items() if k not in cache})
    write_json(out / "enhance_cache.json", cache)
    print(f"ENHANCE processed {len(missing)}; reused {len(names)-len(missing)}")
    return cache_dir

def intact(manifest, out):
    artifacts = manifest.get("artifacts", {})
    return bool(artifacts) and all((out/name).is_file() and digest(out/name)==sha for name,sha in artifacts.items())

def pack(cfg, folder, enhanced, out, names, inputs, key):
    spec = cfg["output"]
    canvas = tuple(map(int,spec["canvas"]))
    preserve = spec.get("preserve",False)
    floor = int(spec["floor"])
    desired = int(spec["body_height"])
    first = rgba(folder / names[0])
    first_box = box(first)
    if not 0 < floor <= canvas[1] or not 0 < desired <= canvas[1]:
        raise ValueError("Invalid body_height/floor")
    if preserve:
        if first.size != canvas or first_box[3]-first_box[1] != desired or first_box[3] != floor:
            raise ValueError("Preserve mode requires exact canvas, idle body height and floor; use preserve:false to normalize")
        factor, origin = 1.0, (0,0)
    else:
        factor = None
        for adjustment in (0,-1,1,-2,2,-3,3):
            candidate = (desired+adjustment)/(first_box[3]-first_box[1])
            scaled = first.resize((max(1,round(first.width*candidate)),max(1,round(first.height*candidate))),RESAMPLE)
            bounds = box(scaled)
            if bounds[3]-bounds[1] == desired:
                factor = candidate
                break
        if factor is None:
            raise ValueError("Unable to produce the exact idle body height with shared scale")
        source_anchor = spec.get("source_anchor",[(first_box[0]+first_box[2])/2, first_box[3]])
        target_anchor = spec.get("target_anchor",[canvas[0]/2,floor])
        origin = (round(target_anchor[0]-source_anchor[0]*factor), round(target_anchor[1]-source_anchor[1]*factor))
        # Maintain one translation for every pose, including jumps and lunges.
        bounds = []
        for name in names:
            image = rgba(folder/name)
            if image.size != first.size:
                raise ValueError("All source frames must use the same canvas; align an irregular source before packing")
            image = image.resize((max(1,round(image.width*factor)),max(1,round(image.height*factor))),RESAMPLE)
            bounds.append(box(image,16))
        if "source_anchor" not in spec and "target_anchor" not in spec:
            idle_scaled = first.resize((max(1,round(first.width*factor)),max(1,round(first.height*factor))),RESAMPLE)
            origin = (origin[0], floor-box(idle_scaled)[3])
        minimum, maximum = 2-min(b[0] for b in bounds), canvas[0]-2-max(b[2] for b in bounds)
        if minimum > maximum:
            raise ValueError("Sequence cannot fit at requested body height; increase canvas width, do not shrink individual poses")
        origin = (min(max(origin[0],minimum),maximum),origin[1])
    frames = out / "frames"
    frames.mkdir(parents=True,exist_ok=True)
    columns = int(spec.get("sheet_columns",5))
    if columns <= 0:
        raise ValueError("sheet_columns must be positive")
    rows = math.ceil(len(names)/columns)
    sheet = Image.new("RGBA",(columns*canvas[0],rows*canvas[1]))
    records, artifacts = [], {}
    for i,name in enumerate(names):
        image = rgba(folder/name)
        if image.size != first.size:
            raise ValueError(f"Inconsistent source canvas: {name}")
        size = (max(1,round(image.width*factor)),max(1,round(image.height*factor)))
        image = image.resize(size,RESAMPLE) if size!=image.size else image
        if enhanced:
            with Image.open(enhanced/name) as up:
                detail = up.convert("RGB").resize(size,RESAMPLE)
            blend = float(cfg["enhance"].get("blend",0.7))
            if not 0 <= blend <= 1:
                raise ValueError("enhance.blend must be between 0 and 1")
            detail = Image.blend(image.convert("RGB"),detail,blend).convert("RGBA")
            detail.putalpha(image.getchannel("A"))
            image = detail
        b = box(image,16)
        placed = (b[0]+origin[0],b[1]+origin[1],b[2]+origin[0],b[3]+origin[1])
        if min(placed[:2]) < 2 or placed[2] > canvas[0]-2 or placed[3] > canvas[1]-2:
            raise ValueError(f"Visible clipping in {name}: {placed}; fix source padding or shared canvas")
        cell = Image.new("RGBA",canvas)
        cell.paste(image,origin)
        target = frames/name
        if preserve and not enhanced:
            shutil.copy2(folder/name,target)
        else:
            cell.save(target)
        saved = rgba(target)
        if ImageChops.difference(saved,cell).getbbox(alpha_only=False):
            raise ValueError(f"PNG round-trip changed pixels: {name}")
        position = (i%columns*canvas[0],i//columns*canvas[1])
        sheet.paste(saved,position)
        if ImageChops.difference(sheet.crop((*position,position[0]+canvas[0],position[1]+canvas[1])),saved).getbbox(alpha_only=False):
            raise ValueError("Atlas packing changed frame pixels")
        bounds = box(saved)
        records.append({"name":name,"sha256":digest(target),"bbox":list(bounds),"sheet_xy":list(position)})
        artifacts["frames/"+name] = digest(target)
    body = records[0]["bbox"]
    if body[3]-body[1] != desired or body[3]!=floor:
        raise ValueError(f"Idle body/floor differs from configured values: {body}")
    if spec.get("decay_monotonic",False):
        previous, last = records[-2]["bbox"],records[-1]["bbox"]
        if last[2]-last[0]>previous[2]-previous[0]+2 or last[3]-last[1]>previous[3]-previous[1]+2:
            raise ValueError("Final corpse footprint grows")
    sheet_path = out / (cfg["slug"]+"_sheet.png")
    sheet.save(sheet_path)
    with Image.open(sheet_path) as reload:
        if ImageChops.difference(reload.convert("RGBA"),sheet).getbbox(alpha_only=False):
            raise ValueError("Saved sheet differs from packed pixels")
    preview = Image.alpha_composite(Image.new("RGBA",sheet.size,(32,35,28,255)),sheet)
    preview.thumbnail((1600,1200),RESAMPLE)
    preview.save(out/"contact_preview.png")
    artifacts[sheet_path.name] = digest(sheet_path)
    artifacts["contact_preview.png"] = digest(out/"contact_preview.png")
    manifest = {"schema":1,"stage":"review_ready","slug":cfg["slug"],"build_key":key,
                "created_utc":dt.datetime.now(dt.timezone.utc).isoformat(),"counts":cfg["input"]["counts"],
                "canvas":list(canvas),"body_height":desired,"floor":floor,"factor":factor,"origin":list(origin),
                "timing":cfg.get("timing",{}),"records":records,"inputs":inputs,"artifacts":artifacts,
                "game_assets_modified":False,"visual_review_required":["anatomy","pose continuity","attack contact","decay"]}
    write_json(out/"manifest.json",manifest)
    print(f"PACK {len(names)} frames -> {sheet.size}; body={desired}; shared scale={factor:.6f}")
    return manifest

def build(args):
    cfg,base,source,out,names,inputs,key,tool_key = context(args)
    out.mkdir(parents=True,exist_ok=True)
    (out/".gdignore").touch()
    previous = read_json(out/"manifest.json") if (out/"manifest.json").exists() else {}
    if previous.get("build_key")==key and intact(previous,out):
        print("CACHE HIT: prepared frames, enhancement and packing skipped")
        return previous,out
    folder = prepare(cfg,base,source,out,names,inputs)
    enhanced = enhance(cfg,args,folder,out,names,tool_key)
    manifest = pack(cfg,folder,enhanced,out,names,inputs,key)
    print(f"REVIEW {out / 'contact_preview.png'}")
    print(f"APPROVAL KEY {key}")
    return manifest,out

def engine(args):
    path = args.godot or os.environ.get("UNIT_ART_GODOT")
    if not path or not Path(path).is_file():
        raise ValueError("Pass --godot or set UNIT_ART_GODOT to the local Godot executable")
    return str(Path(path).resolve())

def preview(args, manifest, out):
    executable = engine(args)
    project = out/"preview_project"
    project.mkdir(exist_ok=True)
    (project/".gdignore").write_text("",encoding="utf-8")
    (project/"project.godot").write_text('config_version=5\n[application]\nconfig/name="Unit Art Preview"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding="utf-8")
    subprocess.Popen([executable,"--path",str(project),"--script",str(Path(__file__).with_name("preview.gd")),
                      "--log-file",str(out/"preview.log"),"--",str(out/"manifest.json")],cwd=project)
    print("PREVIEW opened native Godot window")

def install(args):
    if not args.approved_key:
        raise ValueError("Install requires --approved-key copied from the visually reviewed manifest")
    executable = engine(args) # Validate before touching runtime files.
    cfg,_,_,out,_,_,key,_ = context(args)
    manifest = read_json(out/"manifest.json")
    if manifest["build_key"]!=key or key!=args.approved_key or not intact(manifest,out):
        raise ValueError("Source/config/output changed after review; build and inspect the new candidate")
    if not args.archive:
        raise ValueError("--archive is required; point to the original-art archive outside the active project")
    archive = Path(args.archive).resolve()
    if archive==PROJECT or PROJECT in archive.parents:
        raise ValueError("Archive must be outside the active Godot checkout")
    backup = archive / cfg["slug"] / dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
    backup.mkdir(parents=True)
    destination = PROJECT/"assets"/"battle"/"frames"/cfg["slug"]
    metadata_path = PROJECT/"data"/"battle_visual_metrics.json"
    metadata_text = metadata_path.read_text(encoding="utf-8-sig")
    metadata = json.loads(metadata_text)
    if cfg["slug"] not in metadata:
        raise ValueError("Unknown game unit; define the unit separately before installing art")
    profile = dict(metadata[cfg["slug"]])
    profile.update(width=manifest["canvas"][0],height=manifest["canvas"][1],
                   top=manifest["records"][0]["bbox"][1],bottom=manifest["records"][0]["bbox"][3]-1)
    for motion in MOTIONS:
        profile[motion]=list(range(1,manifest["counts"][motion]+1))
    # Old per-frame timing arrays may no longer match the new sequence.
    for field in ("attack_delays","hit_interval","death_delays","impact_frame"):
        profile.pop(field,None)
        if field in manifest["timing"]:
            profile[field]=manifest["timing"][field]
    pattern = re.compile(r'"'+re.escape(cfg["slug"])+r'":\s*\{[^}]*\}')
    if len(pattern.findall(metadata_text))!=1:
        raise ValueError("Cannot locate a unique visual metadata profile")
    rendered = json.dumps(profile,ensure_ascii=False,indent=2).replace("\n","\n  ")
    updated = pattern.sub(lambda _: '"'+cfg["slug"]+'": '+rendered,metadata_text,count=1)
    check = json.loads(updated)
    if any(check[k]!=metadata[k] for k in metadata if k!=cfg["slug"]):
        raise ValueError("Another unit profile unexpectedly changed")
    if destination.exists():
        shutil.copytree(destination,backup/"previous_frames")
    shutil.copy2(metadata_path,backup/"metrics_before.json")
    shutil.copytree(out/"frames",backup/"approved_frames")
    shutil.copy2(out/"manifest.json",backup/"approved_manifest.json")
    shutil.copy2(out/(cfg["slug"]+"_sheet.png"),backup/"approved_sheet.png")
    existed = {r["name"]:(destination/r["name"]).exists() for r in manifest["records"]}
    destination.mkdir(parents=True,exist_ok=True)
    try:
        for record in manifest["records"]:
            name = record["name"]
            temp = destination/(name+".tmp")
            shutil.copy2(out/"frames"/name,temp)
            os.replace(temp,destination/name)
        temporary = metadata_path.with_suffix(".json.tmp")
        temporary.write_text(updated,encoding="utf-8")
        os.replace(temporary,metadata_path)
        log_path = out/"install_import.log"
        with log_path.open("w",encoding="utf-8") as log:
            result = subprocess.run([executable,"--headless","--editor","--path",str(PROJECT),"--import"],
                                    stdout=log,stderr=subprocess.STDOUT)
        log_text = log_path.read_text(encoding="utf-8",errors="replace")
        if result.returncode or "SCRIPT ERROR:" in log_text or "ERROR:" in log_text:
            raise RuntimeError(f"Godot import failed: {log_path}")
        if any(digest(destination/r["name"])!=r["sha256"] for r in manifest["records"]):
            raise RuntimeError("Installed hash mismatch")
    except Exception:
        for name,was_present in existed.items():
            if was_present:
                shutil.copy2(backup/"previous_frames"/name,destination/name)
            else:
                (destination/name).unlink(missing_ok=True)
        shutil.copy2(backup/"metrics_before.json",metadata_path)
        raise
    write_json(out/"installation.json",{"build_key":key,"backup":str(backup),"installed_utc":dt.datetime.now(dt.timezone.utc).isoformat(),
                                      "count":len(manifest["records"]),"godot_import":"passed"})
    print(f"INSTALLED {cfg['slug']}; backup={backup}")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=["build","preview","install","status"])
    parser.add_argument("--config",required=True)
    parser.add_argument("--output")
    parser.add_argument("--godot")
    parser.add_argument("--upscaler")
    parser.add_argument("--models")
    parser.add_argument("--gpu",type=int,default=0)
    parser.add_argument("--approved-key")
    parser.add_argument("--archive")
    args = parser.parse_args()
    if args.action=="install":
        install(args)
    elif args.action=="status":
        cfg,base,source,out,names,inputs,key,tool_key = context(args)
        manifest = read_json(out/"manifest.json") if (out/"manifest.json").exists() else {}
        print(json.dumps({"slug":cfg["slug"],"output":str(out),"review_ready":manifest.get("build_key")==key and intact(manifest,out),
                          "build_key":key,"enhance":cfg.get("enhance",{}).get("enabled",False)},ensure_ascii=False,indent=2))
    else:
        manifest,out = build(args)
        if args.action=="preview":
            preview(args,manifest,out)

if __name__=="__main__":
    try:
        main()
    except (ValueError,KeyError,OSError,RuntimeError,subprocess.SubprocessError) as error:
        print(f"STOP: {error}",file=sys.stderr)
        sys.exit(1)
