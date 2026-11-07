"""Prepare a Meshy image-to-3D GLB for ASCENDANT: optional dragon strip (colour + adjacency),
face -Z, scale to height, feet on y=0, drop unused vertices, resize textures.
usage: prep_hero.py in.glb out.glb --height 1.8 --tex 4096 --normal 2048 [--strip-dragon] [--dragon-out d.glb]"""
import sys,argparse,numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree
sys.path.insert(0,__import__('os').path.dirname(__file__))
import glbio
ap=argparse.ArgumentParser();ap.add_argument('src');ap.add_argument('dst')
ap.add_argument('--height',type=float,default=1.8);ap.add_argument('--tex',type=int,default=4096);ap.add_argument('--normal',type=int,default=2048)
ap.add_argument('--strip-dragon',action='store_true');ap.add_argument('--dragon-out')
a=ap.parse_args()
d=glbio.load(a.src);tri=d['tri'];pos=d['pos']
def face_adjacency(tri,pos):
    key=np.round(pos/1e-5).astype(np.int64);_,weld=np.unique(key,axis=0,return_inverse=True);weld=weld.ravel()
    t=weld[tri];f=np.arange(len(t))
    # faces sharing a welded vertex are neighbours (vertex adjacency, cheap and good enough)
    rows=np.concatenate([t[:,0],t[:,1],t[:,2]]);cols=np.concatenate([f,f,f])
    vf=coo_matrix((np.ones(len(rows),np.int8),(rows,cols)),shape=(weld.max()+1,len(t))).tocsr()
    return (vf.T@vf).tocsr()
if a.strip_dragon:
    alb=np.asarray(d['albedo'],dtype=np.float32)/255.0;h,w,_=alb.shape
    uvc=d['uv'][tri].mean(1);px=np.clip((uvc[:,0]%1)*w,0,w-1).astype(int);py=np.clip((uvc[:,1]%1)*h,0,h-1).astype(int)
    col=alb[py,px];r,g,b=col.T;mx=col.max(1);mn=col.min(1);sat=(mx-mn)/np.maximum(mx,1e-3)
    seed=(mx>0.7)&(b>=r-0.02)&(sat<0.3)
    adj=face_adjacency(tri,pos)
    # keep only big seed islands (the dragon), drop stray white bits on the outfit
    sub=adj[seed][:,seed];k,lab=connected_components(sub,directed=False);cnt=np.bincount(lab)
    big=np.isin(lab,np.where(cnt>seed.sum()*0.02)[0]);dragon=np.zeros(len(tri),bool);dragon[np.where(seed)[0][big]]=True
    # grow over neighbours that are not hair-coloured and stay near the seed (belly gaps)
    cent=pos[tri].mean(1);tree=cKDTree(cent[dragon]);near=tree.query(cent,distance_upper_bound=0.07)[0]<0.07
    hair=(r>b+0.12)&(g>b+0.02)&(mx>0.55)
    allowed=near&~hair
    for _ in range(40):
        grow=(adj@dragon.astype(np.int8))>0
        new=grow&allowed&~dragon
        if not new.any():break
        dragon|=new
    print("dragon faces",dragon.sum(),"of",len(tri))
    if a.dragon_out:
        dd=dict(d);dd['tri']=tri[dragon];dd['albedo']=d['albedo'].resize((1024,1024));dd['normal']=None;glbio.save(a.dragon_out,dd)
    tri=tri[~dragon]
    # drop floating debris left by the cut (small islands)
    adj2=face_adjacency(tri,pos);k,lab=connected_components(adj2,directed=False);cnt=np.bincount(lab)
    keep=cnt[lab]>len(tri)*0.004
    print("islands",k,"dropped faces",(~keep).sum())
    tri=tri[keep]
# face -Z (Meshy faces +Z), scale, floor, centre
pos=pos*np.array([-1,1,-1],np.float32);nrm=d['nrm']*np.array([-1,1,-1],np.float32)
used=np.unique(tri);lo=pos[used].min(0);hi=pos[used].max(0);s=a.height/(hi[1]-lo[1])
pos=pos*s;band=pos[used];yb=(band[:,1]>0.45*a.height)&(band[:,1]<0.7*a.height)
cx=np.median(band[yb,0]);cz=np.median(band[yb,2]);pos-=np.array([cx,pos[used][:,1].min(),cz],np.float32)
remap=-np.ones(len(pos),np.int64);remap[used]=np.arange(len(used))
out={'pos':pos[used],'nrm':nrm[used],'uv':d['uv'][used],'tri':remap[tri].astype(np.uint32)}
out['albedo']=d['albedo'].resize((a.tex,a.tex)) if d['albedo'].size[0]>a.tex else d['albedo']
out['normal']=None if d['normal'] is None or a.normal==0 else d['normal'].resize((a.normal,a.normal))
glbio.save(a.dst,out)
print("saved",a.dst,"verts",len(used),"tris",len(tri),"scale",round(float(s),3))
