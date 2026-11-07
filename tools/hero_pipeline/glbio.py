import json,struct,io,numpy as np
from PIL import Image
CT={5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
def load(f):
    b=open(f,'rb').read();cl=struct.unpack('<I',b[12:16])[0];j=json.loads(b[20:20+cl]);bo=20+cl+8
    def view(i):
        bv=j['bufferViews'][i];o=bo+bv.get('byteOffset',0);return b[o:o+bv['byteLength']]
    def acc(i):
        a=j['accessors'][i];bv=j['bufferViews'][a['bufferView']];o=bo+bv.get('byteOffset',0)+a.get('byteOffset',0)
        return np.frombuffer(b,dtype=CT[a['componentType']],count=a['count']*NC[a['type']],offset=o).reshape(a['count'],-1).copy()
    p=j['meshes'][0]['primitives'][0];at=p['attributes']
    d={'pos':acc(at['POSITION']).astype(np.float32),'nrm':acc(at['NORMAL']).astype(np.float32),'uv':acc(at['TEXCOORD_0']).astype(np.float32),
       'tri':acc(p['indices']).reshape(-1,3).astype(np.uint32)}
    mat=j['materials'][p.get('material',0)] if 'materials' in j else {}
    def img(tex):
        if tex is None:return None
        im=j['images'][j['textures'][tex['index']]['source']]
        return Image.open(io.BytesIO(view(im['bufferView']))).convert('RGB')
    pbr=mat.get('pbrMetallicRoughness',{})
    d['albedo']=img(pbr.get('baseColorTexture'));d['normal']=img(mat.get('normalTexture'))
    return d
def save(f,d):
    """Single primitive GLB: POSITION, NORMAL, TEXCOORD_0, indices, albedo (+normal) jpeg."""
    chunks=[];views=[];accs=[]
    def add(arr,target=None):
        raw=arr.tobytes();off=sum(len(c) for c in chunks);pad=(-len(raw))%4
        chunks.append(raw+b'\0'*pad);v={'buffer':0,'byteOffset':off,'byteLength':len(raw)}
        if target:v['target']=target
        views.append(v);return len(views)-1
    def acc(arr,typ,ct,target,minmax=False):
        vi=add(np.ascontiguousarray(arr),target);a={'bufferView':vi,'componentType':ct,'count':int(arr.shape[0]),'type':typ}
        if minmax:a['min']=arr.min(0).tolist();a['max']=arr.max(0).tolist()
        accs.append(a);return len(accs)-1
    P=acc(d['pos'].astype(np.float32),'VEC3',5126,34962,True);N=acc(d['nrm'].astype(np.float32),'VEC3',5126,34962)
    U=acc(d['uv'].astype(np.float32),'VEC2',5126,34962);I=acc(d['tri'].astype(np.uint32).reshape(-1),'SCALAR',5125,34963)
    images=[];textures=[]
    def addimg(im,q):
        bio=io.BytesIO();im.save(bio,'JPEG',quality=q);vi=add(np.frombuffer(bio.getvalue(),dtype=np.uint8))
        images.append({'bufferView':vi,'mimeType':'image/jpeg'});textures.append({'source':len(images)-1});return len(textures)-1
    mat={'pbrMetallicRoughness':{'baseColorTexture':{'index':addimg(d['albedo'],90)},'metallicFactor':0.0,'roughnessFactor':1.0},'doubleSided':True}
    if d.get('normal') is not None:mat['normalTexture']={'index':addimg(d['normal'],90)}
    j={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':'body'}],
       'meshes':[{'primitives':[{'attributes':{'POSITION':P,'NORMAL':N,'TEXCOORD_0':U},'indices':I,'material':0}]}],
       'materials':[mat],'images':images,'textures':textures,'accessors':accs,'bufferViews':views,'buffers':[{'byteLength':sum(len(c) for c in chunks)}]}
    js=json.dumps(j).encode();js+=b' '*((-len(js))%4);binb=b''.join(chunks)
    out=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(binb))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(binb),0x004E4942)+binb
    open(f,'wb').write(out)
