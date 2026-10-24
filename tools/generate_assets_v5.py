"""Art pass v5: richer, darker 'painterly pixel' look (terrain tiles, trees, bushes, rocks, stump).
Run from project root: python3 tools/generate_assets_v5.py   (overwrites assets/tiles/tileset.png and assets/world/*.png props)"""
import random, math
from PIL import Image

def hexc(h): h=h.lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))+(255,)

# ------------------------------------------------------------ terrain
def terrain_tile(base, dark, light, seed, blades=None, flecks=None, pebbles=None, flower=None, cracks=None):
    rnd=random.Random(seed)
    im=Image.new('RGBA',(16,16),hexc(base)); px=im.load()
    for y in range(16):
        for x in range(16):
            r=rnd.random()
            if r<0.18: px[x,y]=hexc(dark)
            elif r<0.30: px[x,y]=hexc(light)
    if blades:
        for _ in range(blades[0]):
            x=rnd.randrange(16); y=rnd.randrange(16)
            for k in range(2):
                px[x,(y-k)%16]=hexc(blades[1] if k==0 else blades[2])
    if flecks:
        for _ in range(flecks[0]):
            px[rnd.randrange(16),rnd.randrange(16)]=hexc(flecks[1])
    if pebbles:
        for _ in range(pebbles[0]):
            x=rnd.randrange(1,15); y=rnd.randrange(1,15)
            px[x,y]=hexc(pebbles[1]); px[x+1,y]=hexc(pebbles[1]); px[x,y+1]=hexc(pebbles[2])
    if flower:
        x=rnd.randrange(2,14); y=rnd.randrange(2,14)
        px[x,y]=hexc(flower[0]); px[x-1,y]=hexc(flower[1]); px[x+1,y]=hexc(flower[1]); px[x,y-1]=hexc(flower[1]); px[x,y+1]=hexc(flower[1])
        px[x,y]=hexc(flower[0])
    if cracks:
        for _ in range(cracks[0]):
            x=rnd.randrange(16); y=rnd.randrange(16)
            for k in range(rnd.randrange(3,6)):
                px[x%16,y%16]=hexc(cracks[1]); x+=rnd.choice([-1,1,1]); y+=rnd.choice([0,1])
    return im

def cobble_tile(seed):
    rnd=random.Random(seed)
    base=[hexc('#8a90a0'),hexc('#767d8e'),hexc('#9aa0ae'),hexc('#6c7284')]
    gap=hexc('#4a4f5e')
    im=Image.new('RGBA',(16,16),gap); px=im.load()
    rows=[(0,5),(5,11),(11,16)]
    for ri,(y0,y1) in enumerate(rows):
        x=-rnd.randrange(0,4)
        while x<16:
            w=rnd.randrange(5,8); col=rnd.choice(base[:3])
            for yy in range(y0+1,y1):
                for xx in range(x+1,x+w):
                    if 0<=xx<16:
                        c=col
                        if yy==y0+1: c=hexc('#aab0bc')
                        elif yy==y1-1 or xx==x+w-1: c=base[3]
                        if rnd.random()<0.12: c=base[1]
                        px[xx,yy]=c
            x+=w
    if seed%2==0:
        for _ in range(5):
            px[rnd.randrange(16),rnd.randrange(16)]=hexc('#5c8a46')
    return im

def build_tileset():
    ts=Image.open('assets/tiles/tileset.png').convert('RGBA')
    G=('#4c8a38','#3b7030','#68a645')
    tiles={
     0:terrain_tile(*G,11,blades=(7,'#82bd52','#5aa040'),flecks=(3,'#7fb84e')),
     1:terrain_tile(*G,12,blades=(8,'#82bd52','#5aa040'),flecks=(2,'#6fae48')),
     2:terrain_tile('#2e5e30','#224a28','#418040',13,blades=(8,'#4e9444','#357a38'),flecks=(3,'#5aa04a')),
     3:terrain_tile('#9a6a3c','#7c5230','#b98650',14,pebbles=(2,'#c9a878','#6e4a2a'),flecks=(4,'#5e3c22')),
     4:terrain_tile('#e2c684','#c9aa68','#f2dca0',15,flecks=(5,'#b89850'),pebbles=(1,'#f6e8c0','#b89850')),
     5:cobble_tile(16),
     8:terrain_tile('#4a3a78','#382c62','#5e4c92',17,flecks=(6,'#b9a0ff'),blades=(3,'#7a62b8','#5a4694')),
     9:terrain_tile('#4a3a78','#382c62','#5e4c92',18,flecks=(5,'#d3b8ff'),pebbles=(1,'#8c70c8','#2e2450')),
    }
    for i,t in tiles.items():
        ts.paste(t,(i*16,0))
    ts.save('assets/tiles/tileset.png')

# ------------------------------------------------------------ blob shading (trees, bushes, rocks)
def shade_blobs(w,h,blobs,pal,seed,outline,light=(-0.55,-0.75),noise=0.16,speck=0.0):
    """blobs: list of (cx,cy,rx,ry); later blobs are in front. pal: dark->light list of colours."""
    rnd=random.Random(seed)
    im=Image.new('RGBA',(w,h),(0,0,0,0)); px=im.load()
    cover=[[None]*w for _ in range(h)]
    for (cx,cy,rx,ry) in blobs:
        for y in range(h):
            for x in range(w):
                dx=(x+0.5-cx)/rx; dy=(y+0.5-cy)/ry
                d=dx*dx+dy*dy
                if d<=1.0:
                    z=math.sqrt(max(0,1-d))
                    l=light[0]*dx+light[1]*dy+0.55*z
                    cover[y][x]=l
    for y in range(h):
        for x in range(w):
            l=cover[y][x]
            if l is None: continue
            l+=rnd.uniform(-noise,noise)
            idx=int(max(0,min(len(pal)-1,(l+0.42)/1.05*len(pal))))
            c=pal[idx]
            if speck and rnd.random()<speck: c=pal[min(len(pal)-1,idx+1)]
            px[x,y]=c
    o=hexc(outline)
    out=im.copy(); op=out.load()
    for y in range(h):
        for x in range(w):
            if px[x,y][3]==0:
                for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    xx,yy=x+dx,y+dy
                    if 0<=xx<w and 0<=yy<h and px[xx,yy][3]>0:
                        op[x,y]=o; break
    return out

def pl(*hs): return [hexc(h) for h in hs]

def trunk(im,cx,base_y,top_y,w,cols,rnd):
    px=im.load()
    for y in range(top_y,base_y):
        flare = 1 if y>base_y-4 else 0
        for x in range(cx-w//2-flare,cx+w//2+w%2+flare):
            t=(x-(cx-w//2-flare))/max(1,(w+2*flare))
            c=cols[0] if t<0.3 else (cols[1] if t<0.7 else cols[2])
            if rnd.random()<0.1: c=cols[2]
            px[x,y]=c
    for x in range(cx-w//2-1,cx+w//2+w%2+1):
        px[x,base_y]=hexc('#1c1410')
    for y in range(top_y,base_y):
        px[cx-w//2-1-(1 if y>base_y-4 else 0),y]=hexc('#1c1410')
        px[cx+w//2+w%2+(1 if y>base_y-4 else 0),y]=hexc('#1c1410')

def shadow(im,cx,cy,rx):
    px=im.load()
    for y in range(-2,3):
        for x in range(-rx,rx+1):
            if (x/rx)**2+(y/2.2)**2<=1 and 0<=cy+y<im.height and px[cx+x,cy+y][3]==0:
                px[cx+x,cy+y]=(0,0,0,70)

def oak():
    rnd=random.Random(5)
    w,h=32,48
    blobs=[(16,18,13,12),(8,22,8,8),(24,22,8,8),(16,10,9,8),(10,13,7,7),(22,13,7,7),(16,26,10,7)]
    can=shade_blobs(w,h,blobs,pl('#14361f','#1f4d28','#2f6a32','#46913f','#6cb956','#9ad87a'),11,'#0e2616',speck=0.08)
    base=Image.new('RGBA',(w,h),(0,0,0,0))
    shadow(base,16,44,10)
    trunk(base,16,44,28,5,pl('#4a2c18','#6a4126','#85542f'),rnd)
    base.alpha_composite(can)
    # a few bright leaf pixels
    px=base.load()
    for _ in range(14):
        x=rnd.randrange(5,27); y=rnd.randrange(3,24)
        if px[x,y][3]>0 and px[x,y][:3]!=(14,38,22): px[x,y]=hexc('#b6ee8c')
    base.save('assets/world/tree_oak.png')

def pine():
    rnd=random.Random(6)
    w,h=32,48
    im=Image.new('RGBA',(w,h),(0,0,0,0))
    shadow(im,16,44,9)
    trunk(im,16,44,36,4,pl('#4a2c18','#6a4126','#85542f'),rnd)
    tiers=[(16,9,6,4),(16,16,9,6),(16,24,12,7),(16,32,14,8)]
    layers=[]
    for (cx,cy,rx,ry) in tiers:
        blobs=[]
        # triangle-ish tier via stacked ellipses
        for k in range(5):
            f=k/4.0
            blobs.append((cx,cy-ry*0.6+ry*1.2*f,rx*(0.25+0.75*f),ry*0.45))
        t=shade_blobs(w,h,blobs,pl('#0f3024','#17432f','#1f5a3a','#2f7a46','#4e9c58'),cx+cy,'#0a1f18',light=(-0.7,-0.5),noise=0.14,speck=0.06)
        im.alpha_composite(t)
    im.save('assets/world/tree_pine.png')

def bush(name,pal,outline,seed,size=(16,16),berry=None):
    w,h=size
    blobs=[(8,9,6,5),(5,9,4,4),(11,9,4,4),(8,6,4,4)]
    im=shade_blobs(w,h,blobs,pal,seed,outline,speck=0.1)
    px=im.load()
    rnd=random.Random(seed)
    if berry:
        for _ in range(4):
            x=rnd.randrange(3,13); y=rnd.randrange(5,12)
            if px[x,y][3]>0: px[x,y]=hexc(berry)
    base=Image.new('RGBA',(w,h),(0,0,0,0)); shadow(base,8,13,6); base.alpha_composite(im)
    base.save('assets/world/%s.png'%name)

def rock(name,pal,outline,seed):
    w,h=24,20
    blobs=[(12,12,10,7),(7,13,5,5),(17,13,6,5),(11,9,6,5)]
    im=shade_blobs(w,h,blobs,pal,seed,outline,noise=0.2)
    px=im.load(); rnd=random.Random(seed)
    for _ in range(3):  # moss
        x=rnd.randrange(5,19); y=rnd.randrange(6,11)
        if px[x,y][3]>0 and name=='rock': px[x,y]=hexc('#5f8a46'); px[x+1,y]=hexc('#4a7a3a')
    base=Image.new('RGBA',(w,h),(0,0,0,0)); shadow(base,12,18,10); base.alpha_composite(im)
    base.save('assets/world/%s.png'%name)

def stump():
    rnd=random.Random(9)
    im=Image.new('RGBA',(16,16),(0,0,0,0)); shadow(im,8,14,6); px=im.load()
    for y in range(7,14):
        for x in range(3,13):
            t=(x-3)/10
            px[x,y]=hexc('#4a2c18') if t<0.25 else (hexc('#6a4126') if t<0.7 else hexc('#85542f'))
    for y in range(4,8):
        for x in range(3,13):
            if ((x-7.5)/5)**2+((y-5.5)/2.3)**2<=1: px[x,y]=hexc('#c99a62')
    for x in range(5,11): px[x,5]=hexc('#a8794a')
    px[7,5]=hexc('#8a5c34')
    o=hexc('#1c1410'); src=im.copy(); sp=src.load()
    for y in range(16):
        for x in range(16):
            if sp[x,y][3]<255:
                for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    if 0<=x+dx<16 and 0<=y+dy<16 and sp[x+dx,y+dy][3]==255 : px[x,y]=o; break
    im.save('assets/world/stump.png')

if __name__=='__main__':
    build_tileset(); oak(); pine()
    bush('herb_bush',pl('#17401f','#236a2c','#35903a','#58b650','#8ad878'),'#0e2616',21,berry='#d84a5a')
    rock('rock',pl('#3e4452','#565d6e','#727a8c','#929aac','#b4bcca'),'#20242e',31)
    stump()
