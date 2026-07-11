#+build windows

package main

import "core:sys/windows"

console_print :: proc(text: string) {
    windows.AttachConsole(windows.DWORD(0xFFFFFFFF))
    handle := windows.GetStdHandle(windows.STD_OUTPUT_HANDLE)
    written: windows.DWORD
    windows.WriteFile(handle, raw_data(text), windows.DWORD(len(text)), &written, nil)
}
