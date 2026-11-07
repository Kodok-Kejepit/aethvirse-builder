class_name SaveFile
extends RefCounted
## Save file container: "ASAV" + format + raw size + md5(raw JSON) + packed size + gzip(JSON).
## Written to <path>.tmp then renamed (atomic); the previous file is kept as <path>.bak.
## Reading validates everything and returns "" for missing/foreign/truncated/corrupted files.

const FILE_MAGIC: PackedByteArray = [0x41, 0x53, 0x41, 0x56]
const FILE_FORMAT: int = 2
const MAX_RAW_BYTES: int = 16 * 1024 * 1024


## Atomic, verified write. Static so tests can use it directly.
static func write(path: String, json_text: String) -> Error:
	var raw: PackedByteArray = json_text.to_utf8_buffer()
	var packed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_GZIP)
	var tmp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(FILE_MAGIC)
	file.store_32(FILE_FORMAT)
	file.store_32(raw.size())
	file.store_pascal_string(json_text.md5_text())
	file.store_32(packed.size())
	file.store_buffer(packed)
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path)


## Returns the JSON text, or "" if the file is missing, foreign, truncated or corrupted.
static func read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 16:
		return ""
	if file.get_buffer(4) != FILE_MAGIC or file.get_32() != FILE_FORMAT:
		return ""
	var raw_size: int = file.get_32()
	var checksum: String = file.get_pascal_string()
	var packed_size: int = file.get_32()
	if raw_size <= 0 or raw_size > MAX_RAW_BYTES or packed_size <= 0 \
			or packed_size > file.get_length() - file.get_position():
		return ""
	var packed: PackedByteArray = file.get_buffer(packed_size)
	file.close()
	var raw: PackedByteArray = packed.decompress(raw_size, FileAccess.COMPRESSION_GZIP)
	if raw.size() != raw_size:
		return ""
	var text: String = raw.get_string_from_utf8()
	return text if text.md5_text() == checksum else ""
