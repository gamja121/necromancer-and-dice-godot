extends RefCounted
## Self-contained brush assets. Runtime SVG rasterization works in Godot
## native and web exports without relying on editor-only SVG importer caches.
## The matching .svg originals under assets/map/ui remain editable source art.
const ICON_SVG = """
<svg xmlns="http://www.w3.org/2000/svg" width="58" height="58" viewBox="0 0 58 58">
<!-- hand-brushed map settings mark: no square button or polished metal -->
<path d="M12 17 Q18 7 29 9 Q41 8 48 19 L51 30 Q49 43 39 49 L25 50 Q12 46 9 34 Q7 24 12 17 Z" fill="#211913" opacity=".76"/>
<path d="M12 23 Q15 14 22 13 M35 11 Q45 15 48 23 M49 33 Q45 45 35 47 M23 48 Q11 43 10 32" fill="none" stroke="#9c7546" stroke-width="3.3" stroke-linecap="round" opacity=".7"/>
<path d="M24 9 L33 8 L34 15 L39 17 L45 14 L49 20 L44 26 L45 31 L50 35 L45 42 L39 39 L34 43 L33 50 L25 49 L24 43 L19 40 L12 43 L9 36 L14 30 L14 25 L10 20 L16 14 L22 18 L25 16 Z" fill="#c6a777" stroke="#493421" stroke-width="2.4" stroke-linejoin="round"/>
<path d="M19 19 Q26 14 33 17 M41 26 L43 31 M18 40 L23 41 M31 46 L34 44" stroke="#f0dfb4" stroke-width="2.3" stroke-linecap="round" opacity=".78" fill="none"/>
<path d="M28 22 Q36 21 37 28 Q38 35 30 37 Q23 38 21 31 Q20 25 28 22 Z" fill="#35281d" stroke="#ead2a0" stroke-width="2.3"/>
<path d="M24 29 Q26 24 32 26" fill="none" stroke="#7f6041" stroke-width="2" stroke-linecap="round"/>
<path d="M8 18 L10 15 M47 44 L50 41 M11 46 L14 48" stroke="#e5c99a" stroke-width="1.6" opacity=".75" stroke-linecap="round"/>
</svg>
"""

const PANEL_SVG = """
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="194" viewBox="0 0 256 194">
<!-- deliberately irregular hand-painted panel, nine-slice friendly 24px edges -->
<path d="M15 7 L52 5 Q102 8 128 5 L195 7 L239 6 L248 16 L250 45 L247 82 L249 143 L246 179 L239 188 L183 187 Q123 190 88 187 L17 189 L7 177 L8 137 L6 103 L9 62 L7 17 Z" fill="#211c17" opacity=".98"/>
<path d="M12 11 Q38 8 73 9 L146 10 Q204 7 242 11 M245 17 Q248 67 244 106 L245 174 M237 184 Q190 182 143 185 L76 184 L17 185 M11 174 L12 111 Q9 62 12 19" fill="none" stroke="#b18d5b" stroke-width="5" stroke-linecap="round" opacity=".78"/>
<path d="M17 14 L106 14 L177 15 L238 15 M241 22 L241 150 M229 179 L152 180 L20 181 M15 159 L16 45" fill="none" stroke="#ead0a0" stroke-width="1.6" stroke-linecap="round" opacity=".68"/>
<path d="M23 22 Q100 21 151 23 L230 22 M232 34 L233 121 M229 169 L152 170 L25 172 M22 151 L23 46" fill="none" stroke="#5d452e" stroke-width="2" opacity=".8"/>
<path d="M17 9 L23 8 M229 10 L237 9 M12 179 L17 185 M239 183 L244 178" stroke="#e5c18c" stroke-width="3.2" stroke-linecap="round" opacity=".85"/>
<path d="M35 30 L99 30 M160 162 L216 162 M36 167 L60 167" stroke="#8b6a43" stroke-width="1.8" stroke-linecap="round" opacity=".22"/>
</svg>
"""

const BUTTON_SVG = """
<svg xmlns="http://www.w3.org/2000/svg" width="84" height="36" viewBox="0 0 84 36">
<path d="M8 4 L45 3 L77 5 L81 11 L80 30 L75 33 L20 32 L5 33 L3 24 L5 8 Z" fill="#3b2c20" opacity=".95"/>
<path d="M9 6 L40 5 L74 7 M78 13 L77 28 M72 31 L30 30 L9 31 M6 27 L7 11" fill="none" stroke="#b38c58" stroke-width="2.5" stroke-linecap="round" opacity=".9"/>
<path d="M13 9 L69 9 M15 27 L68 27" fill="none" stroke="#dbc095" stroke-width="1.2" stroke-linecap="round" opacity=".42"/>
</svg>
"""

static func painted_texture(kind: String) -> ImageTexture:
	var svg: String = ""
	match kind:
		"icon": svg = ICON_SVG
		"panel": svg = PANEL_SVG
		"button": svg = BUTTON_SVG
		_: return null
	var image = Image.new()
	var err: Error = image.load_svg_from_string(svg,2.0)
	if err != OK:
		push_error("Cannot rasterize painted settings SVG (%s): %d" % [kind,err])
		return null
	return ImageTexture.create_from_image(image)
