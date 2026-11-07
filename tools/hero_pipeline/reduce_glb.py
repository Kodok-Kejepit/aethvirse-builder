"""Shrinks a huge Meshy GLB before Godot touches it (low memory: numpy + meshoptimizer).
usage: reduce_glb.py in.glb out.glb --tris 30000 [--tex 1024] [--weld]
Keeps UVs (index-only simplification), drops unused vertices and the normal/metal maps,
resizes the albedo. The result goes to tools/import_props.sh like any other GLB.
--weld: for meshes cut into thousands of UV islands (the plain pass stalls far above the
budget): simplify the position-welded surface, then give every new triangle the vertices
of a UV island all three corners share, so textures only smear on the few triangles that
straddle a seam. Needs scipy.
--rebake: best for those meshes: simplify the welded surface, give it a fresh UV atlas
(xatlas) and bake a new albedo by sampling the original texture at the nearest original
vertex of every texel. Needs scipy + xatlas."""
import argparse
import os
import sys

import numpy as np
import meshoptimizer as mo

sys.path.insert(0, os.path.dirname(__file__))
import glbio  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("--tris", type=int, default=30000)
ap.add_argument("--tex", type=int, default=1024)
ap.add_argument("--weld", action="store_true")
ap.add_argument("--rebake", action="store_true")
a = ap.parse_args()

d = glbio.load(a.src)
pos = np.ascontiguousarray(d["pos"], dtype=np.float32)
idx = np.ascontiguousarray(d["tri"].reshape(-1), dtype=np.uint32)
target = a.tris * 3


def plain(idx, pos):
    out = np.zeros_like(idx)
    n = len(idx)
    # Topology-aware passes only (sloppy simplification tears UV seams → smeared textures).
    # Raise the allowed error step by step until the budget is met.
    for err in (0.02, 0.05, 0.1, 0.25, 0.5, 1.0):
        n = mo.simplify(out, idx, pos, target_index_count=target, target_error=err)
        if n <= target * 1.15:
            break
    return out[:n].reshape(-1, 3)


def welded(tri_orig, pos, uv):
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    nv = len(pos)
    # UV islands = connected components of the original (seam-split) triangles.
    e = np.concatenate([tri_orig[:, [0, 1]], tri_orig[:, [1, 2]]])
    g = coo_matrix((np.ones(len(e), dtype=np.int8), (e[:, 0], e[:, 1])), shape=(nv, nv))
    _, island = connected_components(g, directed=False)
    # Canonical vertex per position.
    key = np.round(pos / max(float(np.ptp(pos, axis=0).max()), 1e-6) * 2e5).astype(np.int64)
    _, canon_of, inverse = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inverse = inverse.reshape(-1)
    shadow = inverse[tri_orig].astype(np.uint32)
    cpos = np.ascontiguousarray(pos[canon_of])
    sidx = np.ascontiguousarray(shadow.reshape(-1))
    out = np.zeros_like(sidx)
    n = len(sidx)
    for err in (0.01, 0.03, 0.08, 0.2, 0.5, 1.0):
        n = mo.simplify(out, sidx, cpos, target_index_count=target, target_error=err)
        if n <= target * 1.15:
            break
    ctri = out[:n].reshape(-1, 3)
    # (canonical, island) -> original vertex.
    pairs = {}
    for v in range(nv):
        pairs.setdefault(int(inverse[v]), {}).setdefault(int(island[v]), v)
    res = np.zeros_like(ctri)
    smeared = 0
    for t in range(len(ctri)):
        opts = [pairs[int(c)] for c in ctri[t]]
        common = set(opts[0]).intersection(opts[1], opts[2])
        if common:
            isl = next(iter(common))
            res[t] = [opts[k][isl] for k in range(3)]
        else:
            smeared += 1
            # Most corners agree: take the island two corners share, if any.
            best = None
            for i in range(3):
                for j in range(i + 1, 3):
                    shared = set(opts[i]).intersection(opts[j])
                    if shared:
                        best = next(iter(shared))
            res[t] = [opts[k].get(best, next(iter(opts[k].values()))) for k in range(3)]
    print(f"weld: {smeared} of {len(res)} triangles straddle a UV seam")
    return res


def rebake(tri_orig, pos, uv, albedo, tex):
    import xatlas
    from scipy.spatial import cKDTree
    key = np.round(pos / max(float(np.ptp(pos, axis=0).max()), 1e-6) * 2e5).astype(np.int64)
    _, canon_of, inverse = np.unique(key, axis=0, return_index=True, return_inverse=True)
    cpos = np.ascontiguousarray(pos[canon_of])
    sidx = np.ascontiguousarray(inverse.reshape(-1)[tri_orig].astype(np.uint32).reshape(-1))
    out = np.zeros_like(sidx)
    n = len(sidx)
    for err in (0.01, 0.03, 0.08, 0.2, 0.5, 1.0):
        n = mo.simplify(out, sidx, cpos, target_index_count=target, target_error=err)
        if n <= target * 1.15:
            break
    ctri = out[:n].reshape(-1, 3)
    used = np.unique(ctri)
    rm = np.full(len(cpos), -1, dtype=np.int64)
    rm[used] = np.arange(len(used))
    lpos = cpos[used].astype(np.float32)
    ltri = rm[ctri].astype(np.uint32)
    vmap, ftri, fuv = xatlas.parametrize(lpos, ltri)
    vpos = lpos[vmap]
    # Smooth normals of the new surface.
    fn = np.cross(vpos[ftri[:, 1]] - vpos[ftri[:, 0]], vpos[ftri[:, 2]] - vpos[ftri[:, 0]])
    vn = np.zeros_like(vpos)
    pn = np.zeros_like(lpos)
    for k in range(3):
        np.add.at(pn, vmap[ftri[:, k]], fn)
    pn /= np.maximum(np.linalg.norm(pn, axis=1, keepdims=True), 1e-9)
    vn = pn[vmap]
    # Rasterise the atlas: texel -> 3D point.
    size = tex
    pts = []
    pix = []
    for t in range(len(ftri)):
        a3 = vpos[ftri[t]]
        uvt = fuv[ftri[t]] * size
        x0, y0 = np.floor(uvt.min(0)).astype(int)
        x1, y1 = np.ceil(uvt.max(0)).astype(int)
        xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1 + 1, size)), np.arange(max(y0, 0), min(y1 + 1, size)))
        P = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], 1)
        v0, v1 = uvt[1] - uvt[0], uvt[2] - uvt[0]
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        w = P - uvt[0]
        b1 = (w[:, 0] * v1[1] - v1[0] * w[:, 1]) / den
        b2 = (v0[0] * w[:, 1] - w[:, 0] * v0[1]) / den
        m = (b1 >= -0.02) & (b2 >= -0.02) & (b1 + b2 <= 1.02)
        if not m.any():
            continue
        b1, b2 = b1[m], b2[m]
        pts.append(a3[0] + (a3[1] - a3[0]) * b1[:, None] + (a3[2] - a3[0]) * b2[:, None])
        pix.append(P[m].astype(np.int32))
    pts = np.concatenate(pts)
    pix = np.concatenate(pix)
    # Colour of the nearest original vertex (dense Meshy meshes: sub-millimetre gaps).
    _, near = cKDTree(pos).query(pts, workers=2)
    src = np.asarray(albedo, dtype=np.uint8)
    h, wd = src.shape[:2]
    suv = uv[near]
    sx = np.clip((suv[:, 0] % 1.0) * wd, 0, wd - 1).astype(np.int64)
    sy = np.clip((suv[:, 1] % 1.0) * h, 0, h - 1).astype(np.int64)
    img = np.zeros((size, size, 3), dtype=np.uint8)
    filled = np.zeros((size, size), dtype=bool)
    img[pix[:, 1], pix[:, 0]] = src[sy, sx]
    filled[pix[:, 1], pix[:, 0]] = True
    # Dilate a few texels so mipmaps / bilinear filtering never pick up black gutters.
    for _ in range(4):
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(np.roll(img, dy, 0), dx, 1)
            shf = np.roll(np.roll(filled, dy, 0), dx, 1)
            take = shf & ~filled
            img[take] = sh[take]
            filled |= take
    from PIL import Image
    return {"pos": vpos, "nrm": vn, "uv": fuv.astype(np.float32), "tri": ftri.astype(np.uint32), "normal": None,
            "albedo": Image.fromarray(img)}


if a.rebake:
    res = rebake(d["tri"].reshape(-1, 3), pos, d["uv"], d["albedo"], a.tex)
    glbio.save(a.dst, res)
    print(f"{os.path.basename(a.src)}: {len(idx) // 3} -> {len(res['tri'])} tris rebaked")
    sys.exit(0)
if a.weld:
    tri = welded(d["tri"].reshape(-1, 3), pos, d["uv"])
else:
    tri = plain(idx, pos)
used = np.unique(tri)
remap = np.full(len(pos), -1, dtype=np.int64)
remap[used] = np.arange(len(used))
res = {"pos": pos[used], "nrm": d["nrm"][used], "uv": d["uv"][used], "tri": remap[tri].astype(np.uint32), "normal": None}
alb = d["albedo"]
res["albedo"] = alb.resize((a.tex, a.tex)) if alb is not None and alb.size[0] > a.tex else alb
glbio.save(a.dst, res)
print(f"{os.path.basename(a.src)}: {len(idx) // 3} -> {len(tri)} tris, {len(used)} verts")
