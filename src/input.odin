package main

import "core:math"
import "vendor:raylib"

Direction :: enum {
    Up,
    Down,
    Left,
    Right,
}

InputState :: struct {
    held:         [Direction]bool,
    held_time:    [Direction]f32,
    repeat_timer: [Direction]f32,
    moved:        [Direction]bool,
}

INPUT_INITIAL_DELAY :: f32(0.35)
INPUT_INITIAL_INTERVAL :: f32(0.28)
INPUT_MIN_INTERVAL :: f32(0.04)
INPUT_ACCEL_TIME :: f32(1.2)
INPUT_STICK_THRESHOLD :: f32(0.5)
MAX_RAYLIB_GAMEPADS :: 4

update_input :: proc(state: ^InputState) {
    dt := raylib.GetFrameTime()

    for dir in Direction {
        pressed := is_direction_pressed(dir)
        was_held := state.held[dir]

        if pressed && !was_held {
            state.held[dir] = true
            state.held_time[dir] = 0
            state.repeat_timer[dir] = INPUT_INITIAL_DELAY
            state.moved[dir] = true
        } else if pressed && was_held {
            // Held: accumulate time and trigger repeats.
            state.held_time[dir] += dt
            state.repeat_timer[dir] -= dt

            moved := false
            for state.repeat_timer[dir] <= 0 {
                moved = true
                interval := current_repeat_interval(state.held_time[dir])
                state.repeat_timer[dir] += interval
            }
            state.moved[dir] = moved
        } else {
            state.held[dir] = false
            state.held_time[dir] = 0
            state.repeat_timer[dir] = 0
            state.moved[dir] = false
        }
    }
}

raylib_gamepad_axis_x :: proc(gamepad: i32) -> f32 {
    return raylib.GetGamepadAxisMovement(gamepad, .LEFT_X)
}

raylib_gamepad_axis_y :: proc(gamepad: i32) -> f32 {
    return raylib.GetGamepadAxisMovement(gamepad, .LEFT_Y)
}

DPAD_AXIS_THRESHOLD :: f32(0.5)

is_direction_pressed :: proc(dir: Direction) -> bool {
    // Raylib gamepads
    for i := i32(0); i < MAX_RAYLIB_GAMEPADS; i += 1 {
        if !raylib.IsGamepadAvailable(i) {
            continue
        }
        switch dir {
        case .Up:
            if raylib.IsGamepadButtonDown(i, .LEFT_FACE_UP) ||
                    raylib_gamepad_axis_y(i) < -INPUT_STICK_THRESHOLD {
                return true
            }
        case .Down:
            if raylib.IsGamepadButtonDown(i, .LEFT_FACE_DOWN) ||
                    raylib_gamepad_axis_y(i) > INPUT_STICK_THRESHOLD {
                return true
            }
        case .Left:
            if raylib.IsGamepadButtonDown(i, .LEFT_FACE_LEFT) ||
                    raylib_gamepad_axis_x(i) < -INPUT_STICK_THRESHOLD {
                return true
            }
        case .Right:
            if raylib.IsGamepadButtonDown(i, .LEFT_FACE_RIGHT) ||
                    raylib_gamepad_axis_x(i) > INPUT_STICK_THRESHOLD {
                return true
            }
        }
    }

    // Linux joydev gamepads
    when ODIN_OS == .Linux {
        for i := 0; i < MAX_LINUX_GAMEPADS; i += 1 {
            if !linux_gamepad_available(i) {
                continue
            }
            switch dir {
            case .Up:
                if linux_gamepad_axis(i, JS_AXIS_LEFT_Y) < -INPUT_STICK_THRESHOLD ||
                        linux_gamepad_axis(i, JS_AXIS_DPAD_Y) < -DPAD_AXIS_THRESHOLD {
                    return true
                }
            case .Down:
                if linux_gamepad_axis(i, JS_AXIS_LEFT_Y) > INPUT_STICK_THRESHOLD ||
                        linux_gamepad_axis(i, JS_AXIS_DPAD_Y) > DPAD_AXIS_THRESHOLD {
                    return true
                }
            case .Left:
                if linux_gamepad_axis(i, JS_AXIS_LEFT_X) < -INPUT_STICK_THRESHOLD ||
                        linux_gamepad_axis(i, JS_AXIS_DPAD_X) < -DPAD_AXIS_THRESHOLD {
                    return true
                }
            case .Right:
                if linux_gamepad_axis(i, JS_AXIS_LEFT_X) > INPUT_STICK_THRESHOLD ||
                        linux_gamepad_axis(i, JS_AXIS_DPAD_X) > DPAD_AXIS_THRESHOLD {
                    return true
                }
            }
        }
    }

    // Keyboard
    switch dir {
    case .Up:
        return raylib.IsKeyDown(.UP) || raylib.IsKeyDown(.W)
    case .Down:
        return raylib.IsKeyDown(.DOWN) || raylib.IsKeyDown(.S)
    case .Left:
        return raylib.IsKeyDown(.LEFT) || raylib.IsKeyDown(.A)
    case .Right:
        return raylib.IsKeyDown(.RIGHT) || raylib.IsKeyDown(.D)
    }
    return false
}

current_repeat_interval :: proc(held_time: f32) -> f32 {
    t := math.clamp(held_time / INPUT_ACCEL_TIME, 0, 1)
    return math.lerp(INPUT_INITIAL_INTERVAL, INPUT_MIN_INTERVAL, t)
}

navigation_delta :: proc(state: ^InputState) -> (delta: int) {
    if state.moved[.Up] {delta -= 1}
    if state.moved[.Down] {delta += 1}

    return delta
}

tab_delta :: proc(state: ^InputState) -> (delta: int) {
    if state.moved[.Left] {delta -= 1}
    if state.moved[.Right] {delta += 1}

    return delta
}

raylib_to_joydev_button :: proc(button: raylib.GamepadButton) -> int {
    #partial switch button {
    case .RIGHT_FACE_DOWN:
        return 0
    case .RIGHT_FACE_RIGHT:
        return 1
    case .RIGHT_FACE_LEFT:
        return 2
    case .RIGHT_FACE_UP:
        return 3
    case .LEFT_TRIGGER_1:
        return 4
    case .RIGHT_TRIGGER_1:
        return 5
    case .MIDDLE_LEFT:
        return 6
    case .MIDDLE_RIGHT:
        return 7
    }
    return -1
}

is_action_pressed :: proc(button: raylib.GamepadButton, key: raylib.KeyboardKey) -> bool {
    joy_btn := raylib_to_joydev_button(button)

    // Raylib gamepads
    for i := i32(0); i < MAX_RAYLIB_GAMEPADS; i += 1 {
        if raylib.IsGamepadAvailable(i) && raylib.IsGamepadButtonPressed(i, button) {
            return true
        }
    }

    // Linux joydev gamepads
    when ODIN_OS == .Linux {
        for i := 0; i < MAX_LINUX_GAMEPADS; i += 1 {
            if linux_gamepad_button_pressed(i, joy_btn) {
                return true
            }
        }
    }

    // Keyboard
    return raylib.IsKeyPressed(key)
}
