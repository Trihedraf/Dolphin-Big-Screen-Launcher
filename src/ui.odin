package main

import "core:fmt"
import "core:math"
import "core:slice"
import "core:strings"
import "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

UIState :: struct {
    selected_index:   int,
    coverflow_pos:    f32,
    platforms:        []string,
    platform_indices: map[string][dynamic]int,
    tab_index:        int,
}

cover_color_for_platform :: proc(platform: string) -> raylib.Color {
    switch platform {
    case "GameCube":
        return raylib.PURPLE
    case "Wii":
        return raylib.WHITE
    case "WiiWare":
        return raylib.SKYBLUE
    case "Homebrew":
        return raylib.ORANGE
    }
    return raylib.DARKGRAY
}

FRONT_COVER_WIDTH :: 480
FRONT_COVER_HEIGHT :: 680

init_ui_state :: proc() -> UIState {
    return UIState{selected_index = 0, coverflow_pos = 0, tab_index = 0}
}

cleanup_ui_state :: proc(state: ^UIState) {
    for platform in state.platforms {
        delete(platform)
    }
    delete(state.platforms)
    for _, indices in state.platform_indices {
        delete(indices)
    }
    delete(state.platform_indices)
    state.tab_index = 0
    state.selected_index = 0
    state.coverflow_pos = 0
}

init_ui_platforms :: proc(state: ^UIState, games: []Game) {
    cleanup_ui_state(state)

    state.platform_indices = make(map[string][dynamic]int)
    for game, index in games {
        indices := state.platform_indices[game.platform]
        append_elem(&indices, index)
        state.platform_indices[game.platform] = indices
    }

    for platform in state.platform_indices {
        indices := state.platform_indices[platform]
        n := len(indices)
        for i := 0; i < n; i += 1 {
            for j := i + 1; j < n; j += 1 {
                if games[indices[j]].title < games[indices[i]].title {
                    indices[i], indices[j] = indices[j], indices[i]
                }
            }
        }
    }

    state.platforms = make([]string, len(state.platform_indices))
    i := 0
    for platform in state.platform_indices {
        state.platforms[i] = strings.clone(platform)
        i += 1
    }
    slice.sort(state.platforms)

    if len(state.platforms) > 0 {
        state.tab_index = 0
        state.selected_index = first_index_for_platform(state, state.platforms[0])
    } else {
        state.tab_index = 0
        state.selected_index = 0
    }
}

first_index_for_platform :: proc(state: ^UIState, platform: string) -> int {
    indices := state.platform_indices[platform][:]
    if len(indices) > 0 {
        return indices[0]
    }
    return 0
}

current_platform :: proc(state: ^UIState) -> string {
    if state.tab_index >= 0 && state.tab_index < len(state.platforms) {
        return state.platforms[state.tab_index]
    }
    return ""
}

change_tab :: proc(state: ^UIState, delta: int) {
    if len(state.platforms) == 0 {
        return
    }
    state.tab_index += delta
    if state.tab_index < 0 {
        state.tab_index = len(state.platforms) - 1
    }
    if state.tab_index >= len(state.platforms) {
        state.tab_index = 0
    }
    platform := current_platform(state)
    state.selected_index = first_index_for_platform(state, platform)
    state.coverflow_pos = 0
}

move_selection_in_tab :: proc(state: ^UIState, delta: int) {
    platform := current_platform(state)
    indices := state.platform_indices[platform][:]
    if len(indices) == 0 {
        return
    }

    pos := -1
    for index, i in indices {
        if index == state.selected_index {
            pos = i
            break
        }
    }

    if pos < 0 {
        pos = 0
    }

    pos += delta
    if pos < 0 {
        pos = len(indices) - 1
    }
    if pos >= len(indices) {
        pos = 0
    }
    state.selected_index = indices[pos]
}

update_ui_state :: proc(state: ^UIState, games: []Game) {
    if len(games) == 0 {
        state.selected_index = 0
        return
    }

    if state.selected_index < 0 {
        state.selected_index = 0
    }
    if state.selected_index >= len(games) {
        state.selected_index = len(games) - 1
    }
}

draw_ui :: proc(state: ^UIState, games: []Game, wallpaper: raylib.Texture2D) {
    raylib.BeginDrawing()
    defer raylib.EndDrawing()

    raylib.ClearBackground(raylib.BLACK)

    if wallpaper.id != 0 {
        screen_w := f32(raylib.GetScreenWidth())
        screen_h := f32(raylib.GetScreenHeight())
        tex_w := f32(wallpaper.width)
        tex_h := f32(wallpaper.height)

        scale := math.max(screen_w / tex_w, screen_h / tex_h)
        w := tex_w * scale
        h := tex_h * scale

        source := raylib.Rectangle{0, 0, tex_w, tex_h}
        dest := raylib.Rectangle{(screen_w - w) / 2, (screen_h - h) / 2, w, h}
        origin := raylib.Vector2{0, 0}
        raylib.DrawTexturePro(wallpaper, source, dest, origin, 0, raylib.WHITE)
    }

    if len(games) == 0 {
        draw_empty_state()
        return
    }

    draw_coverflow_view(state, games)
    draw_tabs(state)
}

draw_tabs :: proc(state: ^UIState) {
    screen_w := f32(raylib.GetScreenWidth())
    tab_h: f32 = 80
    padding: f32 = 40

    if len(state.platforms) == 0 {
        return
    }

    raylib.DrawRectangle(0, 0, i32(screen_w), i32(tab_h), raylib.Color{20, 20, 20, 255})

    available_w := screen_w - padding * 2
    tab_w := available_w / f32(len(state.platforms))

    for platform, index in state.platforms {
        x := padding + f32(index) * tab_w
        y: f32 = 10
        is_selected := index == state.tab_index

        if is_selected {
            raylib.DrawRectangle(
                i32(x),
                i32(y),
                i32(tab_w),
                i32(tab_h - 20),
                raylib.Color{60, 60, 60, 255},
            )
            raylib.DrawRectangleLines(i32(x), i32(y), i32(tab_w), i32(tab_h - 20), raylib.YELLOW)
        }

        text := fmt.ctprintf("%s", platform)
        font_size: i32 = 32
        text_width := raylib.MeasureText(text, font_size)
        text_x := i32(x + (tab_w - f32(text_width)) / 2)
        text_y := i32(y + (tab_h - 20 - f32(font_size)) / 2)
        raylib.DrawText(text, text_x, text_y, font_size, raylib.RAYWHITE)
    }

    raylib.DrawRectangle(0, i32(tab_h), i32(screen_w), 2, raylib.Color{40, 40, 40, 255})
}

draw_coverflow_view :: proc(state: ^UIState, games: []Game) {
    screen_w := f32(raylib.GetScreenWidth())
    screen_h := f32(raylib.GetScreenHeight())

    cover_w: f32 = 320
    cover_h: f32 = 444
    center_y: f32 = 50
    max_offset := 4
    spacing: f32 = 320

    platform := current_platform(state)
    indices := state.platform_indices[platform][:]

    selected_pos := 0
    for index, i in indices {
        if index == state.selected_index {
            selected_pos = i
            break
        }
    }

    target := f32(selected_pos)
    if math.abs(target - state.coverflow_pos) > f32(max_offset + 1) {
        state.coverflow_pos = target
    } else {
        state.coverflow_pos += (target - state.coverflow_pos) * 0.18
    }

    center := state.coverflow_pos

    camera := raylib.Camera3D {
        position   = raylib.Vector3{0, 0, 1000},
        target     = raylib.Vector3{0, 0, 0},
        up         = raylib.Vector3{0, 1, 0},
        fovy       = 40,
        projection = .PERSPECTIVE,
    }

    // Increase far clip so rotated cover edges (which go to negative Z) aren't clipped.
    rlgl.SetClipPlanes(0.01, 2000)
    raylib.BeginMode3D(camera)
    rlgl.DisableBackfaceCulling()

    vis_pos: [dynamic]int
    defer delete(vis_pos)
    vis_off: [dynamic]f32
    defer delete(vis_off)

    start_pos := int(math.floor(center)) - max_offset - 1
    end_pos := int(math.ceil(center)) + max_offset + 1
    for pos := start_pos; pos <= end_pos; pos += 1 {
        if pos < 0 || pos >= len(indices) {
            continue
        }
        off := f32(pos) - center
        if math.abs(off) > f32(max_offset) + 0.5 {
            continue
        }
        append(&vis_pos, pos)
        append(&vis_off, off)
    }

    // Sort by abs(offset) descending; for ties, negative offset first so
    // the incoming (positive) cover draws on top during transitions.
    n := len(vis_pos)
    for i := 0; i < n; i += 1 {
        for j := i + 1; j < n; j += 1 {
            ai := math.abs(vis_off[i])
            aj := math.abs(vis_off[j])
            if aj > ai || (aj == ai && vis_off[j] < vis_off[i]) {
                vis_pos[i], vis_pos[j] = vis_pos[j], vis_pos[i]
                vis_off[i], vis_off[j] = vis_off[j], vis_off[i]
            }
        }
    }

    for i := 0; i < n; i += 1 {
        game := &games[indices[vis_pos[i]]]
        draw_coverflow_cover_3d(
            game.cover_texture,
            game.platform,
            center_y,
            cover_w,
            cover_h,
            vis_off[i],
            spacing,
        )
    }

    rlgl.EnableBackfaceCulling()
    raylib.EndMode3D()
    rlgl.SetClipPlanes(0.01, 1000)

    selected_game := &games[state.selected_index]
    title := fmt.ctprintf("%s", selected_game.title)
    meta := fmt.ctprintf("%s", selected_game.region)

    title_font_size: i32 = 48
    meta_font_size: i32 = 32
    title_width := raylib.MeasureText(title, title_font_size)
    meta_width := raylib.MeasureText(meta, meta_font_size)

    title_x := (i32(screen_w) - title_width) / 2
    meta_x := (i32(screen_w) - meta_width) / 2
    title_y := i32(screen_h - 120)
    meta_y := i32(screen_h - 60)

    raylib.DrawText(title, title_x, title_y, title_font_size, raylib.RAYWHITE)
    raylib.DrawText(meta, meta_x, meta_y, meta_font_size, raylib.GRAY)
}

draw_coverflow_cover_3d :: proc(
    texture: raylib.Texture2D,
    platform: string,
    center_y, cover_w, cover_h: f32,
    offset: f32,
    spacing: f32,
) {
    abs_offset := math.abs(offset)

    scale := 1.0 - abs_offset * 0.15
    if scale < 0.35 {
        scale = 0.35
    }
    angle := abs_offset * 25.0
    if angle > 75.0 {
        angle = 75.0
    }
    if offset < 0 {
        angle = -angle
    }

    w := cover_w * scale
    h := cover_h * scale
    x := offset * spacing

    hw := w / 2
    hh := h / 2

    cos_a := math.cos(angle * math.RAD_PER_DEG)
    sin_a := math.sin(angle * math.RAD_PER_DEG)

    // Normal after Y rotation (original normal is +Z).
    nx := sin_a
    nz := cos_a

    bl := raylib.Vector3{-hw * cos_a + x, -hh + center_y, -hw * sin_a}
    br := raylib.Vector3{hw * cos_a + x, -hh + center_y, hw * sin_a}
    tr := raylib.Vector3{hw * cos_a + x, hh + center_y, hw * sin_a}
    tl := raylib.Vector3{-hw * cos_a + x, hh + center_y, -hw * sin_a}

    if texture.id != 0 {
        tex_w := f32(texture.width)
        tex_h := f32(texture.height)
        front_w := tex_h * f32(FRONT_COVER_WIDTH) / f32(FRONT_COVER_HEIGHT)
        u0 := (tex_w - front_w) / tex_w
        u1 := f32(1)

        rlgl.SetTexture(texture.id)
        rlgl.Begin(rlgl.QUADS)
        rlgl.Color4ub(255, 255, 255, 255)
        rlgl.Normal3f(nx, 0, nz)
        rlgl.TexCoord2f(u0, 1); rlgl.Vertex3f(bl.x, bl.y, bl.z)
        rlgl.TexCoord2f(u1, 1); rlgl.Vertex3f(br.x, br.y, br.z)
        rlgl.TexCoord2f(u1, 0); rlgl.Vertex3f(tr.x, tr.y, tr.z)
        rlgl.TexCoord2f(u0, 0); rlgl.Vertex3f(tl.x, tl.y, tl.z)
        rlgl.End()
        rlgl.DisableTexture()
    } else {
        color := cover_color_for_platform(platform)
        rlgl.Begin(rlgl.QUADS)
        rlgl.Color4ub(color.r, color.g, color.b, color.a)
        rlgl.Normal3f(nx, 0, nz)
        rlgl.Vertex3f(bl.x, bl.y, bl.z)
        rlgl.Vertex3f(br.x, br.y, br.z)
        rlgl.Vertex3f(tr.x, tr.y, tr.z)
        rlgl.Vertex3f(tl.x, tl.y, tl.z)
        rlgl.End()
    }
}

draw_empty_state :: proc() {
    text := cstring("No games found. Check your Dolphin library paths.")
    text_width := raylib.MeasureText(text, 30)
    x := (raylib.GetScreenWidth() - text_width) / 2
    y := raylib.GetScreenHeight() / 2 - 15
    raylib.DrawText(text, x, y, 30, raylib.GRAY)
}
