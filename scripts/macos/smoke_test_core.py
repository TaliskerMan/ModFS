#!/usr/bin/env python3
# Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>. GPLv3 or later.
"""Load the search core bundled in the app and run real searches with it.

Run by build_macos.sh after signing. It proves the bundled libmodfs_core.dylib
and the libraries copied next to it load from inside the app (no Homebrew
paths) and that indexing, saving, loading and the search syntax shown in the
app's help work. Exits non-zero on any failure.
"""

import ctypes
import os
import sys
import tempfile

VOID_P = ctypes.c_void_p
CHAR_P = ctypes.c_char_p


def load(path):
    """Load the core and declare the C signatures used (see lib/ffi.dart)."""
    lib = ctypes.CDLL(path)
    lib.modfs_db_new.restype = VOID_P
    lib.modfs_db_new.argtypes = [ctypes.POINTER(CHAR_P), ctypes.c_int,
                                 ctypes.POINTER(CHAR_P), ctypes.c_int, ctypes.c_bool]
    for name in ("modfs_db_scan",):
        getattr(lib, name).argtypes = [VOID_P]
        getattr(lib, name).restype = ctypes.c_bool
    for name in ("modfs_db_save", "modfs_db_load"):
        getattr(lib, name).argtypes = [VOID_P, CHAR_P]
        getattr(lib, name).restype = ctypes.c_bool
    for name in ("modfs_db_get_num_files", "modfs_db_get_num_folders"):
        getattr(lib, name).argtypes = [VOID_P]
        getattr(lib, name).restype = ctypes.c_uint32
    lib.modfs_db_search.argtypes = [VOID_P, CHAR_P]
    lib.modfs_db_search.restype = VOID_P
    for name in ("modfs_search_result_get_folders_count", "modfs_search_result_get_files_count"):
        getattr(lib, name).argtypes = [VOID_P]
        getattr(lib, name).restype = ctypes.c_int
    for name in ("modfs_search_result_get_file_path", "modfs_search_result_get_folder_path"):
        getattr(lib, name).argtypes = [VOID_P, ctypes.c_int]
        getattr(lib, name).restype = VOID_P
    for name in ("modfs_free_string", "modfs_search_result_free", "modfs_db_free"):
        getattr(lib, name).argtypes = [VOID_P]
    return lib


def make_tree(root):
    """Create a small folder tree with known names, sizes and types."""
    files = {
        "projects/report 2026.pdf": 10, "projects/report.docx": 10,
        "projects/invoice-march.pdf": 10, "photos/IMG_0001.jpg": 10,
        "photos/IMG_x.jpg": 10, "photos/photo.png": 10, "notes/README": 10,
        "notes/notes.md": 10, "big/huge.bin": 3 * 1024 * 1024,
    }
    for rel, size in files.items():
        full = os.path.join(root, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "wb") as handle:
            handle.write(b"x" * size)


def search(lib, db, query, root):
    """Return the relative paths (folders prefixed 'D:') matching `query`."""
    result = lib.modfs_db_search(db, query.encode())
    found = []
    try:
        for i in range(lib.modfs_search_result_get_folders_count(result)):
            ptr = lib.modfs_search_result_get_folder_path(result, i)
            found.append("D:" + os.path.relpath(ctypes.string_at(ptr).decode(), root))
            lib.modfs_free_string(ptr)
        for i in range(lib.modfs_search_result_get_files_count(result)):
            ptr = lib.modfs_search_result_get_file_path(result, i)
            found.append(os.path.relpath(ctypes.string_at(ptr).decode(), root))
            lib.modfs_free_string(ptr)
    finally:
        lib.modfs_search_result_free(result)
    return sorted(found)


EXPECTED = {
    "report": ["projects/report 2026.pdf", "projects/report.docx"],
    "ext:pdf": ["projects/invoice-march.pdf", "projects/report 2026.pdf"],
    "*.jpg": ["photos/IMG_0001.jpg", "photos/IMG_x.jpg"],
    r"regex:^IMG_[0-9]+\.jpg$": ["photos/IMG_0001.jpg"],
    "case:README": ["notes/README"],
    "file:notes": ["notes/notes.md"],
    "folder:photos": ["D:photos"],
    "size:>1mb ext:bin": ["big/huge.bin"],
}


def main():
    """Index a temporary tree with the bundled core and check search results."""
    if len(sys.argv) != 2:
        print("usage: smoke_test_core.py <path to libmodfs_core.dylib>", file=sys.stderr)
        return 2
    lib = load(sys.argv[1])
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        # macOS temp folders sit behind a symlink (/var -> /private/var);
        # index the real path so result paths compare cleanly.
        root = os.path.realpath(tmp)
        make_tree(root)
        includes = (CHAR_P * 1)(root.encode())
        db = lib.modfs_db_new(includes, 1, None, 0, False)
        if not lib.modfs_db_scan(db):
            print("FAIL: scan")
            return 1
        print(f"  indexed {lib.modfs_db_get_num_files(db)} files, {lib.modfs_db_get_num_folders(db)} folders")
        for query, expected in EXPECTED.items():
            got = search(lib, db, query, root)
            status = "ok  " if got == expected else "FAIL"
            failures += got != expected
            print(f"  {status} {query!r}: {got}")
        saved = os.path.join(root, "index.fsearch")
        if not lib.modfs_db_save(db, saved.encode()):
            print("FAIL: save")
            failures += 1
        reloaded = lib.modfs_db_new(includes, 1, None, 0, False)
        if not lib.modfs_db_load(reloaded, saved.encode()) or \
                lib.modfs_db_get_num_files(reloaded) != lib.modfs_db_get_num_files(db):
            print("FAIL: load")
            failures += 1
        lib.modfs_db_free(reloaded)
        lib.modfs_db_free(db)
    print("  smoke test passed" if failures == 0 else f"  {failures} failure(s)")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
