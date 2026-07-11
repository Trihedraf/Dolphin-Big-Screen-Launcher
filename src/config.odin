package main

import "core:encoding/json"
import "core:os"
import "core:path/filepath"

CONFIG_FILE_NAME :: "dbsl.json"

LauncherConfig :: struct {
    dolphin_executable: string `json:"dolphin_executable"`,
    dolphin_user_dir:   string `json:"dolphin_user_dir"`,
    fullscreen:         bool `json:"fullscreen"`,
    wallpaper:          string `json:"wallpaper"`,
}

default_config :: proc() -> LauncherConfig {
    return LauncherConfig{fullscreen = true}
}

load_config :: proc() -> (cfg: LauncherConfig, ok: bool) {
    cfg = default_config()

    path := get_config_path()
    if path == "" {
        return cfg, false
    }

    data, err := os.read_entire_file(path, context.temp_allocator)
    if err != os.ERROR_NONE {
        return cfg, false
    }

    // Escape lone backslashes so Windows paths (e.g. C:\Games\Dolphin.exe)
    // survive JSON parsing. Without this, \U/\D are invalid escapes that
    // truncate the string, and \f/\n/\t become control characters.
    processed := escape_lone_backslashes(data)

    unmarshal_err := json.unmarshal(processed, &cfg)
    if unmarshal_err != nil {
        return cfg, false
    }

    return cfg, true
}

escape_lone_backslashes :: proc(data: []byte) -> []byte {
    count := 0
    i := 0
    for i < len(data) {
        if data[i] == '\\' {
            if i + 1 < len(data) && data[i + 1] == '\\' {
                i += 2
                continue
            }
            count += 1
        }
        i += 1
    }

    if count == 0 {
        return data
    }

    result := make([]byte, len(data) + count)
    j := 0
    i = 0
    for i < len(data) {
        if data[i] == '\\' {
            if i + 1 < len(data) && data[i + 1] == '\\' {
                result[j] = '\\'
                result[j + 1] = '\\'
                j += 2
                i += 2
                continue
            }
            result[j] = '\\'
            result[j + 1] = '\\'
            j += 2
            i += 1
            continue
        }
        result[j] = data[i]
        j += 1
        i += 1
    }
    return result
}

save_config :: proc(cfg: LauncherConfig) -> bool {
    path := get_config_path()
    if path == "" {
        return false
    }

    dir := filepath.dir(path)
    if dir != "" && !os.exists(dir) {
        if os.make_directory_all(dir) != os.ERROR_NONE {
            return false
        }
    }

    data, marshal_err := json.marshal(cfg, {pretty = true})
    if marshal_err != nil {
        return false
    }

    return os.write_entire_file(path, data) == os.ERROR_NONE
}

get_config_path :: proc() -> string {
    exe_dir, exe_err := os.get_executable_directory(context.temp_allocator)
    if exe_err != os.ERROR_NONE {
        return ""
    }
    path, _ := filepath.join({exe_dir, CONFIG_FILE_NAME}, context.temp_allocator)
    return path
}
