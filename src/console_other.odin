#+build !windows

package main

import "core:fmt"

console_print :: proc(text: string) {
    fmt.print(text)
}
