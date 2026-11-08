"""Splits a collection model (several trees / rocks / props in one Meshy GLB) into one GLB
per object.
usage: split_glb.py in.glb out_prefix [--min-tris 300] [--gap 0.02]
Pieces = connected triangle islands (vertices welded by position); islands whose footprints
overlap (leaves floating over a trunk) are merged into one object. A flat base plate that
spans everything (a display stand) is dropped. Objects are numbered west to east
(out_prefix_1.glb, _2, ...); every file keeps the shared albedo. Needs numpy + scipy."""
import argparse
import os
import sys

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

sys.path.insert(0, os.path.dirname(__file__))
import glbio  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("prefix")
ap.add_argument("--min-tris", type=int, default=300)
ap.add_argument("--gap", type=float, default=0.02)
a = ap.parse_args()

d = glbio.load(a.src)
pos, tri = d["pos"], d["tri"].reshape(-1, 3)
span = float(np.ptp(pos, axis=0).max())
key = np.round(pos / span * 2e4).astype(np.int64)
_, inv = np.unique(key, axis=0, return_inverse=True)
inv = inv.reshape(-1)
wt = inv[tri]
e = np.concatenate([wt[:, [0, 1]], wt[:, [1, 2]]])
n = int(inv.max()) + 1
g = coo_matrix((np.ones(len(e), dtype=np.int8), (e[:, 0], e[:, 1])), shape=(n, n))
_, comp_of_w = connected_components(g, directed=False)
tri_comp = comp_of_w[wt[:, 0]]
comps = np.unique(tri_comp)

boxes = {}
for c in comps:
    t = tri[tri_comp == c]
    p = pos[np.unique(t)]
    boxes[int(c)] = [p.min(0), p.max(0), len(t)]

# Drop a base plate: thin, and its footprint covers most of the model.
full_lo, full_hi = pos.min(0), pos.max(0)
full_area = (full_hi[0] - full_lo[0]) * (full_hi[2] - full_lo[2])
for c, (lo, hi, nt) in list(boxes.items()):
    area = (hi[0] - lo[0]) * (hi[2] - lo[2])
    if area > 0.6 * full_area and (hi[1] - lo[1]) < 0.12 * (full_hi[1] - full_lo[1]):
        del boxes[c]

# Merge islands with overlapping XZ footprints (union-find).
ids = list(boxes)
parent = {c: c for c in ids}


def find(x):
    while parent[x] != x:
        parent[x] = parent[parent[x]]
        x = parent[x]
    return x


gap = a.gap * span
for i, ci in enumerate(ids):
    for cj in ids[i + 1:]:
        lo1, hi1, _ = boxes[ci]
        lo2, hi2, _ = boxes[cj]
        # Merge only when one island's centre lies inside the other's footprint (leaves
        # over their trunk), not when two neighbouring trees merely touch.
        c1, c2 = (lo1 + hi1) / 2, (lo2 + hi2) / 2
        inside12 = lo2[0] - gap <= c1[0] <= hi2[0] + gap and lo2[2] - gap <= c1[2] <= hi2[2] + gap
        inside21 = lo1[0] - gap <= c2[0] <= hi1[0] + gap and lo1[2] - gap <= c2[2] <= hi1[2] + gap
        if inside12 or inside21:
            parent[find(ci)] = find(cj)
groups = {}
for c in ids:
    groups.setdefault(find(c), []).append(c)

objects = []
for members in groups.values():
    mask = np.isin(tri_comp, members)
    t = tri[mask]
    if len(t) < a.min_tris:
        continue
    used = np.unique(t)
    objects.append((float(pos[used, 0].mean()), t, used))
objects.sort(key=lambda o: o[0])
for i, (_, t, used) in enumerate(objects, 1):
    remap = np.full(len(pos), -1, dtype=np.int64)
    remap[used] = np.arange(len(used))
    out = {"pos": pos[used], "nrm": d["nrm"][used], "uv": d["uv"][used], "tri": remap[t].astype(np.uint32),
           "albedo": d["albedo"], "normal": None}
    path = f"{a.prefix}_{i}.glb"
    glbio.save(path, out)
    size = np.ptp(pos[used], axis=0)
    print(f"{os.path.basename(path)}: {len(t)} tris, size {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f}")
