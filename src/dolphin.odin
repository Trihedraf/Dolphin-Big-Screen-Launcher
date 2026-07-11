package main

import "core:encoding/ini"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"

DolphinPaths :: struct {
    user_dir:    string,
    config_file: string,
    sys_dir:     string,
}

resolve_dolphin_paths :: proc(cfg: LauncherConfig) -> (paths: DolphinPaths, ok: bool) {
    user_dir := cfg.dolphin_user_dir
    if user_dir == "" {
        user_dir = resolve_dolphin_user_dir(cfg.dolphin_executable)
    }

    if user_dir == "" {
        return paths, false
    }

    paths.user_dir = user_dir
    paths.config_file, _ = filepath.join({user_dir, "Config", "Dolphin.ini"})

    exe_dir := filepath.dir(cfg.dolphin_executable)

    sys_candidates: [dynamic]string
    defer delete(sys_candidates)

    p, _ := filepath.join({exe_dir, "Sys"})
    append(&sys_candidates, p)
    p, _ = filepath.join({exe_dir, "sys"})
    append(&sys_candidates, p)
    p, _ = filepath.join({user_dir, "Sys"})
    append(&sys_candidates, p)
    p, _ = filepath.join({user_dir, "sys"})
    append(&sys_candidates, p)

    linux_sys := [3]string {
        "/usr/share/dolphin-emu/sys",
        "/usr/share/games/dolphin-emu/sys",
        "/usr/local/share/dolphin-emu/sys",
    }
    for sys_path in linux_sys {
        append(&sys_candidates, sys_path)
    }

    for candidate in sys_candidates {
        if candidate != "" && os.exists(candidate) {
            paths.sys_dir = candidate
            break
        }
    }

    return paths, true
}

resolve_dolphin_user_dir :: proc(dolphin_executable: string) -> string {
    if dolphin_executable == "" {
        return ""
    }

    exe_dir := filepath.dir(dolphin_executable)

    portable_file, _ := filepath.join({exe_dir, "portable.txt"})
    if os.exists(portable_file) {
        user_dir, _ := filepath.join({exe_dir, "User"})
        return user_dir
    }

    when ODIN_OS == .Windows {
        home := os.get_env("USERPROFILE", context.temp_allocator)
        legacy_path, _ := filepath.join({home, "Documents", "Dolphin Emulator"})
        if os.exists(legacy_path) {
            return legacy_path
        }
        appdata := os.get_env("APPDATA", context.temp_allocator)
        if appdata != "" {
            path, _ := filepath.join({appdata, "Dolphin Emulator"})
            return path
        }
    } else when ODIN_OS == .Darwin {
        env_path := os.get_env("DOLPHIN_EMU_USERPATH", context.temp_allocator)
        if env_path != "" {
            return env_path
        }
        home := os.get_env("HOME", context.temp_allocator)
        if home != "" {
            path, _ := filepath.join({home, "Library/Application Support/Dolphin"})
            return path
        }
    } else when ODIN_OS == .Linux {
        env_path := os.get_env("DOLPHIN_EMU_USERPATH", context.temp_allocator)
        if env_path != "" {
            return env_path
        }
        home := os.get_env("HOME", context.temp_allocator)
        if home == "" {
            return ""
        }
        legacy_path, _ := filepath.join({home, ".dolphin-emu"})
        if os.exists(legacy_path) {
            return legacy_path
        }
        xdg_data := os.get_env("XDG_DATA_HOME", context.temp_allocator)
        if xdg_data != "" {
            path, _ := filepath.join({xdg_data, "dolphin-emu"})
            return path
        }
        path, _ := filepath.join({home, ".local/share/dolphin-emu"})
        return path
    }

    return ""
}

read_iso_paths :: proc(paths: DolphinPaths) -> []string {
    if paths.config_file == "" || !os.exists(paths.config_file) {
        return nil
    }

    data, err := os.read_entire_file(paths.config_file, context.temp_allocator)
    if err != os.ERROR_NONE {
        return nil
    }

    m, map_err := ini.load_map_from_string(string(data), context.allocator)
    if map_err != nil {
        return nil
    }
    defer ini.delete_map(m)

    general := m["General"]
    if general == nil {
        return nil
    }

    count_str := general["ISOPaths"]
    if count_str == "" {
        return nil
    }

    count, count_ok := strconv.parse_int(count_str)
    if !count_ok || count <= 0 {
        return nil
    }

    result := make([dynamic]string, 0, count)
    for i := 0; i < count; i += 1 {
        key := fmt.tprintf("ISOPath%d", i)
        value := general[key]
        if value != "" {
            append(&result, strings.clone(value))
        }
    }

    return result[:]
}

is_recursive_iso_paths :: proc(paths: DolphinPaths) -> bool {
    if paths.config_file == "" || !os.exists(paths.config_file) {
        return false
    }

    data, err := os.read_entire_file(paths.config_file, context.temp_allocator)
    if err != os.ERROR_NONE {
        return false
    }

    m, map_err := ini.load_map_from_string(string(data), context.allocator)
    if map_err != nil {
        return false
    }
    defer ini.delete_map(m)

    general := m["General"]
    if general == nil {
        return false
    }

    value := general["RecursiveISOPaths"]
    if value == "" {
        return false
    }

    return strings.to_lower(value) == "true"
}
