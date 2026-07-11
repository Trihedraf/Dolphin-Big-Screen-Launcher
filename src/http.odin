package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

// Download a file from url to output_path without calling an external program.
download_file :: proc(url: string, output_path: string) -> bool {
    when ODIN_OS == .Windows {
        return download_file_windows(url, output_path)
    } else {
        return download_file_curl(url, output_path)
    }
}

when ODIN_OS == .Windows {
    foreign import urlmon "system:urlmon.lib"
    foreign import ole32 "system:ole32.lib"

    foreign urlmon {
        @(link_name = "URLDownloadToFileA")
        URLDownloadToFileA :: proc(pCaller: rawptr, szURL: cstring, szFileName: cstring, dwReserved: c.int, lpfnCB: rawptr) -> c.int ---
    }

    foreign ole32 {
        @(link_name = "CoInitializeEx")
        CoInitializeEx :: proc(pvReserved: rawptr, dwCoInit: c.int) -> c.int ---

        @(link_name = "CoUninitialize")
        CoUninitialize :: proc() ---
    }

    download_file_windows :: proc(url: string, output_path: string) -> bool {
        url_cstr := strings.clone_to_cstring(url)
        path_cstr := strings.clone_to_cstring(output_path)
        defer delete(url_cstr)
        defer delete(path_cstr)

        // Ensure the output directory exists.
        dir := filepath.dir(output_path)
        if dir != "" {
            os.make_directory_all(dir)
        }

        CoInitializeEx(nil, 0)
        result := URLDownloadToFileA(nil, url_cstr, path_cstr, 0, nil)
        CoUninitialize()
        log_download(fmt.tprintf("URLDownloadToFileA result: 0x%08X for %s", u32(result), url))
        return result == 0
    }
} else {
    download_file_curl :: proc(url: string, output_path: string) -> bool {
        return curl_download_file(url, output_path)
    }
}
