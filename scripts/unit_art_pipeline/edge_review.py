"""Asset review only: composite RGBA frames on light/dark backgrounds; never alter pixels."""
import argparse,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('folder',type=Path)
    ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    files=sorted(args.folder.glob('*.png'))
    if not files: raise ValueError('No frame PNGs')
    rows=(len(files)+3)//4
    sheet=Image.new('RGB',(1600,rows*220),(72,72,72))
    draw=ImageDraw.Draw(sheet)
    records=[]
    for i,path in enumerate(files):
        im=Image.open(path).convert('RGBA')
        a=im.getchannel('A')
        solid=a.point(lambda v:255 if v>=64 else 0)
        bbox=solid.getbbox()
        if bbox is None: raise ValueError('Empty '+path.name)
        edge=solid.copy()
        import PIL.ImageChops as chops
        edge=chops.subtract(solid,solid.filter(ImageFilter.MinFilter(5)))
        magenta=red=green=total=0
        for rgba,e in zip(im.get_flattened_data(),edge.get_flattened_data()):
            if not e: continue
            total+=1
            r,g,b,alpha=rgba
            if r-g>22 and b-g>22: magenta+=1
            if r-g>35 and r-b>35: red+=1
            if g-r>35 and g-b>35: green+=1
        counts=a.histogram()
        records.append({'name':path.name,'bbox_alpha64':bbox,'transparent_pixels':counts[0],'semi_transparent_pixels':sum(counts[1:255]),'edge_pixels':total,'colored_edge_pixels_advisory':{'magenta':magenta,'red':red,'green':green}})
        padded=(max(0,bbox[0]-8),max(0,bbox[1]-8),min(im.width,bbox[2]+8),min(im.height,bbox[3]+8))
        cut=im.crop(padded)
        cut.thumbnail((184,190),Image.Resampling.LANCZOS)
        x,y=(i%4)*400,(i//4)*220
        for j,bg in enumerate(((240,240,232),(22,24,20))):
            tile=Image.new('RGBA',(200,220),(*bg,255))
            tile.alpha_composite(cut,((200-cut.width)//2,22+(190-cut.height)//2))
            sheet.paste(tile.convert('RGB'),(x+j*200,y))
            draw.text((x+j*200+6,y+4),path.name,fill=(40,40,40) if j==0 else (230,230,230))
    sheet.save(args.output/'edge_review.png')
    (args.output/'edge_review.json').write_text(json.dumps({'source':str(args.folder),'note':'Color counts are advisory: material colors can be legitimate; visual review required. No pixels modified. Cropped thumbnails compare edges, not unit size.','frames':records},indent=2)+'\n',encoding='utf-8')
    print(f'EDGE REVIEW {len(files)} frames -> {args.output}')
if __name__=='__main__': main()
