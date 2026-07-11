package main

import "core:fmt"
import "core:os"

launch_game :: proc(dolphin_executable: string, game_path: string, user_dir: string) -> bool {
    if dolphin_executable == "" || game_path == "" {
        return false
    }

    if verbose {
        fmt.println("Launching:", game_path)
    }

    command: [dynamic]string
    defer delete(command)
    append(&command, dolphin_executable)
    if user_dir != "" {
        append(&command, "-u")
        append(&command, user_dir)
    }
    append(&command, "-b")
    append(&command, "-C")
    append(&command, "Main.Display.Fullscreen=True")
    append(&command, "-e")
    append(&command, game_path)

    desc := os.Process_Desc {
        command = command[:],
    }

    process, err := os.process_start(desc)
    if err != os.ERROR_NONE {
        fmt.println("Failed to start Dolphin:", err)
        return false
    }

    _, _ = os.process_wait(process)

    if verbose {
        fmt.println("Dolphin exited.")
    }
    return true
}
