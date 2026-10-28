/// The Win32 application. Owns the message loop and the configuration
/// that new windows are created from.
const App = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const apprt = @import("../../apprt.zig");
const configpkg = @import("../../config.zig");
const Config = configpkg.Config;
const CoreApp = @import("../../App.zig");
const CoreSurface = @import("../../Surface.zig");
const windows = @import("../../os/main.zig").windows;
const kernel32 = windows.exp.kernel32;
const user32 = windows.exp.user32;
const Surface = @import("Surface.zig");

const log = std.log.scoped(.win32);

const msg_class_name = std.unicode.utf8ToUtf16LeStringLiteral("GhosttyMessageWindow");

/// Posted to the message window to wake the event loop so that the core
/// app mailbox is drained. The message itself carries no data.
const WM_GHOSTTY_WAKEUP = windows.WM_USER + 1;

core_app: *CoreApp,

/// The loaded configuration, used to create new windows.
config: Config,

instance: windows.HINSTANCE,

/// A hidden message-only window. It exists only so that `wakeup`
/// (which may be called from any thread) can post a message that
/// unblocks GetMessage on the main thread.
msg_hwnd: windows.HWND,

/// The number of open windows. Each window has exactly one surface.
windows_open: usize = 0,

/// Set to false to exit the message loop.
running: bool = true,

pub fn init(
    self: *App,
    core_app: *CoreApp,

    // Required by the apprt interface but we don't use it.
    opts: struct {},
) !void {
    _ = opts;

    // Opt in to per-monitor DPI awareness so that we render at the
    // native resolution of each monitor instead of being bitmap-scaled
    // by the system. This can fail if the manifest already set it,
    // which is fine.
    _ = user32.SetProcessDpiAwarenessContext(
        windows.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
    );

    var config = Config.load(core_app.alloc) catch |err| err: {
        log.err("error loading config, using defaults err={}", .{err});
        break :err try Config.default(core_app.alloc);
    };
    errdefer config.deinit();

    // Log any configuration diagnostics. There is no UI for these yet.
    for (config._diagnostics.items()) |diag| {
        var buf: [1024]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buf);
        diag.format(&writer) catch {};
        log.warn("config diagnostic: {s}", .{writer.buffered()});
    }

    const instance: windows.HINSTANCE = @ptrCast(kernel32.GetModuleHandleW(null) orelse
        return error.Win32GetModuleHandleFailed);

    try Surface.registerClass(instance);

    const msg_class: windows.WNDCLASSEXW = .{
        .lpfnWndProc = msgWndProc,
        .hInstance = instance,
        .lpszClassName = msg_class_name,
    };
    if (user32.RegisterClassExW(&msg_class) == 0) return error.Win32RegisterClassFailed;

    const msg_hwnd = user32.CreateWindowExW(
        0,
        msg_class_name,
        null,
        0,
        0,
        0,
        0,
        0,
        windows.HWND_MESSAGE,
        null,
        instance,
        null,
    ) orelse return error.Win32CreateWindowFailed;

    self.* = .{
        .core_app = core_app,
        .config = config,
        .instance = instance,
        .msg_hwnd = msg_hwnd,
    };
}

pub fn run(self: *App) !void {
    if (self.config.@"initial-window") try self.newWindow(null);

    var msg: windows.MSG = undefined;
    while (self.running) {
        // GetMessage returns 0 on WM_QUIT and -1 on error.
        const result = @backingInt(user32.GetMessageW(&msg, null, 0, 0));
        if (result == 0) break;
        if (result == -1) {
            log.err("GetMessage failed err={}", .{windows.GetLastError()});
            break;
        }

        _ = user32.TranslateMessage(&msg);
        _ = user32.DispatchMessageW(&msg);

        // Drain the core app mailbox after every message. This is cheap
        // when the mailbox is empty.
        try self.core_app.tick(self);

        // There is no way to reach a windowless Ghostty on Windows yet
        // (no tray icon or similar), so we always quit once the last
        // window is closed.
        if (self.windows_open == 0) self.running = false;
    }
}

pub fn terminate(self: *App) void {
    // Destroy any windows that are still open (e.g. after `quit`). Each
    // destroyed window removes its surface from the core app, which
    // must have no surfaces left when it is destroyed.
    while (self.core_app.surfaces.items.len > 0) {
        const surfaces = self.core_app.surfaces.items;
        const surface = surfaces[surfaces.len - 1];
        if (!user32.DestroyWindow(surface.hwnd).toBool()) {
            log.err("failed to destroy window err={}", .{windows.GetLastError()});
            break;
        }
    }

    _ = user32.DestroyWindow(self.msg_hwnd);
    self.config.deinit();
}

/// Called by CoreApp to wake up the event loop. This is thread-safe.
pub fn wakeup(self: *App) void {
    _ = user32.PostMessageW(self.msg_hwnd, WM_GHOSTTY_WAKEUP, 0, 0);
}

pub fn performAction(
    self: *App,
    target: apprt.Target,
    comptime action: apprt.Action.Key,
    value: apprt.Action.Value(action),
) !bool {
    switch (action) {
        .quit => self.running = false,

        .new_window => try self.newWindow(switch (target) {
            .app => null,
            .surface => |v| v,
        }),

        .close_window => switch (target) {
            .app => return false,
            .surface => |v| v.rt_surface.close(v.needsConfirmQuit()),
        },

        .render => switch (target) {
            .app => {},
            .surface => |v| v.rt_surface.redraw(),
        },

        .set_title => switch (target) {
            .app => return false,
            .surface => |v| try v.rt_surface.setTitle(value.title),
        },

        .mouse_shape => switch (target) {
            .app => return false,
            .surface => |v| v.rt_surface.setMouseShape(value),
        },

        .mouse_visibility => switch (target) {
            .app => return false,
            .surface => |v| v.rt_surface.setMouseVisibility(value == .visible),
        },

        .initial_size => switch (target) {
            .app => return false,
            .surface => |v| v.rt_surface.setInitialSize(value.width, value.height),
        },

        .ring_bell => _ = user32.MessageBeep(windows.MB_OK),

        .reload_config => try self.reloadConfig(target, value),

        .config_change => switch (target) {
            .app => {
                const config = try value.config.clone(self.core_app.alloc);
                self.config.deinit();
                self.config = config;
            },

            // Surfaces read their configuration from the core surface,
            // there is nothing for us to store.
            .surface => {},
        },

        // Everything else is unimplemented. Returning false lets the
        // core fall back to its default behavior where there is one.
        else => return false,
    }

    return true;
}

/// Send the given IPC to a running Ghostty. Not supported on Win32 yet.
pub fn performIpc(
    _: Allocator,
    _: apprt.ipc.Target,
    comptime _: apprt.ipc.Action.Key,
    _: anytype,
) !bool {
    return false;
}

/// The inspector is not supported yet.
pub fn redrawInspector(_: *App, _: *Surface) void {}

/// Open a new window. If a parent surface is given then the new surface
/// inherits from it (working directory, font size, etc.).
fn newWindow(self: *App, parent: ?*CoreSurface) !void {
    // TODO: inherit from the parent surface.
    _ = parent;
    _ = try Surface.create(self);
}

/// Called by surfaces once their window has been destroyed.
pub fn windowClosed(self: *App) void {
    self.windows_open -|= 1;
}

fn reloadConfig(
    self: *App,
    target: apprt.Target,
    opts: apprt.action.ReloadConfig,
) !void {
    // A soft reload re-applies our existing config, a hard reload reads
    // it from disk again.
    var loaded: ?Config = if (opts.soft) null else try Config.load(self.core_app.alloc);
    defer if (loaded) |*c| c.deinit();
    const config: *const Config = if (loaded) |*c| c else &self.config;

    switch (target) {
        .app => try self.core_app.updateConfig(self, config),
        .surface => |core| try core.updateConfig(config),
    }
}

fn msgWndProc(
    hwnd: windows.HWND,
    msg: windows.UINT,
    wparam: windows.WPARAM,
    lparam: windows.LPARAM,
) callconv(.winapi) windows.LRESULT {
    return switch (msg) {
        // The wakeup message only needs to unblock GetMessage; the run
        // loop ticks the core app after dispatching it.
        WM_GHOSTTY_WAKEUP => 0,
        else => user32.DefWindowProcW(hwnd, msg, wparam, lparam),
    };
}
