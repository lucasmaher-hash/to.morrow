"""morrow app icon.

The bottom light is built from two parts, and both are drawn AFTER the shade
so nothing can bury them:
  bloom  a wide, short ellipse hugging the bottom edge, blurred and clipped to
         the bubble — brightest at bottom centre, fading along the arc
  rim    a stack of arcs of widening span and falling alpha, so the rim is most
         intense at bottom centre and pans out toward the sides
"""
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import os, math

SS = 3
OUT = int(os.environ.get("OUT", "1024"))
S = OUT * SS
cx = cy = S // 2
def C(v): return tuple(int(v[i:i+2], 16) for i in (0, 2, 4))
E = os.environ

BG_TOP, BG_BOT   = C(E["BG_TOP"]),  C(E["BG_BOT"])
BUB_TOP, BUB_BOT = C(E["BUB_TOP"]), C(E["BUB_BOT"])
INK        = C(E["INK"])
EDGE_LIGHT = C(E.get("EDGE_LIGHT", "FFFFFF"))
EDGE_SHADE = C(E.get("EDGE_SHADE", "464B52"))
RELIEF     = E.get("RELIEF", "1") == "1"
BOT        = float(E.get("BOT", "1.0"))          # bottom-light strength

def vgrad(top, bot):
    g = Image.new("RGB", (1, S)); d = ImageDraw.Draw(g)
    for y in range(S):
        t = y / (S - 1)
        d.point((0, y), tuple(round(top[i] + (bot[i]-top[i])*t) for i in range(3)))
    return g.resize((S, S), Image.BICUBIC)

def blank(): return Image.new("L", (S, S), 0)

img = vgrad(BG_TOP, BG_BOT).convert("RGB")
D = int(0.68 * S); R = D // 2
box = [cx-R, cy-R, cx+R, cy+R]
bub = blank(); ImageDraw.Draw(bub).ellipse(box, fill=255)
clip = lambda m: Image.composite(m, blank(), bub)
paint = lambda col, m: img.paste(Image.new("RGB", (S, S), col), (0, 0), m)

# contact shadow
sh = blank()
ImageDraw.Draw(sh).ellipse([box[0], box[1]+int(0.030*S), box[2], box[3]+int(0.030*S)], fill=95)
paint((0x1A, 0x22, 0x33), sh.filter(ImageFilter.GaussianBlur(0.040*S)))

img.paste(vgrad(BUB_TOP, BUB_BOT), (0, 0), bub)

def piecewise(stops):
    m = blank(); d = ImageDraw.Draw(m)
    for y in range(cy-R, cy+R+1):
        t = (y-(cy-R))/D; a = 0.0
        for i in range(len(stops)-1):
            t0,a0 = stops[i]; t1,a1 = stops[i+1]
            if t0 <= t <= t1:
                a = a0 + (a1-a0)*((t-t0)/(t1-t0) if t1 > t0 else 0); break
        d.line([(0,y),(S,y)], fill=int(a*255))
    return clip(m)

if RELIEF:                                   # light-mode inner relief
    paint(EDGE_LIGHT, piecewise([(0.00,0.392),(0.14,0.123),(0.34,0.0),(1.00,0.0)]))
    paint(EDGE_SHADE, piecewise([(0.00,0.0),(0.60,0.0),(0.80,0.102),(1.00,0.24)]))
    k = D/104.54
    side = blank()
    ImageDraw.Draw(side).ellipse(box, outline=int(0.128*255), width=max(2,int(13*k)))
    side = side.filter(ImageFilter.GaussianBlur(9*k))
    hm = blank(); hd = ImageDraw.Draw(hm)
    for x in range(cx-R, cx+R+1):
        t = (x-(cx-R))/D
        v = 0.0 if 0.30 <= t <= 0.70 else ((1-t/0.30) if t < 0.30 else (t-0.70)/0.30)
        hd.line([(x,0),(x,S)], fill=int(max(0.0,min(1.0,v))*255))
    paint(EDGE_SHADE, clip(ImageChops.multiply(side, hm)))

# ── bottom light ─────────────────────────────────────────────────────────
bloom = blank()
bw, bh = int(1.15*R), int(0.42*R)
by = cy + int(0.96*R)
ImageDraw.Draw(bloom).ellipse([cx-bw, by-bh, cx+bw, by+bh], fill=int(255*min(1.0, 0.90*BOT)))
bloom = clip(bloom.filter(ImageFilter.GaussianBlur(0.055*S)))
paint(EDGE_LIGHT, bloom)

# ── top shade ────────────────────────────────────────────────────────────
# The bottom light's mirror: same fan, same shape, drawn as shade and kept
# deliberately weaker.
TOPSHADE = float(E.get("TOPSHADE", "0.30"))
if TOPSHADE > 0:
    ts = blank()
    tw, th_ = int(1.15*R), int(0.42*R)
    ty = cy - int(0.96*R)
    ImageDraw.Draw(ts).ellipse([cx-tw, ty-th_, cx+tw, ty+th_],
                               fill=int(255*min(1.0, TOPSHADE)))
    paint(EDGE_SHADE, clip(ts.filter(ImageFilter.GaussianBlur(0.055*S))))

# ── rim ──────────────────────────────────────────────────────────────────
# A SMOOTH angular ramp, not a stack of arcs. Stacked arcs leave a visible
# step wherever one starts or stops; sweeping the alpha continuously round the
# circle removes every seam. RIM_MID is the floor at 3 and 9 o'clock, so the
# ring thins there but never breaks.
rw = max(2, int(0.018*D))
RIM_MID = float(E.get("RIM_MID", "0.10"))
TOP_A   = float(E.get("TOP_A", "0.42"))

def fan(theta, anchor, power):
    """1 at the anchor angle, easing to 0 by 90 degrees away."""
    d = abs(((theta - anchor + 180) % 360) - 180)
    return 0.0 if d >= 90 else math.cos(math.radians(d)) ** power

rim = blank(); rd = ImageDraw.Draw(rim)
STEP = 2
for a0 in range(0, 360, STEP):
    th = a0 + STEP/2
    a = RIM_MID + BOT*fan(th, 90, 1.5) + TOP_A*fan(th, 270, 1.7)
    rd.arc(box, a0-1, a0+STEP+1, fill=int(255*min(1.0, a)), width=rw)
paint(EDGE_LIGHT, rim.filter(ImageFilter.GaussianBlur(0.004*S)))

# ── the mark ─────────────────────────────────────────────────────────────
G = int(0.50*D); w = int(0.115*G); core = int(0.42*G)
gm = blank(); gd = ImageDraw.Draw(gm)
gd.ellipse([cx-G//2, cy-G//2, cx+G//2, cy+G//2], outline=255, width=w)
gd.ellipse([cx-core//2, cy-core//2, cx+core//2, cy+core//2], fill=255)
paint(INK, gm)

icon = img.resize((OUT, OUT), Image.LANCZOS).convert("RGB")
icon.save(E["OUTFILE"])
m = Image.new("L", (OUT, OUT), 0)
ImageDraw.Draw(m).rounded_rectangle([0,0,OUT-1,OUT-1], radius=int(OUT*0.2237), fill=255)
p = Image.new("RGB", (OUT, OUT), (0xF2,0xF2,0xF4)); p.paste(icon, (0,0), m)
if E.get("PREVIEW") and E["PREVIEW"] != "/dev/null":
    p.save(E["PREVIEW"])
