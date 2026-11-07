class_name ChunkMath
extends RefCounted
## Pure chunk grid helpers for WorldStreamer (unit tested).

const CHUNK_SIZE_M: float = 128.0


## Chunk coordinate containing a world position (chunks are centered on their coords).
static func chunk_of(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / CHUNK_SIZE_M + 0.5), floori(position.z / CHUNK_SIZE_M + 0.5))


## Chunks to keep for a center and ring (square, Chebyshev distance).
static func wanted(center: Vector2i, ring: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in range(center.x - ring, center.x + ring + 1):
		for z: int in range(center.y - ring, center.y + ring + 1):
			out.append(Vector2i(x, z))
	return out
