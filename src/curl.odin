package main

import "base:runtime"
import c "core:c/libc"
import "core:os"
import "core:strings"

when ODIN_OS != .Windows {
    foreign import curl_lib "system:curl"

    foreign curl_lib {
        @(link_name = "curl_global_init")
        curl_global_init :: proc(flags: c.long) -> c.int ---

        @(link_name = "curl_global_cleanup")
        curl_global_cleanup :: proc() ---

        @(link_name = "curl_easy_init")
        curl_easy_init :: proc() -> rawptr ---

        @(link_name = "curl_easy_setopt")
        curl_easy_setopt :: proc(curl: rawptr, option: c.int, #c_vararg args: ..any) -> c.int ---

        @(link_name = "curl_easy_perform")
        curl_easy_perform :: proc(curl: rawptr) -> c.int ---

        @(link_name = "curl_easy_cleanup")
        curl_easy_cleanup :: proc(curl: rawptr) ---
    }

    CURLOPT_URL :: c.int(10002)
    CURLOPT_FOLLOWLOCATION :: c.int(52)
    CURLOPT_TIMEOUT :: c.int(13)
    CURLOPT_WRITEFUNCTION :: c.int(20011)
    CURLOPT_WRITEDATA :: c.int(10001)

    curl_download_file :: proc(url: string, output_path: string) -> bool {
        curl_global_init(3)
        defer curl_global_cleanup()

        handle := curl_easy_init()
        if handle == nil {
            return false
        }
        defer curl_easy_cleanup(handle)

        data := make([dynamic]u8)
        defer delete(data)

        url_cstr := strings.clone_to_cstring(url)
        defer delete(url_cstr)

        curl_easy_setopt(handle, CURLOPT_URL, url_cstr)
        curl_easy_setopt(handle, CURLOPT_FOLLOWLOCATION, 1)
        curl_easy_setopt(handle, CURLOPT_TIMEOUT, 30)
        curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, curl_write_callback)
        curl_easy_setopt(handle, CURLOPT_WRITEDATA, &data)

        result := curl_easy_perform(handle)
        if result != 0 {
            return false
        }
        if len(data) == 0 {
            return false
        }

        return os.write_entire_file(output_path, data[:]) == os.ERROR_NONE
    }

    curl_write_callback :: proc "c" (
        buffer: [^]u8,
        size: c.size_t,
        nitems: c.size_t,
        outstream: rawptr,
    ) -> c.size_t {
        context = runtime.default_context()
        data := cast(^[dynamic]u8)outstream
        total := size * nitems
        for i := c.size_t(0); i < total; i += 1 {
            append(data, buffer[i])
        }
        return total
    }
}
