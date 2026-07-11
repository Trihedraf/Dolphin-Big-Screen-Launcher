package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

TitleDatabase :: distinct map[string]string

load_title_database :: proc(paths: DolphinPaths) -> TitleDatabase {
    db := make(TitleDatabase)

    candidates: [dynamic]string
    defer delete(candidates)

    // Dolphin bundled/user Sys locations.
    if paths.sys_dir != "" {
        p, _ := filepath.join({paths.sys_dir, "wiitdb-en.txt"})
        append(&candidates, p)
        p2, _ := filepath.join({paths.sys_dir, "wiitdb.txt"})
        append(&candidates, p2)
    }
    if paths.user_dir != "" {
        p, _ := filepath.join({paths.user_dir, "Sys", "wiitdb-en.txt"})
        append(&candidates, p)
        p2, _ := filepath.join({paths.user_dir, "Sys", "wiitdb.txt"})
        append(&candidates, p2)
        p3, _ := filepath.join({paths.user_dir, "wiitdb-en.txt"})
        append(&candidates, p3)
        p4, _ := filepath.join({paths.user_dir, "wiitdb.txt"})
        append(&candidates, p4)
    }

    // Linux system share directories.
    sys_dirs := [3]string {
        "/usr/share/dolphin-emu",
        "/usr/share/games/dolphin-emu",
        "/usr/local/share/dolphin-emu",
    }
    for sys_path in sys_dirs {
        p, _ := filepath.join({sys_path, "wiitdb-en.txt"})
        append(&candidates, p)
        p2, _ := filepath.join({sys_path, "wiitdb.txt"})
        append(&candidates, p2)
    }

    for path in candidates {
        if path == "" || !os.exists(path) {
            continue
        }

        data, err := os.read_entire_file(path, context.temp_allocator)
        if err != os.ERROR_NONE {
            continue
        }

        parse_title_database(&db, string(data))
        return db
    }

    return db
}

parse_title_database :: proc(db: ^TitleDatabase, src: string) {
    s := src
    for line in strings.split_lines_iterator(&s) {
        trimmed := strings.trim_space(line)
        if len(trimmed) == 0 {
            continue
        }
        if trimmed[0] == '#' || trimmed[0] == ';' {
            continue
        }

        eq := strings.index_byte(trimmed, '=')
        if eq <= 0 {
            continue
        }

        id := strings.trim_space(trimmed[:eq])
        title := strings.trim_space(trimmed[eq + 1:])
        if id != "" && title != "" {
            id_clone := strings.clone(id)
            title_clone := strings.clone(title)
            db[id_clone] = title_clone
        }
    }
}

lookup_title :: proc(db: TitleDatabase, game_id: string) -> string {
    if title, ok := db[game_id]; ok {
        return title
    }

    // Try broader matches: first 4 chars, first 3 chars.
    if len(game_id) >= 4 {
        if title, ok := db[game_id[:4]]; ok {
            return title
        }
    }
    if len(game_id) >= 3 {
        if title, ok := db[game_id[:3]]; ok {
            return title
        }
    }

    return ""
}

apply_titles :: proc(games: []Game, db: TitleDatabase) {
    for i := 0; i < len(games); i += 1 {
        game := &games[i]
        if title := lookup_title(db, game.game_id); title != "" {
            game.title = strings.clone(title)
        }
    }
}
