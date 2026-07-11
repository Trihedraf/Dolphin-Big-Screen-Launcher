package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "vendor:raylib"

Game :: struct {
    path:          string,
    filename:      string,
    game_id:       string,
    title:         string,
    platform:      string,
    region:        string,
    cover_path:    string,
    cover_texture: raylib.Texture2D,
}

SUPPORTED_EXTENSIONS :: []string {
    ".iso",
    ".gcm",
    ".tgc",
    ".bin",
    ".ciso",
    ".gcz",
    ".wbfs",
    ".wia",
    ".rvz",
    ".nfs",
    ".wad",
    ".dol",
    ".elf",
    ".json",
}

scan_game_library :: proc(paths: []string, recursive: bool) -> []Game {
    result := make([dynamic]Game)
    for path in paths {
        if path == "" || !os.exists(path) {
            continue
        }
        if recursive {
            scan_directory_recursive(path, &result)
        } else {
            scan_directory(path, &result)
        }
    }
    return result[:]
}

load_game_cover_paths :: proc(games: []Game, data_dir: string) {
    covers_dir, _ := filepath.join({data_dir, "Cache", "GameCoversHQ"})
    if !os.exists(covers_dir) {
        if os.make_directory_all(covers_dir) != os.ERROR_NONE {
            return
        }
    }

    for i := 0; i < len(games); i += 1 {
        game := &games[i]
        cover_name := fmt.tprintf("%s.png", game.game_id)
        cover_path, _ := filepath.join({covers_dir, cover_name})
        game.cover_path = strings.clone(cover_path)
    }
}

load_game_cover_textures :: proc(games: []Game) {
    for i := 0; i < len(games); i += 1 {
        game := &games[i]
        if game.cover_path != "" && os.exists(game.cover_path) && game.cover_texture.id == 0 {
            load_single_cover_texture(game)
        }
    }
}

reload_game_cover_textures :: proc(games: []Game) {
    for i := 0; i < len(games); i += 1 {
        game := &games[i]
        if game.cover_texture.id != 0 {
            raylib.UnloadTexture(game.cover_texture)
            game.cover_texture.id = 0
        }
        if game.cover_path != "" && os.exists(game.cover_path) {
            load_single_cover_texture(game)
        }
    }
}

load_single_cover_texture :: proc(game: ^Game) {
    cover_cstr := strings.clone_to_cstring(game.cover_path)
    game.cover_texture = raylib.LoadTexture(cover_cstr)
    delete(cover_cstr)
    if game.cover_texture.id != 0 {
        // Load at native PNG resolution and sample the full texture for sharper downscaling.
        raylib.SetTextureFilter(game.cover_texture, .BILINEAR)
        raylib.SetTextureWrap(game.cover_texture, .CLAMP)
    }
}

cleanup_games :: proc(games: []Game) {
    for game in games {
        delete(game.path)
        delete(game.filename)
        delete(game.game_id)
        delete(game.title)
        delete(game.cover_path)
        if game.cover_texture.id != 0 {
            raylib.UnloadTexture(game.cover_texture)
        }
    }
    delete(games)
}

scan_directory :: proc(dir: string, result: ^[dynamic]Game) {
    infos, err := os.read_directory_by_path(dir, -1, context.temp_allocator)
    if err != os.ERROR_NONE {
        return
    }

    for info in infos {
        if info.type != .Regular {
            continue
        }
        if is_game_file(info.name) {
            game := create_game(info.fullpath)
            append(result, game)
        }
    }
}

scan_directory_recursive :: proc(dir: string, result: ^[dynamic]Game) {
    w := os.walker_create(dir)
    defer os.walker_destroy(&w)

    for info in os.walker_walk(&w) {
        if info.type != .Regular {
            continue
        }
        if is_game_file(info.name) {
            game := create_game(info.fullpath)
            append(result, game)
        }
    }
}

is_game_file :: proc(name: string) -> bool {
    ext := strings.to_lower(filepath.ext(name), context.temp_allocator)
    for supported in SUPPORTED_EXTENSIONS {
        if ext == supported {
            return true
        }
    }
    return false
}

create_game :: proc(path: string) -> Game {
    game: Game
    game.path = strings.clone(path)
    game.filename = strings.clone(filepath.base(path))

    ext := strings.to_lower(filepath.ext(path), context.temp_allocator)

    game.game_id = extract_game_id_for_format(path, ext)

    if game.game_id == "" {
        game.game_id = strings.clone(filepath.stem(path))
    }
    game.title = strings.clone(filepath.stem(path))

    game.platform = detect_platform(path, game.game_id)
    game.region = detect_region(game.game_id)

    return game
}

extract_game_id_for_format :: proc(path: string, ext: string) -> string {
    switch ext {
    case ".iso", ".gcm", ".tgc":
        return extract_game_id(path, 0)
    case ".rvz", ".wia":
        return extract_game_id(path, 0x58)
    case ".wbfs":
        return extract_game_id(path, 0x200)
    case ".ciso":
        return extract_game_id(path, 0x8000)
    case ".gcz":
        // GCZ requires decompressing the first block; skip for now.
        return ""
    }
    return ""
}

extract_game_id :: proc(path: string, offset: i64) -> string {
    f, err := os.open(path)
    if err != os.ERROR_NONE {
        return ""
    }
    defer os.close(f)

    _, seek_err := os.seek(f, offset, io.Seek_From.Start)
    if seek_err != os.ERROR_NONE {
        return ""
    }

    buf: [6]u8
    n, read_err := os.read(f, buf[:])
    if read_err != os.ERROR_NONE || n < 6 {
        return ""
    }

    // GameID is 6 ASCII bytes.
    return strings.clone_from(buf[:], context.allocator)
}

detect_platform :: proc(path: string, game_id: string) -> string {
    ext := strings.to_lower(filepath.ext(path), context.temp_allocator)

    if ext == ".wad" {
        return "WiiWare"
    }
    if ext == ".dol" || ext == ".elf" {
        return "Homebrew"
    }

    if ext == ".iso" || ext == ".gcm" || ext == ".tgc" {
        // Try to read magic words from the disc header (big-endian).
        magic := read_u32be_at(path, 0x18)
        if magic == 0x5D1C9EA3 {
            return "Wii"
        }
        magic = read_u32be_at(path, 0x1C)
        if magic == 0xC2339F3D {
            return "GameCube"
        }
    }

    // Best-effort guess from the first letter of the GameID.
    if len(game_id) >= 1 {
        switch game_id[0] {
        case 'G', 'P':
            return "GameCube"
        case 'R', 'S', 'U':
            return "Wii"
        }
    }

    return "Unknown"
}

detect_region :: proc(game_id: string) -> string {
    if len(game_id) < 4 {
        return "Unknown"
    }

    switch game_id[3] {
    case 'E':
        return "NTSC-U"
    case 'P', 'D', 'F', 'I', 'S', 'X', 'Y', 'L':
        return "PAL"
    case 'J':
        return "NTSC-J"
    case 'K':
        return "NTSC-K"
    case 'W':
        return "Taiwan"
    }

    return "Unknown"
}

read_u32be_at :: proc(path: string, offset: i64) -> u32be {
    f, err := os.open(path)
    if err != os.ERROR_NONE {
        return 0
    }
    defer os.close(f)

    _, seek_err := os.seek(f, offset, io.Seek_From.Start)
    if seek_err != os.ERROR_NONE {
        return 0
    }

    buf: [4]u8
    n, read_err := os.read(f, buf[:])
    if read_err != os.ERROR_NONE || n < 4 {
        return 0
    }

    return (cast(^u32be)&buf[0])^
}
