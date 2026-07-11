package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:sync"
import "core:thread"
import "vendor:raylib"

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720
TARGET_FPS :: 60

DBSL_VERSION :: #config(DBSL_VERSION, "dev")

verbose: bool

AppState :: enum {
    Library,
    Error,
}

DownloadWork :: struct {
    games:       []Game,
    covers_dir:  string,
    index:       int,
    should_stop: bool,
    mutex:       sync.Mutex,
}

App :: struct {
    state:                     AppState,
    should_close:              bool,
    error_message:             string,
    cfg:                       LauncherConfig,
    games:                     []Game,
    ui_state:                  UIState,
    input_state:               InputState,
    pending_fullscreen_toggle: bool,
    wallpaper_texture:         raylib.Texture2D,
    dolphin_user_dir:          string,
    download_thread:           ^thread.Thread,
    download_work:             DownloadWork,
    frame_count:               int,
}

main :: proc() {
    app: App
    app.cfg, _ = load_config()
    if parse_args(&app.cfg) {
        print_help()
        return
    }

    if verbose {
        fmt.println("Dolphin executable:", app.cfg.dolphin_executable)
        fmt.println("Fullscreen:", app.cfg.fullscreen)
    }

    if app.cfg.dolphin_executable == "" {
        set_error(
            &app,
            "Dolphin executable is not configured.\nEdit dbsl.json and set dolphin_executable.",
        )
    } else if !os.exists(app.cfg.dolphin_executable) {
        set_error(
            &app,
            fmt.tprintf("Dolphin executable not found:\n%s", app.cfg.dolphin_executable),
        )
    } else {
        load_games(&app)
    }

    app.ui_state = init_ui_state()
    start_cover_download_thread(&app, app.dolphin_user_dir)

    raylib.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, cstring("Dolphin Big Screen Launcher"))
    raylib.SetTargetFPS(TARGET_FPS)

    if app.cfg.fullscreen {
        raylib.ToggleBorderlessWindowed()
    }

    // Gamepad detection.
    gamepad_count := 0
    for i := 0; i < 4; i += 1 {
        if raylib.IsGamepadAvailable(i32(i)) {
            if verbose {
                name := raylib.GetGamepadName(i32(i))
                fmt.println("Gamepad", i, ":", name)
            }
            gamepad_count += 1
        }
    }
    if gamepad_count == 0 && verbose {
        fmt.println("WARNING: No gamepad detected via raylib.")
        when ODIN_OS == .Linux {
            fmt.println("Attempting joydev fallback...")
        }
    }

    when ODIN_OS == .Linux {
        linux_gamepad_init()
        if verbose && linux_gamepad_available() {
            fmt.println("Joydev gamepad fallback active.")
        }
    }

    init_ui_platforms(&app.ui_state, app.games)

    // Textures must be loaded after the window/GL context exists.
    load_game_cover_textures(app.games)
    load_wallpaper(&app)

    for !raylib.WindowShouldClose() && !app.should_close {
        if app.pending_fullscreen_toggle {
            raylib.ToggleBorderlessWindowed()
            reload_game_cover_textures(app.games)
            reload_wallpaper(&app)
            app.pending_fullscreen_toggle = false
        }

        update_input(&app.input_state)
        when ODIN_OS == .Linux {
            linux_gamepad_poll()
        }
        handle_global_input(&app)

        switch app.state {
        case .Library:
            handle_library_input(&app)
            update_ui_state(&app.ui_state, app.games)
            draw_ui(&app.ui_state, app.games, app.wallpaper_texture)
        case .Error:
            draw_error_screen(app.error_message)
        }

        // Periodically load textures for covers downloaded in the background.
        app.frame_count += 1
        if app.frame_count % 30 == 0 {
            load_game_cover_textures(app.games)
        }
    }

    stop_cover_download_thread(&app)
    when ODIN_OS == .Linux {
        linux_gamepad_close()
    }
    cleanup_ui_state(&app.ui_state)
    cleanup_games(app.games)
    if app.wallpaper_texture.id != 0 {
        raylib.UnloadTexture(app.wallpaper_texture)
    }
    raylib.CloseWindow()
}

set_error :: proc(app: ^App, message: string) {
    app.state = .Error
    app.error_message = strings.clone(message)
}

parse_args :: proc(cfg: ^LauncherConfig) -> (show_help: bool) {
    args := os.args
    i := 1
    for i < len(args) {
        arg := args[i]
        if arg == "-v" {
            verbose = true
            i += 1
        } else if arg == "-d" && i + 1 < len(args) {
            cfg.dolphin_executable = args[i + 1]
            i += 2
        } else if arg == "-u" && i + 1 < len(args) {
            cfg.dolphin_user_dir = args[i + 1]
            i += 2
        } else if arg == "-w" && i + 1 < len(args) {
            cfg.wallpaper = args[i + 1]
            i += 2
        } else {
            return true
        }
    }
    return false
}

print_help :: proc() {
    help := "DBSL " + DBSL_VERSION +
        "\n\nUsage: dbsl [-v] [-d <path>] [-u <path>] [-w <path>]" +
        "\n\nOptions:" +
        "\n  -h          Show this help" +
        "\n  -v          Verbose output" +
        "\n  -d <path>   Dolphin executable path" +
        "\n  -u <path>   Dolphin user directory" +
        "\n  -w <path>   Wallpaper image path\n"

    console_print(help)
}

load_wallpaper :: proc(app: ^App) {
    if app.cfg.wallpaper == "" || !os.exists(app.cfg.wallpaper) {
        return
    }
    wallpaper_cstr := strings.clone_to_cstring(app.cfg.wallpaper)
    app.wallpaper_texture = raylib.LoadTexture(wallpaper_cstr)
    delete(wallpaper_cstr)
    if app.wallpaper_texture.id != 0 {
        raylib.SetTextureFilter(app.wallpaper_texture, .BILINEAR)
    }
}

reload_wallpaper :: proc(app: ^App) {
    if app.wallpaper_texture.id != 0 {
        raylib.UnloadTexture(app.wallpaper_texture)
        app.wallpaper_texture = raylib.Texture2D{}
    }
    load_wallpaper(app)
}

load_games :: proc(app: ^App) {
    paths, paths_ok := resolve_dolphin_paths(app.cfg)
    if !paths_ok {
        set_error(
            app,
            "Could not resolve Dolphin paths.\nCheck dolphin_executable and dolphin_user_dir in dbsl.json.",
        )
        return
    }

    if verbose {
        fmt.println("Dolphin user dir:", paths.user_dir)
        fmt.println("Dolphin config:", paths.config_file)
        fmt.println("Dolphin sys dir:", paths.sys_dir)
    }

    app.dolphin_user_dir = paths.user_dir

    iso_paths := read_iso_paths(paths)
    recursive := is_recursive_iso_paths(paths)
    app.games = scan_game_library(iso_paths, recursive)

    title_db := load_title_database(paths)
    apply_titles(app.games, title_db)

    load_game_cover_paths(app.games, paths.user_dir)

    if verbose {
        fmt.println("Games found:", len(app.games))
    }
}

start_cover_download_thread :: proc(app: ^App, user_dir: string) {
    if len(app.games) == 0 || user_dir == "" {
        if verbose {
            fmt.println("No games to download covers for")
        }
        return
    }

    covers_dir, _ := filepath.join({user_dir, "Cache", "GameCoversHQ"})
    if !os.exists(covers_dir) {
        if os.make_directory_all(covers_dir) != os.ERROR_NONE {
            fmt.println("Failed to create covers directory:", covers_dir)
            return
        }
    }

    log_path, _ := filepath.join({covers_dir, "download.log"})
    set_download_log_path(log_path)
    log_download(
        fmt.tprintf(
            "start_cover_download_thread: %d games, user_dir=%s",
            len(app.games),
            user_dir,
        ),
    )

    app.download_work = DownloadWork {
        games      = app.games,
        covers_dir = covers_dir,
        index      = 0,
    }
    app.download_thread = thread.create(cover_download_worker)
    if app.download_thread == nil {
        log_download("Failed to create cover download thread")
        return
    }
    app.download_thread.data = &app.download_work
    thread.start(app.download_thread)
    log_download("Cover download thread started")
}

stop_cover_download_thread :: proc(app: ^App) {
    if app.download_thread == nil {
        return
    }
    log_download("Stopping cover download thread")
    sync.mutex_lock(&app.download_work.mutex)
    app.download_work.should_stop = true
    sync.mutex_unlock(&app.download_work.mutex)
    thread.join(app.download_thread)
    thread.destroy(app.download_thread)
    app.download_thread = nil
    log_download("Cover download thread stopped")
}

cover_download_worker :: proc(t: ^thread.Thread) {
    work := cast(^DownloadWork)t.data
    log_download("Worker thread running")
    for {
        sync.mutex_lock(&work.mutex)
        if work.should_stop || work.index >= len(work.games) {
            sync.mutex_unlock(&work.mutex)
            log_download("Worker thread exiting")
            return
        }
        game := work.games[work.index]
        work.index += 1
        sync.mutex_unlock(&work.mutex)

        if game.cover_path != "" && !os.exists(game.cover_path) {
            download_cover(game, work.covers_dir)
        }
    }
}

handle_global_input :: proc(app: ^App) {
    if is_action_pressed(.MIDDLE_LEFT, .ESCAPE) {
        app.should_close = true
        return
    }

    if raylib.IsKeyPressed(.F) {
        app.pending_fullscreen_toggle = true
    }
}

handle_library_input :: proc(app: ^App) {
    if len(app.games) == 0 {
        return
    }

    launch :=
        is_action_pressed(.RIGHT_FACE_DOWN, .ENTER) ||
        raylib.IsKeyPressed(.SPACE) ||
        (raylib.IsGamepadAvailable(0) && raylib.IsGamepadButtonPressed(0, .MIDDLE_RIGHT))
    when ODIN_OS == .Linux {
        launch = launch || linux_gamepad_button_pressed(JS_BTN_START)
    }
    if launch {
        game := &app.games[app.ui_state.selected_index]

        raylib.SetWindowState({.WINDOW_HIDDEN})

        launch_game(app.cfg.dolphin_executable, game.path, app.dolphin_user_dir)

        raylib.ClearWindowState({.WINDOW_HIDDEN})
        return
    }

    // Left/Right d-pad: move through games.
    t_delta := tab_delta(&app.input_state)
    if t_delta != 0 {
        move_selection_in_tab(&app.ui_state, t_delta)
    }

    // L1/R1: switch systems.
    if is_action_pressed(.LEFT_TRIGGER_1, .Q) {
        change_tab(&app.ui_state, -1)
    }
    if is_action_pressed(.RIGHT_TRIGGER_1, .E) {
        change_tab(&app.ui_state, 1)
    }
}

draw_error_screen :: proc(message: string) {
    raylib.BeginDrawing()
    defer raylib.EndDrawing()

    raylib.ClearBackground(raylib.BLACK)

    title := cstring("Error")
    title_width := raylib.MeasureText(title, 40)
    raylib.DrawText(title, (raylib.GetScreenWidth() - title_width) / 2, 80, 40, raylib.RED)

    lines := strings.split(message, "\n", context.temp_allocator)
    y: i32 = 180
    for line in lines {
        cstr := fmt.ctprintf("%s", line)
        width := raylib.MeasureText(cstr, 24)
        x := (raylib.GetScreenWidth() - width) / 2
        raylib.DrawText(cstr, x, y, 24, raylib.RAYWHITE)
        y += 36
    }

    hint := cstring("Press Start / Escape to exit.")
    hint_width := raylib.MeasureText(hint, 20)
    raylib.DrawText(hint, (raylib.GetScreenWidth() - hint_width) / 2, y + 40, 20, raylib.GRAY)
}
