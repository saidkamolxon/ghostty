//! WGL OpenGL context management for Windows.
//!
//! Windows has no surfaceless EGL, so each renderer gets a WGL context
//! bound to its own hidden window. The renderer only ever draws into
//! framebuffer objects and reads the result back for the apprt to
//! present, so the window exists solely to provide a device context
//! with an OpenGL capable pixel format.
const std = @import("std");
const windows = @import("../../os/main.zig").windows;
const kernel32 = windows.exp.kernel32;
const user32 = windows.exp.user32;
const gdi32 = windows.exp.gdi32;
const opengl32 = windows.exp.opengl32;

const log = std.log.scoped(.opengl_wgl);

const class_name = std.unicode.utf8ToUtf16LeStringLiteral("GhosttyWGLContext");

/// ERROR_CLASS_ALREADY_EXISTS
const error_class_already_exists = 1410;

pub const Error = error{
    WglRegisterClassFailed,
    WglCreateWindowFailed,
    WglGetDCFailed,
    WglPixelFormatFailed,
    WglCreateContextFailed,
    WglMakeCurrentFailed,
    WglNoCreateContextAttribs,
};

pub const Context = struct {
    hwnd: windows.HWND,
    hdc: windows.HDC,
    hglrc: windows.HGLRC,

    /// Create a core profile context of at least the given version.
    /// This must be called on the thread that will destroy it, since
    /// the backing window is owned by the creating thread.
    pub fn create(major: c_int, minor: c_int) Error!Context {
        const instance: ?windows.HINSTANCE = @ptrCast(kernel32.GetModuleHandleW(null));
        try registerClass(instance);

        const hwnd = user32.CreateWindowExW(
            0,
            class_name,
            class_name,
            0,
            0,
            0,
            1,
            1,
            null,
            null,
            instance,
            null,
        ) orelse return error.WglCreateWindowFailed;
        errdefer _ = user32.DestroyWindow(hwnd);

        const hdc = user32.GetDC(hwnd) orelse return error.WglGetDCFailed;
        errdefer _ = user32.ReleaseDC(hwnd, hdc);

        const pfd: windows.PIXELFORMATDESCRIPTOR = .{
            .dwFlags = windows.PFD_DRAW_TO_WINDOW |
                windows.PFD_SUPPORT_OPENGL |
                windows.PFD_DOUBLEBUFFER,
            .iPixelType = windows.PFD_TYPE_RGBA,
            .cColorBits = 32,
            .cAlphaBits = 8,
            .iLayerType = windows.PFD_MAIN_PLANE,
        };
        const format = gdi32.ChoosePixelFormat(hdc, &pfd);
        if (format == 0) return error.WglPixelFormatFailed;
        if (!gdi32.SetPixelFormat(hdc, format, &pfd).toBool()) {
            return error.WglPixelFormatFailed;
        }

        // A core profile context can only be created with the
        // wglCreateContextAttribsARB extension, and extension functions
        // can only be loaded while a (legacy) context is current.
        const legacy = opengl32.wglCreateContext(hdc) orelse
            return error.WglCreateContextFailed;
        defer _ = opengl32.wglDeleteContext(legacy);
        if (!opengl32.wglMakeCurrent(hdc, legacy).toBool()) {
            return error.WglMakeCurrentFailed;
        }
        defer _ = opengl32.wglMakeCurrent(null, null);

        const create_attribs: windows.PFNWGLCREATECONTEXTATTRIBSARBPROC = @ptrCast(
            validProc(opengl32.wglGetProcAddress("wglCreateContextAttribsARB")) orelse
                return error.WglNoCreateContextAttribs,
        );

        const attribs = [_]c_int{
            windows.WGL_CONTEXT_MAJOR_VERSION_ARB, major,
            windows.WGL_CONTEXT_MINOR_VERSION_ARB, minor,
            windows.WGL_CONTEXT_PROFILE_MASK_ARB,  windows.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
            0,
        };
        const hglrc = create_attribs(hdc, null, &attribs) orelse {
            log.warn("wglCreateContextAttribsARB failed err={}", .{windows.GetLastError()});
            return error.WglCreateContextFailed;
        };

        return .{ .hwnd = hwnd, .hdc = hdc, .hglrc = hglrc };
    }

    /// Destroy the context. Must be called on the creating thread and
    /// the context must not be current on any other thread.
    pub fn destroy(self: *const Context) void {
        _ = opengl32.wglDeleteContext(self.hglrc);
        _ = user32.ReleaseDC(self.hwnd, self.hdc);
        _ = user32.DestroyWindow(self.hwnd);
    }

    pub fn makeCurrent(self: *const Context) Error!void {
        if (!opengl32.wglMakeCurrent(self.hdc, self.hglrc).toBool()) {
            log.warn("wglMakeCurrent failed err={}", .{windows.GetLastError()});
            return error.WglMakeCurrentFailed;
        }
    }
};

/// Release whatever context is current on the calling thread.
pub fn releaseCurrent() void {
    _ = opengl32.wglMakeCurrent(null, null);
}

/// Loader for GLAD. wglGetProcAddress only returns extension and
/// post-1.1 functions, so OpenGL 1.1 functions are loaded from
/// opengl32.dll directly.
pub fn getProcAddress(name: [*c]const u8) callconv(.c) ?*const fn () callconv(.c) void {
    const name_z: [*:0]const u8 = @ptrCast(name);
    if (validProc(opengl32.wglGetProcAddress(name_z))) |proc| return @ptrCast(proc);
    const module = kernel32.LoadLibraryA("opengl32.dll") orelse return null;
    return @ptrCast(kernel32.GetProcAddress(module, name_z));
}

/// wglGetProcAddress may return 1, 2, 3 or -1 instead of null on failure.
fn validProc(proc: ?windows.PROC) ?windows.PROC {
    const p = proc orelse return null;
    return switch (@intFromPtr(p)) {
        1, 2, 3, std.math.maxInt(usize) => null,
        else => p,
    };
}

fn registerClass(instance: ?windows.HINSTANCE) Error!void {
    const class: windows.WNDCLASSEXW = .{
        .style = windows.CS_OWNDC,
        .lpfnWndProc = user32.DefWindowProcW,
        .hInstance = instance,
        .lpszClassName = class_name,
    };
    if (user32.RegisterClassExW(&class) == 0 and
        @backingInt(windows.GetLastError()) != error_class_already_exists)
    {
        return error.WglRegisterClassFailed;
    }
}
