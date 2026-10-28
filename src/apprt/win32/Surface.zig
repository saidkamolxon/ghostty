/// A Win32 surface. Each surface is a top-level window that hosts exactly
/// one core terminal surface.
const Surface = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const apprt = @import("../../apprt.zig");
const CoreSurface = @import("../../Surface.zig");
const global = @import("../../global.zig");
const input = @import("../../input.zig");
const renderer = @import("../../renderer.zig");
const terminal = @import("../../terminal/main.zig");
const windows = @import("../../os/main.zig").windows;
const user32 = windows.exp.user32;
const gdi32 = windows.exp.gdi32;
const kernel32 = windows.exp.kernel32;
const App = @import("App.zig");
const key = @import("key.zig");

const log = std.log.scoped(.win32_surface);

const class_name = std.unicode.utf8ToUtf16LeStringLiteral("GhosttyWindow");
const default_title = std.unicode.utf8ToUtf16LeStringLiteral("Ghostty");

/// Posted to a surface window to close it. Closing is always deferred
/// to the message loop because the core may request it from inside one
/// of our own callbacks, where freeing the surface would be unsafe.
/// wparam is 1 if a process is still running and we should confirm.
const WM_GHOSTTY_CLOSE = windows.WM_USER + 2;

/// A frame exported by the renderer, already in GDI's BGRA order.
const Frame = @FieldType(renderer.Renderer.ExportedFrame, "memory");

app: *App,
hwnd: windows.HWND,

/// Window creation and destruction happen in phases; see `create`.
state: enum { creating, open } = .creating,

/// The core surface. Null until initialized and after destruction.
core_surface: ?*CoreSurface = null,

/// The client area size in device pixels.
size: apprt.SurfaceSize = .{ .width = 0, .height = 0 },

/// The last cursor position in device pixels.
cursor_pos: apprt.CursorPos = .{ .x = -1, .y = -1 },

/// The current title, if one was set by the terminal.
title: ?[:0]const u8 = null,

/// The cursor shown over the client area, and whether it is visible.
cursor: ?windows.HCURSOR = null,
cursor_visible: bool = true,

/// Whether we requested a WM_MOUSELEAVE notification.
tracking_mouse: bool = false,

/// Whether the last key produced dead key preedit text.
preedit_active: bool = false,

/// Buffers WM_CHAR messages that arrive outside of a key down, e.g.
/// IME commits, which may be split across UTF-16 surrogate pairs.
char_text: key.TextBuffer = .{},

/// The most recently presented frame. We keep it so we can repaint
/// (e.g. after being uncovered) without waiting for the renderer.
frame: ?Frame = null,

/// Register the window class for surfaces. Called once by the app.
pub fn registerClass(instance: windows.HINSTANCE) !void {
    const class: windows.WNDCLASSEXW = .{
        .style = windows.CS_HREDRAW | windows.CS_VREDRAW,
        .lpfnWndProc = wndProc,
        .hInstance = instance,
        .hIcon = user32.LoadIconW(null, windows.IDI_APPLICATION),
        .hCursor = user32.LoadCursorW(null, windows.IDC_ARROW),
        .lpszClassName = class_name,
    };
    if (user32.RegisterClassExW(&class) == 0) return error.Win32RegisterClassFailed;
}

/// Create a new window with a new terminal surface and show it.
pub fn create(app: *App) !*Surface {
    const alloc = app.core_app.alloc;
    const self = try alloc.create(Surface);
    errdefer alloc.destroy(self);
    self.* = .{
        .app = app,
        .hwnd = undefined,
        .cursor = user32.LoadCursorW(null, windows.IDC_IBEAM),
    };

    // WM_NCCREATE stores our pointer and window handle on the window.
    _ = user32.CreateWindowExW(
        windows.WS_EX_APPWINDOW,
        class_name,
        default_title,
        windows.WS_OVERLAPPEDWINDOW,
        windows.CW_USEDEFAULT,
        windows.CW_USEDEFAULT,
        windows.CW_USEDEFAULT,
        windows.CW_USEDEFAULT,
        null,
        null,
        app.instance,
        self,
    ) orelse return error.Win32CreateWindowFailed;

    // While we're still `creating`, WM_DESTROY won't free us so the
    // errdefer above remains responsible for our memory.
    errdefer _ = user32.DestroyWindow(self.hwnd);

    try self.initCoreSurface();
    self.state = .open;
    app.windows_open += 1;

    _ = user32.ShowWindow(self.hwnd, windows.SW_SHOWDEFAULT);
    return self;
}

fn initCoreSurface(self: *Surface) !void {
    const app = self.app;
    const alloc = app.core_app.alloc;

    self.updateSize();

    const surface = try alloc.create(CoreSurface);
    errdefer alloc.destroy(surface);

    try app.core_app.addSurface(self);
    errdefer app.core_app.deleteSurface(self);

    var config = try apprt.surface.newConfig(app.core_app, &app.config, .window);
    defer config.deinit();

    try surface.init(alloc, &config, app.core_app, app, self);
    self.core_surface = surface;
}

/// Called from WM_DESTROY. Tears down the core surface and frees us.
fn destroy(self: *Surface) void {
    _ = user32.SetWindowLongPtrW(self.hwnd, windows.GWLP_USERDATA, 0);

    // If we failed during creation then `create` cleans up.
    if (self.state == .creating) return;

    const alloc = self.app.core_app.alloc;
    if (self.core_surface) |surface| {
        self.app.core_app.deleteSurface(self);
        surface.deinit();
        alloc.destroy(surface);
        self.core_surface = null;
    }

    if (self.frame) |frame| frame.deinit();
    if (self.title) |v| alloc.free(v);

    const app = self.app;
    alloc.destroy(self);
    app.windowClosed();
}

//---------------------------------------------------------------
// apprt.Surface interface

pub fn core(self: *Surface) *CoreSurface {
    return self.core_surface.?;
}

/// Required by the core, which calls this when the app is destroyed.
/// Our windows are destroyed earlier, in `App.terminate`.
pub fn deinit(_: *Surface) void {}

pub fn rtApp(self: *const Surface) *App {
    return self.app;
}

pub fn close(self: *Surface, process_active: bool) void {
    _ = user32.PostMessageW(
        self.hwnd,
        WM_GHOSTTY_CLOSE,
        @intFromBool(process_active),
        0,
    );
}

pub fn cgroup(_: *const Surface) ?[]const u8 {
    return null;
}

pub fn getTitle(self: *const Surface) ?[:0]const u8 {
    return self.title;
}

pub fn getContentScale(self: *const Surface) !apprt.ContentScale {
    const dpi = user32.GetDpiForWindow(self.hwnd);
    const scale: f32 = if (dpi == 0)
        1
    else
        @as(f32, @floatFromInt(dpi)) / windows.USER_DEFAULT_SCREEN_DPI;
    return .{ .x = scale, .y = scale };
}

pub fn getSize(self: *const Surface) !apprt.SurfaceSize {
    return self.size;
}

pub fn getCursorPos(self: *const Surface) !apprt.CursorPos {
    return self.cursor_pos;
}

pub fn supportsClipboard(
    _: *const Surface,
    clipboard_type: apprt.Clipboard,
) bool {
    // Windows only has the standard clipboard.
    return clipboard_type == .standard;
}

pub fn clipboardRequest(
    self: *Surface,
    clipboard_type: apprt.Clipboard,
    state: apprt.ClipboardRequest,
) !apprt.ClipboardReadResult {
    if (clipboard_type != .standard) return .unsupported;

    const alloc = self.app.core_app.alloc;
    const text = try readClipboardText(alloc, self.hwnd) orelse return .unavailable;
    defer alloc.free(text);

    const contents: []const terminal.clipboard.Content = &.{
        .{ .mime = "text/plain", .data = text },
    };

    const complete: CoreSurface.CompleteClipboard = switch (state) {
        .paste, .osc_52_read => .{ .contents = contents },
        .list => .{ .available = &.{"text/plain"} },

        // Kitty clipboard protocol reads and writes of other MIME types
        // are not supported yet.
        .kitty_read, .kitty_write => return .unavailable,

        // Writes never go through this path.
        .osc_52_write => unreachable,
    };

    self.completeClipboard(state, complete);
    return .started;
}

pub fn setClipboard(
    self: *Surface,
    clipboard_type: apprt.Clipboard,
    contents: []const apprt.ClipboardContent,
    confirm: bool,
) !void {
    if (clipboard_type != .standard) return;

    const text = for (contents) |content| {
        if (terminal.clipboard.isTextMime(content.mime)) break content.data;
    } else return;

    if (confirm and !self.askYesNo(
        "An application is attempting to write to the clipboard. Allow it?",
        "Allow Clipboard Access?",
    )) return;

    try writeClipboardText(self.app.core_app.alloc, self.hwnd, text);
}

pub fn defaultTermioEnv(_: *Surface) !std.process.Environ.Map {
    return try global.environMap();
}

pub fn redrawInspector(_: *Surface) void {}

pub fn renderDeviceOptions(_: *Surface) !renderer.Device.Options {
    return .{};
}

//---------------------------------------------------------------
// Actions, called by the App

/// Schedule a repaint with the latest frame from the renderer.
pub fn redraw(self: *Surface) void {
    _ = user32.InvalidateRect(self.hwnd, null, .FALSE);
}

pub fn setTitle(self: *Surface, title: [:0]const u8) !void {
    const alloc = self.app.core_app.alloc;
    const copy = try alloc.dupeSentinel(u8, title, 0);
    if (self.title) |v| alloc.free(v);
    self.title = copy;

    const wide = try std.unicode.utf8ToUtf16LeAllocZ(alloc, title);
    defer alloc.free(wide);
    _ = user32.SetWindowTextW(self.hwnd, wide);
}

pub fn setMouseShape(self: *Surface, shape: terminal.MouseShape) void {
    const id: windows.LPCWSTR_RESOURCE = switch (shape) {
        .text, .vertical_text => windows.IDC_IBEAM,
        .pointer, .grab, .grabbing, .alias, .copy => windows.IDC_HAND,
        .progress => windows.IDC_APPSTARTING,
        .wait => windows.IDC_WAIT,
        .help, .context_menu => windows.IDC_HELP,
        .cell, .crosshair => windows.IDC_CROSS,
        .move, .all_scroll => windows.IDC_SIZEALL,
        .no_drop, .not_allowed => windows.IDC_NO,
        .col_resize, .ew_resize, .e_resize, .w_resize => windows.IDC_SIZEWE,
        .row_resize, .ns_resize, .n_resize, .s_resize => windows.IDC_SIZENS,
        .nesw_resize, .ne_resize, .sw_resize => windows.IDC_SIZENESW,
        .nwse_resize, .nw_resize, .se_resize => windows.IDC_SIZENWSE,
        else => windows.IDC_ARROW,
    };
    self.cursor = user32.LoadCursorW(null, id);
    self.applyCursor();
}

pub fn setMouseVisibility(self: *Surface, visible: bool) void {
    self.cursor_visible = visible;
    self.applyCursor();
}

/// Resize the window so that its client area has the given size in
/// device pixels.
pub fn setInitialSize(self: *Surface, width: u32, height: u32) void {
    const dpi = user32.GetDpiForWindow(self.hwnd);
    var rect: windows.RECT = .{
        .left = 0,
        .top = 0,
        .right = @intCast(width),
        .bottom = @intCast(height),
    };
    _ = user32.AdjustWindowRectExForDpi(
        &rect,
        windows.WS_OVERLAPPEDWINDOW,
        .FALSE,
        windows.WS_EX_APPWINDOW,
        dpi,
    );
    _ = user32.SetWindowPos(
        self.hwnd,
        null,
        0,
        0,
        rect.right - rect.left,
        rect.bottom - rect.top,
        windows.SWP_NOMOVE | windows.SWP_NOZORDER | windows.SWP_NOACTIVATE,
    );
}

//---------------------------------------------------------------
// Window procedure

fn wndProc(
    hwnd: windows.HWND,
    msg: windows.UINT,
    wparam: windows.WPARAM,
    lparam: windows.LPARAM,
) callconv(.winapi) windows.LRESULT {
    if (msg == windows.WM_NCCREATE) {
        // lparam is a CREATESTRUCTW whose first field is lpCreateParams.
        const create_params: *const ?*Surface = @ptrFromInt(@as(usize, @bitCast(lparam)));
        const self = create_params.*.?;
        self.hwnd = hwnd;
        _ = user32.SetWindowLongPtrW(hwnd, windows.GWLP_USERDATA, @bitCast(@intFromPtr(self)));
        return user32.DefWindowProcW(hwnd, msg, wparam, lparam);
    }

    const ptr: usize = @bitCast(user32.GetWindowLongPtrW(hwnd, windows.GWLP_USERDATA));
    if (ptr == 0) return user32.DefWindowProcW(hwnd, msg, wparam, lparam);
    const self: *Surface = @ptrFromInt(ptr);

    switch (msg) {
        windows.WM_PAINT => {
            self.paint();
            return 0;
        },

        // We always paint the full client area, so erasing it first
        // would only cause flicker.
        windows.WM_ERASEBKGND => return 1,

        windows.WM_SIZE => {
            self.onSize(wparam);
            return 0;
        },

        windows.WM_DPICHANGED => {
            self.onDpiChanged(lparam);
            return 0;
        },

        windows.WM_SETFOCUS, windows.WM_KILLFOCUS => {
            if (self.core_surface) |surface| {
                surface.focusCallback(msg == windows.WM_SETFOCUS) catch |err| {
                    log.warn("error in focus callback err={}", .{err});
                };
            }
            return 0;
        },

        windows.WM_KEYDOWN,
        windows.WM_SYSKEYDOWN,
        windows.WM_KEYUP,
        windows.WM_SYSKEYUP,
        => if (self.onKey(msg, wparam, lparam)) return 0,

        windows.WM_CHAR, windows.WM_SYSCHAR => {
            self.onChar(wparam);
            return 0;
        },

        windows.WM_MOUSEMOVE => {
            self.onMouseMove(lparam);
            return 0;
        },

        windows.WM_MOUSELEAVE => {
            self.tracking_mouse = false;
            self.cursor_pos = .{ .x = -1, .y = -1 };
            if (self.core_surface) |surface| {
                surface.cursorPosCallback(self.cursor_pos, null) catch |err| {
                    log.warn("error in cursor pos callback err={}", .{err});
                };
            }
            return 0;
        },

        windows.WM_LBUTTONDOWN => return self.onMouseButton(.press, .left),
        windows.WM_LBUTTONUP => return self.onMouseButton(.release, .left),
        windows.WM_RBUTTONDOWN => return self.onMouseButton(.press, .right),
        windows.WM_RBUTTONUP => return self.onMouseButton(.release, .right),
        windows.WM_MBUTTONDOWN => return self.onMouseButton(.press, .middle),
        windows.WM_MBUTTONUP => return self.onMouseButton(.release, .middle),
        windows.WM_XBUTTONDOWN, windows.WM_XBUTTONUP => {
            const action: input.MouseButtonState =
                if (msg == windows.WM_XBUTTONDOWN) .press else .release;
            // X1 is "back" and X2 is "forward", which are buttons 8 and
            // 9 by X11 convention.
            const button: input.MouseButton = switch (windows.HIWORD(wparam)) {
                windows.XBUTTON1 => .eight,
                windows.XBUTTON2 => .nine,
                else => .unknown,
            };
            _ = self.onMouseButton(action, button);
            // XBUTTON messages must return TRUE.
            return 1;
        },

        windows.WM_MOUSEWHEEL, windows.WM_MOUSEHWHEEL => {
            const delta: f64 = @floatFromInt(@as(i16, @bitCast(windows.HIWORD(wparam))));
            const lines = delta / windows.WHEEL_DELTA;
            if (self.core_surface) |surface| {
                const xoff: f64, const yoff: f64 = if (msg == windows.WM_MOUSEWHEEL)
                    .{ 0, lines }
                else
                    .{ lines, 0 };
                surface.scrollCallback(xoff, yoff, .{}) catch |err| {
                    log.warn("error in scroll callback err={}", .{err});
                };
            }
            return 0;
        },

        windows.WM_SETCURSOR => if (windows.LOWORD(lparam) == windows.HTCLIENT) {
            self.applyCursor();
            return 1;
        },

        windows.WM_CLOSE => {
            // Let the core decide whether this needs confirmation. It
            // calls back into `close`.
            if (self.core_surface) |surface| {
                surface.close();
                return 0;
            }
        },

        WM_GHOSTTY_CLOSE => {
            if (wparam == 0 or self.askYesNo(
                "A process is still running in this terminal. Close it anyway?",
                "Close Terminal?",
            )) _ = user32.DestroyWindow(hwnd);
            return 0;
        },

        windows.WM_DESTROY => {
            self.destroy();
            return 0;
        },

        else => {},
    }

    return user32.DefWindowProcW(hwnd, msg, wparam, lparam);
}

fn paint(self: *Surface) void {
    var ps: windows.PAINTSTRUCT = undefined;
    const hdc = user32.BeginPaint(self.hwnd, &ps) orelse return;
    defer _ = user32.EndPaint(self.hwnd, &ps);

    // Grab the latest frame from the renderer, if there is a new one.
    if (self.core_surface) |surface| {
        if (surface.renderer.takeFrame()) |exported| switch (exported) {
            .memory => |frame| {
                if (self.frame) |old| old.deinit();
                self.frame = frame;
            },

            // DMABUFs are never exported on Windows.
            else => exported.deinit(),
        };
    }

    const frame = self.frame orelse return;
    const width: c_int = @intCast(frame.width);
    const height: c_int = @intCast(frame.height);

    // A positive height makes this a bottom-up DIB, which matches the
    // row order of the OpenGL readback.
    const bmi: windows.BITMAPINFO = .{ .bmiHeader = .{
        .biWidth = width,
        .biHeight = height,
        .biBitCount = 32,
    } };
    _ = gdi32.StretchDIBits(
        hdc,
        0,
        0,
        width,
        height,
        0,
        0,
        width,
        height,
        frame.pixels.ptr,
        &bmi,
        windows.DIB_RGB_COLORS,
        windows.SRCCOPY,
    );
}

fn updateSize(self: *Surface) void {
    var rect: windows.RECT = undefined;
    if (!user32.GetClientRect(self.hwnd, &rect).toBool()) return;
    self.size = .{
        .width = @intCast(@max(0, rect.right - rect.left)),
        .height = @intCast(@max(0, rect.bottom - rect.top)),
    };
}

fn onSize(self: *Surface, wparam: windows.WPARAM) void {
    const surface = self.core_surface orelse {
        self.updateSize();
        return;
    };

    const minimized = wparam == windows.SIZE_MINIMIZED;
    surface.occlusionCallback(!minimized) catch |err| {
        log.warn("error in occlusion callback err={}", .{err});
    };
    if (minimized) return;

    const old = self.size;
    self.updateSize();
    if (old.eql(&self.size) or self.size.width == 0 or self.size.height == 0) return;
    surface.sizeCallback(self.size) catch |err| {
        log.warn("error in size callback err={}", .{err});
    };
}

fn onDpiChanged(self: *Surface, lparam: windows.LPARAM) void {
    if (self.core_surface) |surface| {
        const scale = self.getContentScale() catch unreachable;
        surface.contentScaleCallback(scale) catch |err| {
            log.warn("error in content scale callback err={}", .{err});
        };
    }

    // Windows suggests a new window rect for the new DPI. Using it
    // results in WM_SIZE which updates our size.
    const rect: *const windows.RECT = @ptrFromInt(@as(usize, @bitCast(lparam)));
    _ = user32.SetWindowPos(
        self.hwnd,
        null,
        rect.left,
        rect.top,
        rect.right - rect.left,
        rect.bottom - rect.top,
        windows.SWP_NOZORDER | windows.SWP_NOACTIVATE,
    );
}

/// Handle a key message. Returns true if Ghostty consumed the key and
/// the default window procedure should not see it.
fn onKey(
    self: *Surface,
    msg: windows.UINT,
    wparam: windows.WPARAM,
    lparam: windows.LPARAM,
) bool {
    const surface = self.core_surface orelse return false;

    // The IME is processing this key; its result arrives as WM_CHAR.
    if (wparam == windows.VK_PROCESSKEY) return false;

    const action = key.action(msg, lparam);

    // TranslateMessage already posted any characters this key produced,
    // so they are next in our queue. Take them so that the text is
    // associated with this key event.
    var text: key.TextBuffer = .{};
    var dead = false;
    if (action != .release) self.takeChars(&text, &dead);

    const mods = key.currentMods();
    var consumed_mods: input.Mods = .{};
    if (text.len > 0) {
        consumed_mods.shift = mods.shift;

        // AltGr is reported as Ctrl+Alt. If those produced text then
        // they were consumed by the keyboard layout.
        if (mods.ctrl and mods.alt) {
            consumed_mods.ctrl = true;
            consumed_mods.alt = true;
        }
    }

    // A dead key starts a composition: show it as preedit until the
    // next key completes it.
    if (dead) {
        surface.preeditCallback(text.slice()) catch |err| {
            log.warn("error in preedit callback err={}", .{err});
        };
        self.preedit_active = true;
    } else if (self.preedit_active and action != .release) {
        surface.preeditCallback(null) catch |err| {
            log.warn("error in preedit callback err={}", .{err});
        };
        self.preedit_active = false;
    }

    const effect = surface.keyCallback(.{
        .action = action,
        .key = key.physicalKey(lparam),
        .mods = mods,
        .consumed_mods = consumed_mods,
        .composing = dead,
        .utf8 = text.slice(),
        .unshifted_codepoint = key.unshiftedCodepoint(wparam),
    }) catch |err| {
        log.warn("error in key callback err={}", .{err});
        return false;
    };

    return effect != .ignored;
}

/// Remove the character messages for the key being processed from the
/// queue. Stops at the first message that isn't a character so that we
/// never take characters belonging to a later key.
fn takeChars(self: *Surface, text: *key.TextBuffer, dead: *bool) void {
    var next: windows.MSG = undefined;
    while (user32.PeekMessageW(&next, self.hwnd, 0, 0, windows.PM_NOREMOVE).toBool()) {
        switch (next.message) {
            windows.WM_CHAR,
            windows.WM_SYSCHAR,
            windows.WM_DEADCHAR,
            windows.WM_SYSDEADCHAR,
            => {},
            else => return,
        }

        _ = user32.PeekMessageW(
            &next,
            self.hwnd,
            next.message,
            next.message,
            windows.PM_REMOVE,
        );

        if (next.message == windows.WM_DEADCHAR or
            next.message == windows.WM_SYSDEADCHAR) dead.* = true;
        text.appendUtf16(@truncate(next.wParam));
    }
}

/// A character that didn't come with a key down we processed, e.g.
/// text committed by an IME.
fn onChar(self: *Surface, wparam: windows.WPARAM) void {
    const surface = self.core_surface orelse return;

    self.char_text.appendUtf16(@truncate(wparam));
    if (self.char_text.len == 0) return;
    defer self.char_text.len = 0;

    _ = surface.keyCallback(.{
        .action = .press,
        .utf8 = self.char_text.slice(),
    }) catch |err| {
        log.warn("error in key callback err={}", .{err});
    };
}

fn onMouseMove(self: *Surface, lparam: windows.LPARAM) void {
    if (!self.tracking_mouse) {
        var tme: windows.TRACKMOUSEEVENT = .{
            .dwFlags = windows.TME_LEAVE,
            .hwndTrack = self.hwnd,
        };
        self.tracking_mouse = user32.TrackMouseEvent(&tme).toBool();
    }

    self.cursor_pos = .{
        .x = @floatFromInt(windows.GET_X_LPARAM(lparam)),
        .y = @floatFromInt(windows.GET_Y_LPARAM(lparam)),
    };

    const surface = self.core_surface orelse return;
    surface.cursorPosCallback(self.cursor_pos, key.currentMods()) catch |err| {
        log.warn("error in cursor pos callback err={}", .{err});
    };
}

fn onMouseButton(
    self: *Surface,
    action: input.MouseButtonState,
    button: input.MouseButton,
) windows.LRESULT {
    // Capture the mouse while a button is held so that drags (e.g.
    // selections) keep working outside of the window.
    switch (action) {
        .press => _ = user32.SetCapture(self.hwnd),
        .release => _ = user32.ReleaseCapture(),
    }

    const surface = self.core_surface orelse return 0;
    _ = surface.mouseButtonCallback(action, button, key.currentMods()) catch |err| {
        log.warn("error in mouse button callback err={}", .{err});
    };
    return 0;
}

fn applyCursor(self: *const Surface) void {
    _ = user32.SetCursor(if (self.cursor_visible) self.cursor else null);
}

/// Show a modal yes/no question. Returns true if the user said yes.
fn askYesNo(self: *const Surface, comptime text: []const u8, comptime caption: []const u8) bool {
    return user32.MessageBoxW(
        self.hwnd,
        std.unicode.utf8ToUtf16LeStringLiteral(text),
        std.unicode.utf8ToUtf16LeStringLiteral(caption),
        windows.MB_YESNO | windows.MB_ICONWARNING,
    ) == windows.IDYES;
}

/// Complete a clipboard request, asking for confirmation if the core
/// considers it unsafe.
fn completeClipboard(
    self: *Surface,
    req: apprt.ClipboardRequest,
    complete: CoreSurface.CompleteClipboard,
) void {
    const surface = self.core_surface orelse return;
    surface.completeClipboardRequest(req, complete) catch |err| switch (err) {
        error.UnsafePaste, error.UnauthorizedPaste => {
            if (!self.askYesNo(
                "The pasted text may be unsafe (for example, it contains " ++
                    "newlines that would run commands). Paste it anyway?",
                "Confirm Paste",
            )) {
                surface.denyClipboardRequest(req);
                return;
            }

            var confirmed = complete;
            confirmed.confirmed = true;
            surface.completeClipboardRequest(req, confirmed) catch |err2| {
                log.warn("failed to complete clipboard request err={}", .{err2});
            };
        },

        else => log.warn("failed to complete clipboard request err={}", .{err}),
    };
}

//---------------------------------------------------------------
// Clipboard

/// Read the clipboard as UTF-8 text. Returns null if there is no text.
fn readClipboardText(alloc: Allocator, hwnd: windows.HWND) !?[]u8 {
    if (!user32.OpenClipboard(hwnd).toBool()) return error.Win32OpenClipboardFailed;
    defer _ = user32.CloseClipboard();

    const handle = user32.GetClipboardData(windows.CF_UNICODETEXT) orelse return null;
    const data: [*:0]const u16 = @ptrCast(@alignCast(
        kernel32.GlobalLock(handle) orelse return null,
    ));
    defer _ = kernel32.GlobalUnlock(handle);

    return try std.unicode.utf16LeToUtf8Alloc(alloc, std.mem.span(data));
}

fn writeClipboardText(alloc: Allocator, hwnd: windows.HWND, text: []const u8) !void {
    const wide = try std.unicode.utf8ToUtf16LeAllocZ(alloc, text);
    defer alloc.free(wide);

    // The clipboard takes ownership of a movable global allocation.
    const size = (wide.len + 1) * @sizeOf(u16);
    const handle = kernel32.GlobalAlloc(windows.GMEM_MOVEABLE, size) orelse
        return error.OutOfMemory;
    var owned = true;
    defer if (owned) {
        _ = kernel32.GlobalFree(handle);
    };

    {
        const dst: [*]u16 = @ptrCast(@alignCast(
            kernel32.GlobalLock(handle) orelse return error.OutOfMemory,
        ));
        defer _ = kernel32.GlobalUnlock(handle);
        @memcpy(dst[0 .. wide.len + 1], wide[0 .. wide.len + 1]);
    }

    if (!user32.OpenClipboard(hwnd).toBool()) return error.Win32OpenClipboardFailed;
    defer _ = user32.CloseClipboard();
    _ = user32.EmptyClipboard();
    if (user32.SetClipboardData(windows.CF_UNICODETEXT, handle) == null) {
        return error.Win32SetClipboardFailed;
    }
    owned = false;
}
