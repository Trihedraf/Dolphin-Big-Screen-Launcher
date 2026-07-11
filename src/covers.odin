package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

LOG_PATH := ""

set_download_log_path :: proc(path: string) {
    LOG_PATH = strings.clone(path)
}

log_download :: proc(message: string) {
    if LOG_PATH == "" {
        return
    }
    line := fmt.tprintf("%s\n", message)
    f, err := os.open(LOG_PATH, os.O_WRONLY | os.O_CREATE | os.O_APPEND)
    if err != os.ERROR_NONE {
        return
    }
    os.write(f, transmute([]u8)line)
    os.close(f)
}

// Download the coverfullHQ image for a single game. Runs on a background thread.
download_cover :: proc(game: Game, covers_dir: string) {
    if game.cover_path == "" {
        return
    }

    cover_path, _ := filepath.join({covers_dir, fmt.tprintf("%s.png", game.game_id)})

    if os.exists(cover_path) {
        return
    }

    region := gametdb_region(game.region)
    url := fmt.tprintf("https://art.gametdb.com/wii/coverfullHQ/%s/%s.png", region, game.game_id)
    log_download(fmt.tprintf("[%s] downloading: %s", game.game_id, url))

    if !download_file(url, cover_path) {
        log_download(fmt.tprintf("[%s] download_file returned false", game.game_id))
        return
    }

    if !os.exists(cover_path) {
        log_download(fmt.tprintf("[%s] cover file missing after download", game.game_id))
        return
    }

    log_download(fmt.tprintf("[%s] cover saved: %s", game.game_id, cover_path))
}

gametdb_platform_type :: proc(platform: string) -> string {
    switch platform {
    case "GameCube":
        return "gc"
    case "Wii", "WiiWare":
        return "wii"
    }
    return "wii"
}

gametdb_region :: proc(region: string) -> string {
    switch region {
    case "USA", "NTSC-U":
        return "US"
    case "JPN", "NTSC-J":
        return "JA"
    case "EUR", "PAL":
        return "EN"
    }
    return "US"
}
