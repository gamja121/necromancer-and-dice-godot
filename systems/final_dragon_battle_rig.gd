extends RefCounted
## Render-only articulated combat rig. The book presentation is a different asset.
const SOURCE := "res://assets/battle/final_dragon/final_dragon.png"
const DEST := "res://assets/battle/frames/dragon"
const CANVAS := Vector2i(1024, 640)
const PICTURE := Vector2(720, 496)
const ORIGIN := Vector2(90, 78)
const SOURCE_RECT := Rect2(305, 9, 1204, 830)
const SOURCE_SIZE := Vector2(1871, 840)
const NECK_PIVOT := Vector2(1210, 378)
const JAW_PIVOT := Vector2(1386, 278)
const JAW := [Vector2(1371,265), Vector2(1408,276), Vector2(1443,288), Vector2(1497,274), Vector2(1493,302), Vector2(1484,319), Vector2(1456,343), Vector2(1434,356), Vector2(1391,327), Vector2(1365,308)]
const COUNTS := {"attack":16, "hit":8, "death":20}
const ATTACK_DELAYS := [0.10,0.08,0.08,0.09,0.08,0.07,0.055,0.055,0.12,0.08,0.08,0.08,0.08,0.08,0.09,0.11]
const HIT_INTERVAL := 0.065
const DEATH_DELAYS := [0.10,0.11,0.12,0.12,0.13,0.13,0.14,0.14,0.15,0.15,0.16,0.16,0.17,0.17,0.18,0.18,0.19,0.19,0.22,0.28]
const IMPACT_FRAME := 9
const SHADER := "
shader_type canvas_item;
uniform int part = 0;
uniform float rot : hint_range(0.0,1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);
}
bool cross_edge(vec2 p,vec2 a,vec2 b) {
 if ((a.y>p.y)==(b.y>p.y)) return false;
 return p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x;
}
bool jaw_at(vec2 p) {
 bool inside=false;
 if(cross_edge(p,vec2(1371,265),vec2(1408,276))) inside=!inside;
 if(cross_edge(p,vec2(1408,276),vec2(1443,288))) inside=!inside;
 if(cross_edge(p,vec2(1443,288),vec2(1497,274))) inside=!inside;
 if(cross_edge(p,vec2(1497,274),vec2(1493,302))) inside=!inside;
 if(cross_edge(p,vec2(1493,302),vec2(1484,319))) inside=!inside;
 if(cross_edge(p,vec2(1484,319),vec2(1456,343))) inside=!inside;
 if(cross_edge(p,vec2(1456,343),vec2(1434,356))) inside=!inside;
 if(cross_edge(p,vec2(1434,356),vec2(1391,327))) inside=!inside;
 if(cross_edge(p,vec2(1391,327),vec2(1365,308))) inside=!inside;
 if(cross_edge(p,vec2(1365,308),vec2(1371,265))) inside=!inside;
 return inside;
}
void fragment() {
 vec4 ink=texture(TEXTURE,UV);
 bool jaw=jaw_at(UV*vec2(1871.0,840.0));
 if ((part==0 && jaw)||(part==1 && !jaw)) ink.a=0.0;
 if(rot>0.0) {
  vec2 q=(UV*vec2(1871.0,840.0)-vec2(305.0,9.0))/vec2(1204.0,830.0);
  float broad=noise(q*vec2(17.0,13.0));
  float fine=noise(q*vec2(89.0,71.0));
  float field=0.62*broad+0.28*fine+0.10*q.y;
  float stain=smoothstep(broad*0.45,broad*0.45+0.24,rot);
  float light=dot(ink.rgb,vec3(0.3,0.59,0.11));
  vec3 rotten=mix(vec3(0.12,0.15,0.055),vec3(0.30,0.22,0.12),fine)*light*2.1;
  ink.rgb=mix(ink.rgb,rotten,stain*0.92);
  float threshold=max(0.0,rot-0.20)*1.40;
  ink.a*=smoothstep(threshold-0.027,threshold+0.027,field);
 }
 COLOR=ink;
}
"
var body: MeshInstance2D
var jaw: MeshInstance2D
var mouth: Polygon2D
var debris: Debris

class Debris:
 extends Node2D
 var progress := 0.0
 func _draw() -> void:
  var amount := smoothstep(0.50,0.98,progress)
  if amount<=0.0: return
  draw_set_transform(Vector2(425,495),0,Vector2(1.0,0.085))
  draw_circle(Vector2.ZERO,210,Color(0.045,0.035,0.015,amount*0.40))
  draw_set_transform(Vector2.ZERO)
  for i in range(23):
   var x := 245.0+float(i)*15.4+sin(float(i)*3.7)*13.0
   var y := 492.0+sin(float(i)*2.4)*5.5
   var point := Vector2(x,y)
   var end := point+Vector2(7.0+float(i%4)*2.0,sin(float(i)*1.9)*5.0)
   draw_line(point,end,Color(0.035,0.030,0.017,amount),4.0,true)
   draw_line(point,end,Color(0.41,0.35,0.20,amount*0.85),1.4,true)

static func smooth(a: float,b: float,t: float) -> float:
 var f := clampf((t-a)/(b-a),0.0,1.0)
 return f*f*(3.0-2.0*f)

static func pose(motion: String,index: int) -> Dictionary:
 if motion=="attack":
  var keys: Array = [
   {"jaw":-18.0},{ "head_x":-8.0,"head_angle":-3.0,"jaw":-16.0},
   {"head_x":-23.0,"head_angle":-6.0,"jaw":-6.0,"lean":-7.0,"wing":-1.0},
   {"head_x":-40.0,"head_angle":-9.0,"jaw":12.0,"lean":-14.0,"wing":-2.0},
   {"head_x":-38.0,"head_angle":-8.0,"jaw":28.0,"lean":-17.0,"wing":-3.0},
   {"head_x":-18.0,"head_angle":-4.0,"jaw":38.0,"lean":-6.0,"wing":-2.0},
   {"head_x":65.0,"head_y":10.0,"head_angle":6.0,"jaw":40.0,"lean":24.0,"wing":2.0},
   {"head_x":158.0,"head_y":18.0,"head_angle":12.0,"jaw":34.0,"lean":48.0,"wing":4.0},
   {"head_x":178.0,"head_y":14.0,"head_angle":8.0,"jaw":-18.0,"lean":54.0,"wing":3.0},
   {"head_x":160.0,"head_y":12.0,"head_angle":7.0,"jaw":-18.0,"lean":48.0,"wing":3.0},
   {"head_x":130.0,"head_y":9.0,"head_angle":5.0,"jaw":-18.0,"lean":38.0,"wing":2.0},
   {"head_x":91.0,"head_y":6.0,"head_angle":3.0,"jaw":-18.0,"lean":27.0,"wing":1.0},
   {"head_x":52.0,"head_y":3.0,"head_angle":1.0,"jaw":-18.0,"lean":15.0},
   {"head_x":24.0,"head_angle":-1.0,"jaw":-18.0,"lean":6.0},
   {"head_x":7.0,"jaw":-18.0},{"jaw":-18.0}
  ]
  return keys[clampi(index,0,keys.size()-1)].duplicate()
 if motion=="hit":
  var keys: Array = [
   {"head_x":-18.0,"head_angle":-9.0,"jaw":0.0,"lean":-7.0},
   {"head_x":-65.0,"head_y":-14.0,"head_angle":-28.0,"jaw":13.0,"lean":-19.0,"wing":-3.0},
   {"head_x":-94.0,"head_y":-20.0,"head_angle":-38.0,"jaw":18.0,"lean":-26.0,"wing":-4.0},
   {"head_x":-80.0,"head_y":-16.0,"head_angle":-32.0,"jaw":10.0,"lean":-22.0,"wing":-3.0},
   {"head_x":-53.0,"head_y":-10.0,"head_angle":-21.0,"jaw":-2.0,"lean":-15.0,"wing":-2.0},
   {"head_x":-26.0,"head_angle":-10.0,"jaw":-12.0,"lean":-7.0},
   {"head_x":-7.0,"head_angle":-3.0,"jaw":-18.0},{"jaw":-18.0}
  ]
  return keys[clampi(index,0,keys.size()-1)].duplicate()
 var t := clampf(float(index)/float(COUNTS.death-1),0.0,1.0)
 return {"head_x":-45.0*smooth(0.0,0.7,t),"head_y":45.0*t,"head_angle":26.0*smooth(0.0,0.65,t),"jaw":lerpf(-18.0,18.0,smooth(0.0,0.5,t)),"wing":-20.0*smooth(0.08,0.8,t),"lean":-35.0*t,"collapse":0.68*smooth(0.15,1.0,t),"rot":t}

static func point(source: Vector2,p: Dictionary,lower_jaw: bool=false) -> Vector2:
 var moved := source
 if lower_jaw:
  moved=JAW_PIVOT+(moved-JAW_PIVOT).rotated(deg_to_rad(float(p.get("jaw",-18.0))))
 var q := (source-SOURCE_RECT.position)/SOURCE_RECT.size
 var head_weight := smooth(0.58,0.76,q.x)*(1.0-smooth(0.35,0.61,q.y))*smooth(0.070,0.11,q.y)
 var turned := NECK_PIVOT+(moved-NECK_PIVOT).rotated(deg_to_rad(float(p.get("head_angle",0.0))))
 turned+=Vector2(float(p.get("head_x",0.0)),float(p.get("head_y",0.0)))
 moved=moved.lerp(turned,head_weight)
 var result := (moved-SOURCE_RECT.position)/SOURCE_RECT.size*PICTURE
 var wing_weight := (1.0-smooth(0.52,0.76,q.x))*(1.0-smooth(0.40,0.70,q.y))
 var wing_pivot := PICTURE*Vector2(0.64,0.47)
 result=wing_pivot+(result-wing_pivot).rotated(deg_to_rad(float(p.get("wing",0.0)))*wing_weight)
 result.x+=float(p.get("lean",0.0))*(1.0-smooth(0.69,0.97,q.y))
 result.y+=(PICTURE.y-result.y)*float(p.get("collapse",0.0))*(1.0-smooth(0.91,1.0,q.y))
 return result

static func mesh(p: Dictionary,lower_jaw: bool=false) -> ArrayMesh:
 var vertices := PackedVector3Array()
 var uv := PackedVector2Array()
 var indices := PackedInt32Array()
 const COLS := 100
 const ROWS := 70
 for row in range(ROWS+1):
  for col in range(COLS+1):
   var q := Vector2(float(col)/COLS,float(row)/ROWS)
   var source := SOURCE_RECT.position+q*SOURCE_RECT.size
   var v := point(source,p,lower_jaw)
   vertices.append(Vector3(v.x,v.y,0))
   uv.append(source/SOURCE_SIZE)
 for row in range(ROWS):
  for col in range(COLS):
   var a := row*(COLS+1)+col
   var b := a+1
   var c := a+COLS+1
   indices.append_array(PackedInt32Array([a,b,c,b,c+1,c]))
 var arrays: Array = []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_TEX_UV]=uv
 arrays[Mesh.ARRAY_INDEX]=indices
 var output := ArrayMesh.new()
 output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return output

func mount(parent: Node) -> void:
 var source := Image.load_from_file(SOURCE)
 var texture := ImageTexture.create_from_image(source)
 var shader := Shader.new()
 shader.code=SHADER
 mouth=Polygon2D.new()
 mouth.position=ORIGIN
 parent.add_child(mouth)
 for part in range(2):
  var node := MeshInstance2D.new()
  node.texture=texture
  node.position=ORIGIN
  var mat := ShaderMaterial.new()
  mat.shader=shader
  mat.set_shader_parameter("part",part)
  node.material=mat
  parent.add_child(node)
  if part==0: body=node
  else: jaw=node
 debris=Debris.new()
 debris.position=ORIGIN
 parent.add_child(debris)

func show_pose(p: Dictionary) -> void:
 body.mesh=mesh(p)
 jaw.mesh=mesh(p,true)
 var corners := PackedVector2Array()
 for item in [Vector2(1370,266),Vector2(1497,273)]:
  corners.append(point(item,p))
 for item in [Vector2(1484,305),Vector2(1448,331),Vector2(1381,298)]:
  corners.append(point(item,p,true))
 mouth.polygon=corners
 var rot := float(p.get("rot",0.0))
 mouth.color=Color(0.045,0.018,0.012,1.0-smooth(0.18,0.80,rot))
 body.material.set_shader_parameter("rot",rot)
 jaw.material.set_shader_parameter("rot",rot)
 debris.progress=rot
 debris.queue_redraw()
