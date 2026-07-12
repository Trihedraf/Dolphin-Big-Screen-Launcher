package main

import "core:fmt"
import "core:os"
import "core:strings"

JS_BTN_A :: 0
JS_BTN_B :: 1
JS_BTN_X :: 2
JS_BTN_Y :: 3
JS_BTN_LB :: 4
JS_BTN_RB :: 5
JS_BTN_BACK :: 6
JS_BTN_START :: 7

JS_AXIS_LEFT_X :: 0
JS_AXIS_LEFT_Y :: 1
JS_AXIS_DPAD_X :: 6
JS_AXIS_DPAD_Y :: 7

MAX_LINUX_GAMEPADS :: 4

when ODIN_OS == .Linux {

    JS_EVENT_BUTTON :: u8(0x01)
    JS_EVENT_AXIS :: u8(0x02)
    JS_EVENT_INIT :: u8(0x80)

    LinuxGamepadState :: struct {
        file:               ^os.File,
        available:          bool,
        button_states:      [16]bool,
        prev_button_states: [16]bool,
        axis_values:        [8]i16,
    }

    linux_gamepads: [MAX_LINUX_GAMEPADS]LinuxGamepadState
    num_linux_gamepads: int

    linux_gamepad_init :: proc() {
        num_linux_gamepads = 0
        for i := 0; i < MAX_LINUX_GAMEPADS; i += 1 {
            path := fmt.tprintf("/dev/input/js%d", i)
            f, err := os.open(path, os.File_Flags{.Read, .Non_Blocking})
            if err != os.ERROR_NONE || f == nil {
                continue
            }

            name_path := fmt.tprintf("/sys/class/input/js%d/device/name", i)
            name_data, _ := os.read_entire_file(name_path, context.temp_allocator)
            device_name := strings.trim_space(string(name_data))

            if device_name != "" {
                lower := strings.to_lower(device_name, context.temp_allocator)
                sensor_keywords := [6]string {
                    "accel",
                    "gyro",
                    "sensor",
                    "touchpad",
                    "touch",
                    "mouse",
                }
                is_sensor := false
                for kw in sensor_keywords {
                    if strings.index(lower, kw) >= 0 {
                        is_sensor = true
                        break
                    }
                }
                if is_sensor {
                    if verbose {
                        fmt.println("Skipping non-gamepad:", path, "name:", device_name)
                    }
                    os.close(f)
                    continue
                }
            }

            buf: [512]u8
            num_axes := 0
            num_buttons := 0
            gp := &linux_gamepads[num_linux_gamepads]

            for {
                n, read_err := os.read(f, buf[:])
                if read_err != os.ERROR_NONE || n < 8 {
                    break
                }
                offset := 0
                for offset + 8 <= n {
                    ev_type := buf[offset + 6]
                    ev_number := buf[offset + 7]
                    ev_value := cast(i16)(cast(u16)(buf[offset + 4]) |
                        (cast(u16)(buf[offset + 5]) << 8))

                    raw_type := ev_type & ~JS_EVENT_INIT
                    is_init := (ev_type & JS_EVENT_INIT) != 0

                    if is_init {
                        idx := int(ev_number)
                        if raw_type == JS_EVENT_AXIS {
                            if idx < len(gp.axis_values) {
                                gp.axis_values[idx] = ev_value
                            }
                            if idx + 1 > num_axes {
                                num_axes = idx + 1
                            }
                        } else if raw_type == JS_EVENT_BUTTON {
                            if idx < len(gp.button_states) {
                                gp.button_states[idx] = ev_value != 0
                            }
                            if idx + 1 > num_buttons {
                                num_buttons = idx + 1
                            }
                        }
                    }

                    offset += 8
                }
                if n < len(buf) {
                    break
                }
            }

            if num_axes >= 2 && num_buttons >= 4 {
                gp.file = f
                gp.available = true
                num_linux_gamepads += 1
                if verbose {
                    fmt.println(
                        "Linux gamepad opened:",
                        path,
                        "name:",
                        device_name,
                        "(",
                        num_axes,
                        "axes,",
                        num_buttons,
                        "buttons )",
                    )
                    for a := 0; a < num_axes && a < len(gp.axis_values); a += 1 {
                        fmt.println("  axis", a, "=", gp.axis_values[a])
                    }
                }
            } else {
                if verbose {
                    fmt.println("Skipping non-gamepad:", path, "name:", device_name)
                }
                os.close(f)
            }
        }
    }

    linux_gamepad_poll :: proc() {
        for i := 0; i < num_linux_gamepads; i += 1 {
            gp := &linux_gamepads[i]
            if !gp.available || gp.file == nil {
                continue
            }

            for j := 0; j < len(gp.button_states); j += 1 {
                gp.prev_button_states[j] = gp.button_states[j]
            }

            buf: [512]u8
            for {
                n, err := os.read(gp.file, buf[:])
                if err != os.ERROR_NONE || n < 8 {
                    break
                }

                offset := 0
                for offset + 8 <= n {
                    ev_type := buf[offset + 6]
                    ev_number := buf[offset + 7]
                    ev_value := cast(i16)(cast(u16)(buf[offset + 4]) |
                        (cast(u16)(buf[offset + 5]) << 8))

                    raw_type := ev_type & ~JS_EVENT_INIT

                    if raw_type == JS_EVENT_BUTTON && ev_number < len(gp.button_states) {
                        gp.button_states[ev_number] = ev_value != 0
                    } else if raw_type == JS_EVENT_AXIS && ev_number < len(gp.axis_values) {
                        gp.axis_values[ev_number] = ev_value
                    }

                    offset += 8
                }

                if n < len(buf) {
                    break
                }
            }
        }
    }

    linux_gamepad_close :: proc() {
        for i := 0; i < num_linux_gamepads; i += 1 {
            gp := &linux_gamepads[i]
            if gp.file != nil {
                os.close(gp.file)
                gp.file = nil
            }
            gp.available = false
        }
        num_linux_gamepads = 0
    }

    linux_gamepad_available :: proc(idx: int) -> bool {
        if idx < 0 || idx >= num_linux_gamepads {
            return false
        }
        return linux_gamepads[idx].available
    }

    linux_gamepad_axis :: proc(idx: int, axis: int) -> f32 {
        if idx < 0 || idx >= num_linux_gamepads {
            return 0
        }
        gp := &linux_gamepads[idx]
        if axis < 0 || axis >= len(gp.axis_values) {
            return 0
        }
        return f32(gp.axis_values[axis]) / 32767.0
    }

    linux_gamepad_button_down :: proc(idx: int, btn: int) -> bool {
        if idx < 0 || idx >= num_linux_gamepads {
            return false
        }
        gp := &linux_gamepads[idx]
        if btn < 0 || btn >= len(gp.button_states) {
            return false
        }
        return gp.button_states[btn]
    }

    linux_gamepad_button_pressed :: proc(idx: int, btn: int) -> bool {
        if idx < 0 || idx >= num_linux_gamepads {
            return false
        }
        gp := &linux_gamepads[idx]
        if btn < 0 || btn >= len(gp.button_states) {
            return false
        }
        return gp.button_states[btn] && !gp.prev_button_states[btn]
    }

} else {

    linux_gamepad_init :: proc() {}
    linux_gamepad_poll :: proc() {}
    linux_gamepad_close :: proc() {}
    linux_gamepad_available :: proc(idx: int) -> bool {return false}
    linux_gamepad_axis :: proc(idx: int, axis: int) -> f32 {return 0}
    linux_gamepad_button_down :: proc(idx: int, btn: int) -> bool {return false}
    linux_gamepad_button_pressed :: proc(idx: int, btn: int) -> bool {return false}

}
