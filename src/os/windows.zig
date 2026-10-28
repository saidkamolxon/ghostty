const std = @import("std");
const windows = std.os.windows;

// NOTE: The Windows part of the Zig stdlib is currently in the process of
// having most of its features removed, with the ultimate goal of switching to
// serve as a support for higher-level functionality offered in places like
// `std.Io` only. As such this file serves as a "bridge" between type
// information (mostly coming from stdlib) and manually-defined constants and
// external functions.

// Utility functions
pub const GetCurrentProcessId = windows.GetCurrentProcessId;
pub const GetLastError = windows.GetLastError;
pub const unexpectedError = windows.unexpectedError;
pub const unexpectedStatus = windows.unexpectedStatus;

// Primitive types
pub const BOOL = windows.BOOL;
pub const COORD = windows.COORD;
pub const DWORD = windows.DWORD;
pub const DWORD_PTR = windows.DWORD_PTR;
pub const HANDLE = windows.HANDLE;
pub const HINSTANCE = windows.HINSTANCE;
pub const HPCON = windows.LPVOID;
pub const HRESULT = c_long;
pub const LARGE_INTEGER = windows.LARGE_INTEGER;
pub const LPCWSTR = windows.LPCWSTR;
pub const LPSTR = windows.LPSTR;
pub const LPVOID = windows.LPVOID;
pub const LPWSTR = windows.LPWSTR;
pub const PVOID = windows.PVOID;
pub const SIZE_T = windows.SIZE_T;
pub const UINT = windows.UINT;
pub const ULONG = windows.ULONG;
pub const ULONG_PTR = windows.ULONG_PTR;
pub const UNICODE_STRING = windows.UNICODE_STRING;

// Structs and opaque types
pub const LPPROC_THREAD_ATTRIBUTE_LIST = ?*anyopaque;
pub const SECURITY_ATTRIBUTES = windows.SECURITY_ATTRIBUTES;
pub const STARTF_USESTDHANDLES = windows.STARTF_USESTDHANDLES;
pub const STARTUPINFOW = windows.STARTUPINFOW;

pub const OVERLAPPED = extern struct {
    Internal: ULONG_PTR,
    InternalHigh: ULONG_PTR,
    DUMMYUNIONNAME: extern union {
        DUMMYSTRUCTNAME: extern struct {
            Offset: DWORD,
            OffsetHigh: DWORD,
        },
        Pointer: ?PVOID,
    },
    hEvent: ?HANDLE,
};
pub const PROCESS_INFORMATION = extern struct {
    hProcess: HANDLE,
    hThread: HANDLE,
    dwProcessId: DWORD,
    dwThreadId: DWORD,
};
pub const STARTUPINFOEX = extern struct {
    StartupInfo: windows.STARTUPINFOW,
    lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST,
};

// Well-known constant values
pub const INFINITE = 4294967295;
pub const INVALID_HANDLE_VALUE = windows.INVALID_HANDLE_VALUE;
pub const MAX_PATH = windows.MAX_PATH;
pub const FALSE: windows.BOOL = .fromBool(false);
pub const TRUE: windows.BOOL = .fromBool(true);

// Bit-field and enum constant values
pub const CREATE_UNICODE_ENVIRONMENT = 0x00000400;
pub const DELETE = 0x00010000;
pub const ERROR_SUCCESS = 0;
pub const EXTENDED_STARTUPINFO_PRESENT = 0x00080000;
pub const FILE_ATTRIBUTE_NORMAL = 0x80;
pub const FILE_FLAG_FIRST_PIPE_INSTANCE = 0x00080000;
pub const FILE_FLAG_OVERLAPPED = 0x40000000;
/// GetFinalPathNameByHandleW dwFlags: normalized name with a DOS drive
/// letter (both are the zero flag values).
pub const FILE_NAME_NORMALIZED = 0x0;
pub const FILE_NON_DIRECTORY_FILE = 0x00000040;
/// NtCreateFile CreateDisposition: open an existing file, never create.
/// Distinct from the Win32 CreateFileW value OPEN_EXISTING.
pub const FILE_OPEN = 0x00000001;
pub const FILE_OPEN_REPARSE_POINT = 0x00200000;
pub const FILE_SHARE_DELETE = 0x00000004;
pub const FILE_SHARE_READ = 0x00000001;
pub const FILE_SHARE_WRITE = 0x00000002;
pub const FILE_SYNCHRONOUS_IO_NONALERT = 0x00000020;
pub const GENERIC_READ = 0x80000000;
pub const HANDLE_FLAG_INHERIT = 0x00000001;
pub const MEM_COMMIT = 0x1000;
pub const MEM_RELEASE = 0x8000;
pub const MEM_RESERVE = 0x2000;
pub const OPEN_EXISTING = 3; // Known as FILE_OPEN in Windows docs
pub const PAGE_READWRITE = 0x04;
pub const PIPE_ACCESS_OUTBOUND = 0x00000002;
pub const PIPE_TYPE_BYTE = 0x00000000;
pub const PROC_THREAD_ATTRIBUTE_ADDITIVE = 0x00040000;
pub const PROC_THREAD_ATTRIBUTE_INPUT = 0x00020000;
pub const PROC_THREAD_ATTRIBUTE_NUMBER = 0x0000FFFF;
pub const PROC_THREAD_ATTRIBUTE_THREAD = 0x00010000;
pub const S_OK = 0;
pub const SYNCHRONIZE = 0x00100000;
pub const VOLUME_NAME_DOS = 0x0;
pub const WAIT_FAILED = 0xFFFFFFFF;

/// IOCTL that fills the output buffer with bytes from the kernel CSPRNG
/// behind `\Device\CNG` (what ProcessPrng and BCryptGenRandom draw from).
pub const IOCTL_KSEC_GEN_RANDOM: CTL_CODE = windows.IOCTL.KSEC.GEN_RANDOM;

pub const PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = ProcThreadAttributeValue(
    .ProcThreadAttributePseudoConsole,
    false,
    true,
    false,
);

// Types needed for ntdll calls
pub const ACCESS_MASK = windows.ACCESS_MASK;
pub const CTL_CODE = windows.CTL_CODE;
pub const FILE_ALL_INFORMATION = windows.FILE.ALL_INFORMATION;
pub const FILE_ATTRIBUTE_TAG_INFORMATION = windows.FILE.ATTRIBUTE_TAG_INFO;
pub const FILE_DISPOSITION_INFORMATION = windows.FILE.DISPOSITION.INFORMATION;
pub const FILE_DISPOSITION_INFORMATION_EX = windows.FILE.DISPOSITION.INFORMATION.EX;
pub const FILE_INFORMATION_CLASS = windows.FILE.INFORMATION_CLASS;
pub const FILE_POSITION_INFORMATION = windows.FILE.POSITION_INFORMATION;
pub const FILE_STANDARD_INFORMATION = windows.FILE.STANDARD_INFORMATION;
pub const IO_STATUS_BLOCK = windows.IO_STATUS_BLOCK;
pub const NTSTATUS = windows.NTSTATUS;
pub const OBJECT_ATTRIBUTES = windows.OBJECT.ATTRIBUTES;

// Window management (user32/gdi32/opengl32) types used by the Win32 apprt
// and the WGL OpenGL context.
pub const ATOM = windows.ATOM;
pub const HBRUSH = windows.HBRUSH;
pub const HCURSOR = windows.HCURSOR;
pub const HDC = windows.HDC;
pub const HGLRC = windows.HGLRC;
pub const HICON = windows.HICON;
pub const HMENU = windows.HMENU;
pub const HMODULE = windows.HMODULE;
pub const HWND = windows.HWND;
pub const LONG = windows.LONG;
pub const LPARAM = windows.LPARAM;
pub const LRESULT = isize;
pub const WORD = windows.WORD;
pub const WPARAM = usize;
pub const HGLOBAL = *anyopaque;
pub const DPI_AWARENESS_CONTEXT = isize;
/// A procedure address returned by GetProcAddress/wglGetProcAddress.
/// Kept opaque (align 1) because wglGetProcAddress may return sentinel
/// values such as 1, 2, 3 or -1 that are not valid function pointers.
pub const PROC = *const anyopaque;

pub const WNDPROC = *const fn (
    hwnd: HWND,
    msg: UINT,
    wparam: WPARAM,
    lparam: LPARAM,
) callconv(.winapi) LRESULT;

pub const POINT = extern struct {
    x: LONG,
    y: LONG,
};

pub const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

pub const MSG = extern struct {
    hwnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT = 0,
    lpfnWndProc: WNDPROC,
    cbClsExtra: c_int = 0,
    cbWndExtra: c_int = 0,
    hInstance: ?HINSTANCE = null,
    hIcon: ?HICON = null,
    hCursor: ?HCURSOR = null,
    hbrBackground: ?HBRUSH = null,
    lpszMenuName: ?LPCWSTR = null,
    lpszClassName: LPCWSTR,
    hIconSm: ?HICON = null,
};

pub const PAINTSTRUCT = extern struct {
    hdc: HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]u8,
};

pub const PIXELFORMATDESCRIPTOR = extern struct {
    nSize: WORD = @sizeOf(PIXELFORMATDESCRIPTOR),
    nVersion: WORD = 1,
    dwFlags: DWORD = 0,
    iPixelType: u8 = 0,
    cColorBits: u8 = 0,
    cRedBits: u8 = 0,
    cRedShift: u8 = 0,
    cGreenBits: u8 = 0,
    cGreenShift: u8 = 0,
    cBlueBits: u8 = 0,
    cBlueShift: u8 = 0,
    cAlphaBits: u8 = 0,
    cAlphaShift: u8 = 0,
    cAccumBits: u8 = 0,
    cAccumRedBits: u8 = 0,
    cAccumGreenBits: u8 = 0,
    cAccumBlueBits: u8 = 0,
    cAccumAlphaBits: u8 = 0,
    cDepthBits: u8 = 0,
    cStencilBits: u8 = 0,
    cAuxBuffers: u8 = 0,
    iLayerType: u8 = 0,
    bReserved: u8 = 0,
    dwLayerMask: DWORD = 0,
    dwVisibleMask: DWORD = 0,
    dwDamageMask: DWORD = 0,
};

pub const BITMAPINFOHEADER = extern struct {
    biSize: DWORD = @sizeOf(BITMAPINFOHEADER),
    biWidth: LONG,
    biHeight: LONG,
    biPlanes: WORD = 1,
    biBitCount: WORD,
    biCompression: DWORD = BI_RGB,
    biSizeImage: DWORD = 0,
    biXPelsPerMeter: LONG = 0,
    biYPelsPerMeter: LONG = 0,
    biClrUsed: DWORD = 0,
    biClrImportant: DWORD = 0,
};

pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]DWORD = .{0},
};

pub const TRACKMOUSEEVENT = extern struct {
    cbSize: DWORD = @sizeOf(TRACKMOUSEEVENT),
    dwFlags: DWORD,
    hwndTrack: HWND,
    dwHoverTime: DWORD = 0,
};

// Window messages
pub const WM_NULL = 0x0000;
pub const WM_CREATE = 0x0001;
pub const WM_DESTROY = 0x0002;
pub const WM_SIZE = 0x0005;
pub const WM_SETFOCUS = 0x0007;
pub const WM_KILLFOCUS = 0x0008;
pub const WM_PAINT = 0x000F;
pub const WM_CLOSE = 0x0010;
pub const WM_ERASEBKGND = 0x0014;
pub const WM_SETCURSOR = 0x0020;
pub const WM_GETMINMAXINFO = 0x0024;
pub const WM_NCCREATE = 0x0081;
pub const WM_KEYDOWN = 0x0100;
pub const WM_KEYUP = 0x0101;
pub const WM_CHAR = 0x0102;
pub const WM_DEADCHAR = 0x0103;
pub const WM_SYSKEYDOWN = 0x0104;
pub const WM_SYSKEYUP = 0x0105;
pub const WM_SYSCHAR = 0x0106;
pub const WM_SYSDEADCHAR = 0x0107;
pub const WM_UNICHAR = 0x0109;
pub const WM_TIMER = 0x0113;
pub const WM_MOUSEMOVE = 0x0200;
pub const WM_LBUTTONDOWN = 0x0201;
pub const WM_LBUTTONUP = 0x0202;
pub const WM_RBUTTONDOWN = 0x0204;
pub const WM_RBUTTONUP = 0x0205;
pub const WM_MBUTTONDOWN = 0x0207;
pub const WM_MBUTTONUP = 0x0208;
pub const WM_MOUSEWHEEL = 0x020A;
pub const WM_XBUTTONDOWN = 0x020B;
pub const WM_XBUTTONUP = 0x020C;
pub const WM_MOUSEHWHEEL = 0x020E;
pub const WM_MOUSELEAVE = 0x02A3;
pub const WM_DPICHANGED = 0x02E0;
pub const WM_USER = 0x0400;

// Window styles
pub const WS_OVERLAPPEDWINDOW = 0x00CF0000;
pub const WS_POPUP = 0x80000000;
pub const WS_EX_APPWINDOW = 0x00040000;
pub const WS_EX_TOOLWINDOW = 0x00000080;
pub const CS_HREDRAW = 0x0002;
pub const CS_VREDRAW = 0x0001;
pub const CS_OWNDC = 0x0020;
pub const CW_USEDEFAULT: c_int = @bitCast(@as(u32, 0x80000000));
pub const HWND_MESSAGE: HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -3))));
pub const GWLP_USERDATA = -21;
pub const SW_HIDE = 0;
pub const SW_SHOW = 5;
pub const SW_SHOWDEFAULT = 10;
pub const SW_MAXIMIZE = 3;
pub const SW_RESTORE = 9;
pub const SIZE_MINIMIZED = 1;
pub const PM_REMOVE = 0x0001;
pub const PM_NOREMOVE = 0x0000;
pub const HTCLIENT = 1;
pub const TME_LEAVE = 0x00000002;
pub const MK_SHIFT = 0x0004;
pub const MK_CONTROL = 0x0008;
pub const WHEEL_DELTA = 120;
pub const SWP_NOZORDER = 0x0004;
pub const SWP_NOACTIVATE = 0x0010;
pub const SWP_NOMOVE = 0x0002;
pub const SWP_FRAMECHANGED = 0x0020;
pub const GWL_STYLE = -16;
pub const MONITOR_DEFAULTTONEAREST = 0x00000002;
pub const USER_DEFAULT_SCREEN_DPI = 96;
pub const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2: DPI_AWARENESS_CONTEXT = -4;
pub const MB_OK = 0x00000000;
pub const MB_YESNO = 0x00000004;
pub const MB_ICONERROR = 0x00000010;
pub const MB_ICONWARNING = 0x00000030;
pub const IDYES = 6;
pub const XBUTTON1 = 0x0001;
pub const XBUTTON2 = 0x0002;

/// The result of MAKEINTRESOURCEW: an integer resource ID passed where
/// a string is expected. These are not aligned so they can't be LPCWSTR.
pub const LPCWSTR_RESOURCE = [*:0]align(1) const u16;

// Cursors (MAKEINTRESOURCE values)
pub const IDC_ARROW: LPCWSTR_RESOURCE = @ptrFromInt(32512);
pub const IDC_IBEAM: LPCWSTR_RESOURCE = @ptrFromInt(32513);
pub const IDC_WAIT: LPCWSTR_RESOURCE = @ptrFromInt(32514);
pub const IDC_CROSS: LPCWSTR_RESOURCE = @ptrFromInt(32515);
pub const IDC_SIZENWSE: LPCWSTR_RESOURCE = @ptrFromInt(32642);
pub const IDC_SIZENESW: LPCWSTR_RESOURCE = @ptrFromInt(32643);
pub const IDC_SIZEWE: LPCWSTR_RESOURCE = @ptrFromInt(32644);
pub const IDC_SIZENS: LPCWSTR_RESOURCE = @ptrFromInt(32645);
pub const IDC_SIZEALL: LPCWSTR_RESOURCE = @ptrFromInt(32646);
pub const IDC_NO: LPCWSTR_RESOURCE = @ptrFromInt(32648);
pub const IDC_HAND: LPCWSTR_RESOURCE = @ptrFromInt(32649);
pub const IDC_APPSTARTING: LPCWSTR_RESOURCE = @ptrFromInt(32650);
pub const IDC_HELP: LPCWSTR_RESOURCE = @ptrFromInt(32651);
pub const IDI_APPLICATION: LPCWSTR_RESOURCE = @ptrFromInt(32512);

// Virtual keys
pub const VK_BACK = 0x08;
pub const VK_SHIFT = 0x10;
pub const VK_CONTROL = 0x11;
pub const VK_MENU = 0x12;
pub const VK_CAPITAL = 0x14;
pub const VK_PROCESSKEY = 0xE5;
pub const VK_LWIN = 0x5B;
pub const VK_RWIN = 0x5C;
pub const VK_NUMLOCK = 0x90;
pub const VK_LSHIFT = 0xA0;
pub const VK_RSHIFT = 0xA1;
pub const VK_LCONTROL = 0xA2;
pub const VK_RCONTROL = 0xA3;
pub const VK_LMENU = 0xA4;
pub const VK_RMENU = 0xA5;
pub const MAPVK_VK_TO_CHAR = 2;

// Clipboard
pub const CF_UNICODETEXT = 13;
pub const GMEM_MOVEABLE = 0x0002;

// GDI/WGL
pub const BI_RGB = 0;
pub const DIB_RGB_COLORS = 0;
pub const SRCCOPY = 0x00CC0020;
pub const PFD_DRAW_TO_WINDOW = 0x00000004;
pub const PFD_SUPPORT_OPENGL = 0x00000020;
pub const PFD_DOUBLEBUFFER = 0x00000001;
pub const PFD_TYPE_RGBA = 0;
pub const PFD_MAIN_PLANE = 0;
pub const WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
pub const WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
pub const WGL_CONTEXT_FLAGS_ARB = 0x2094;
pub const WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126;
pub const WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
pub const WGL_CONTEXT_DEBUG_BIT_ARB = 0x00000001;

/// Signature of the wglCreateContextAttribsARB extension function.
pub const PFNWGLCREATECONTEXTATTRIBSARBPROC = *const fn (
    hdc: HDC,
    hShareContext: ?HGLRC,
    attribList: [*]const c_int,
) callconv(.winapi) ?HGLRC;

pub fn LOWORD(v: anytype) u16 {
    return @truncate(@as(usize, @bitCast(v)));
}

pub fn HIWORD(v: anytype) u16 {
    return @truncate(@as(usize, @bitCast(v)) >> 16);
}

/// GET_X_LPARAM: the signed low word of an LPARAM.
pub fn GET_X_LPARAM(v: LPARAM) i16 {
    return @bitCast(LOWORD(v));
}

/// GET_Y_LPARAM: the signed high word of an LPARAM.
pub fn GET_Y_LPARAM(v: LPARAM) i16 {
    return @bitCast(HIWORD(v));
}

// Exported functions by library
pub const exp = struct {
    pub const kernel32 = struct {
        pub extern "kernel32" fn CreatePipe(
            hReadPipe: *HANDLE,
            hWritePipe: *HANDLE,
            lpPipeAttributes: ?*const SECURITY_ATTRIBUTES,
            nSize: DWORD,
        ) callconv(.winapi) BOOL;
        pub extern "kernel32" fn CreatePseudoConsole(
            size: COORD,
            hInput: HANDLE,
            hOutput: HANDLE,
            dwFlags: DWORD,
            phPC: *HPCON,
        ) callconv(.winapi) HRESULT;
        pub extern "kernel32" fn ResizePseudoConsole(
            hPC: HPCON,
            size: COORD,
        ) callconv(.winapi) HRESULT;
        pub extern "kernel32" fn ClosePseudoConsole(hPC: HPCON) callconv(.winapi) void;
        pub extern "kernel32" fn InitializeProcThreadAttributeList(
            lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST,
            dwAttributeCount: DWORD,
            dwFlags: DWORD,
            lpSize: *SIZE_T,
        ) callconv(.winapi) BOOL;
        pub extern "kernel32" fn UpdateProcThreadAttribute(
            lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST,
            dwFlags: DWORD,
            Attribute: DWORD_PTR,
            lpValue: PVOID,
            cbSize: SIZE_T,
            lpPreviousValue: ?PVOID,
            lpReturnSize: ?*SIZE_T,
        ) callconv(.winapi) BOOL;
        pub extern "kernel32" fn PeekNamedPipe(
            hNamedPipe: HANDLE,
            lpBuffer: ?LPVOID,
            nBufferSize: DWORD,
            lpBytesRead: ?*DWORD,
            lpTotalBytesAvail: ?*DWORD,
            lpBytesLeftThisMessage: ?*DWORD,
        ) callconv(.winapi) BOOL;
        // Duplicated here because lpCommandLine is not marked optional in zig std
        pub extern "kernel32" fn CreateProcessW(
            lpApplicationName: ?LPWSTR,
            lpCommandLine: ?LPWSTR,
            lpProcessAttributes: ?*SECURITY_ATTRIBUTES,
            lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
            bInheritHandles: BOOL,
            dwCreationFlags: DWORD,
            lpEnvironment: ?*anyopaque,
            lpCurrentDirectory: ?LPWSTR,
            lpStartupInfo: *STARTUPINFOW,
            lpProcessInformation: *PROCESS_INFORMATION,
        ) callconv(.winapi) BOOL;
        /// https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getcomputernamea
        pub extern "kernel32" fn GetComputerNameA(
            lpBuffer: LPSTR,
            nSize: *DWORD,
        ) callconv(.winapi) BOOL;
        /// https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-gettemppathw
        pub extern "kernel32" fn GetTempPathW(
            nBufferLength: DWORD,
            lpBuffer: LPWSTR,
        ) callconv(.winapi) DWORD;
        pub extern "kernel32" fn SetHandleInformation(
            hObject: HANDLE,
            dwMask: DWORD,
            dwFlags: DWORD,
        ) callconv(.winapi) BOOL;
        pub extern "kernel32" fn CreateFileW(
            lpFileName: LPCWSTR,
            dwDesiredAccess: DWORD,
            dwShareMode: DWORD,
            lpSecurityAttributes: ?*SECURITY_ATTRIBUTES,
            dwCreationDisposition: DWORD,
            dwFlagsAndAttributes: DWORD,
            hTemplateFile: ?HANDLE,
        ) callconv(.winapi) HANDLE;
        pub extern "kernel32" fn CreateNamedPipeW(
            lpName: LPCWSTR,
            dwOpenMode: DWORD,
            dwPipeMode: DWORD,
            nMaxInstances: DWORD,
            nOutBufferSize: DWORD,
            nInBufferSize: DWORD,
            nDefaultTimeOut: DWORD,
            lpSecurityAttributes: ?*const SECURITY_ATTRIBUTES,
        ) callconv(.winapi) HANDLE;
        pub extern "kernel32" fn CloseHandle(
            hObject: HANDLE,
        ) callconv(.winapi) BOOL;
        pub extern "kernel32" fn VirtualAlloc(
            lpAddress: ?LPVOID,
            dwSize: SIZE_T,
            flAllocationType: DWORD,
            flProtect: DWORD,
        ) callconv(.winapi) ?LPVOID;
        pub extern "kernel32" fn VirtualFree(
            lpAddress: ?LPVOID,
            dwSize: SIZE_T,
            dwFreeType: DWORD,
        ) callconv(.winapi) BOOL;
        /// https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-discardvirtualmemory
        pub extern "kernel32" fn DiscardVirtualMemory(
            VirtualAddress: PVOID,
            Size: SIZE_T,
        ) callconv(.winapi) DWORD;
        pub extern "kernel32" fn WaitForSingleObject(
            hHandle: HANDLE,
            dwMilliseconds: DWORD,
        ) callconv(.winapi) DWORD;
        pub extern "kernel32" fn GetExitCodeProcess(
            hProcess: HANDLE,
            lpExitCode: *DWORD,
        ) callconv(.winapi) BOOL;
        pub extern "kernel32" fn TerminateProcess(
            hProcess: HANDLE,
            uExitCode: UINT,
        ) callconv(.winapi) BOOL;
        pub extern "kernel32" fn CancelIoEx(
            hFile: HANDLE,
            lpOverlapped: ?*OVERLAPPED,
        ) callconv(.winapi) BOOL;
        pub extern "kernel32" fn ReadFile(
            hFile: HANDLE,
            lpBuffer: LPVOID,
            nNumberOfBytesToRead: DWORD,
            lpNumberOfBytesRead: ?*DWORD,
            lpOverlapped: ?*OVERLAPPED,
        ) callconv(.winapi) BOOL;
        /// https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfinalpathnamebyhandlew
        pub extern "kernel32" fn GetFinalPathNameByHandleW(
            hFile: HANDLE,
            lpszFilePath: [*]u16,
            cchFilePath: DWORD,
            dwFlags: DWORD,
        ) callconv(.winapi) DWORD;
        pub extern "kernel32" fn GetModuleHandleW(
            lpModuleName: ?LPCWSTR,
        ) callconv(.winapi) ?HMODULE;
        pub extern "kernel32" fn LoadLibraryA(
            lpLibFileName: [*:0]const u8,
        ) callconv(.winapi) ?HMODULE;
        pub extern "kernel32" fn GetProcAddress(
            hModule: HMODULE,
            lpProcName: [*:0]const u8,
        ) callconv(.winapi) ?PROC;
        pub extern "kernel32" fn GlobalAlloc(
            uFlags: UINT,
            dwBytes: SIZE_T,
        ) callconv(.winapi) ?HGLOBAL;
        pub extern "kernel32" fn GlobalFree(hMem: HGLOBAL) callconv(.winapi) ?HGLOBAL;
        pub extern "kernel32" fn GlobalLock(hMem: HGLOBAL) callconv(.winapi) ?LPVOID;
        pub extern "kernel32" fn GlobalUnlock(hMem: HGLOBAL) callconv(.winapi) BOOL;
        pub extern "kernel32" fn GlobalSize(hMem: HGLOBAL) callconv(.winapi) SIZE_T;
    };
    pub const user32 = struct {
        pub extern "user32" fn RegisterClassExW(
            lpWndClass: *const WNDCLASSEXW,
        ) callconv(.winapi) ATOM;
        pub extern "user32" fn CreateWindowExW(
            dwExStyle: DWORD,
            lpClassName: LPCWSTR,
            lpWindowName: ?LPCWSTR,
            dwStyle: DWORD,
            X: c_int,
            Y: c_int,
            nWidth: c_int,
            nHeight: c_int,
            hWndParent: ?HWND,
            hMenu: ?HMENU,
            hInstance: ?HINSTANCE,
            lpParam: ?LPVOID,
        ) callconv(.winapi) ?HWND;
        pub extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.winapi) BOOL;
        pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: c_int) callconv(.winapi) BOOL;
        pub extern "user32" fn IsZoomed(hWnd: HWND) callconv(.winapi) BOOL;
        pub extern "user32" fn DefWindowProcW(
            hWnd: HWND,
            Msg: UINT,
            wParam: WPARAM,
            lParam: LPARAM,
        ) callconv(.winapi) LRESULT;
        pub extern "user32" fn GetMessageW(
            lpMsg: *MSG,
            hWnd: ?HWND,
            wMsgFilterMin: UINT,
            wMsgFilterMax: UINT,
        ) callconv(.winapi) BOOL;
        pub extern "user32" fn PeekMessageW(
            lpMsg: *MSG,
            hWnd: ?HWND,
            wMsgFilterMin: UINT,
            wMsgFilterMax: UINT,
            wRemoveMsg: UINT,
        ) callconv(.winapi) BOOL;
        pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;
        pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;
        pub extern "user32" fn PostMessageW(
            hWnd: ?HWND,
            Msg: UINT,
            wParam: WPARAM,
            lParam: LPARAM,
        ) callconv(.winapi) BOOL;
        pub extern "user32" fn PostQuitMessage(nExitCode: c_int) callconv(.winapi) void;
        pub extern "user32" fn GetDC(hWnd: ?HWND) callconv(.winapi) ?HDC;
        pub extern "user32" fn ReleaseDC(hWnd: ?HWND, hDC: HDC) callconv(.winapi) c_int;
        pub extern "user32" fn BeginPaint(
            hWnd: HWND,
            lpPaint: *PAINTSTRUCT,
        ) callconv(.winapi) ?HDC;
        pub extern "user32" fn EndPaint(
            hWnd: HWND,
            lpPaint: *const PAINTSTRUCT,
        ) callconv(.winapi) BOOL;
        pub extern "user32" fn InvalidateRect(
            hWnd: ?HWND,
            lpRect: ?*const RECT,
            bErase: BOOL,
        ) callconv(.winapi) BOOL;
        pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
        pub extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
        pub extern "user32" fn SetWindowPos(
            hWnd: HWND,
            hWndInsertAfter: ?HWND,
            X: c_int,
            Y: c_int,
            cx: c_int,
            cy: c_int,
            uFlags: UINT,
        ) callconv(.winapi) BOOL;
        pub extern "user32" fn AdjustWindowRectExForDpi(
            lpRect: *RECT,
            dwStyle: DWORD,
            bMenu: BOOL,
            dwExStyle: DWORD,
            dpi: UINT,
        ) callconv(.winapi) BOOL;
        pub extern "user32" fn SetWindowTextW(
            hWnd: HWND,
            lpString: LPCWSTR,
        ) callconv(.winapi) BOOL;
        pub extern "user32" fn SetWindowLongPtrW(
            hWnd: HWND,
            nIndex: c_int,
            dwNewLong: isize,
        ) callconv(.winapi) isize;
        pub extern "user32" fn GetWindowLongPtrW(
            hWnd: HWND,
            nIndex: c_int,
        ) callconv(.winapi) isize;
        pub extern "user32" fn LoadCursorW(
            hInstance: ?HINSTANCE,
            lpCursorName: LPCWSTR_RESOURCE,
        ) callconv(.winapi) ?HCURSOR;
        pub extern "user32" fn LoadIconW(
            hInstance: ?HINSTANCE,
            lpIconName: LPCWSTR_RESOURCE,
        ) callconv(.winapi) ?HICON;
        pub extern "user32" fn SetCursor(hCursor: ?HCURSOR) callconv(.winapi) ?HCURSOR;
        pub extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(.winapi) i16;
        pub extern "user32" fn MapVirtualKeyW(uCode: UINT, uMapType: UINT) callconv(.winapi) UINT;
        pub extern "user32" fn GetDpiForWindow(hwnd: HWND) callconv(.winapi) UINT;
        pub extern "user32" fn SetProcessDpiAwarenessContext(
            value: DPI_AWARENESS_CONTEXT,
        ) callconv(.winapi) BOOL;
        pub extern "user32" fn SetCapture(hWnd: HWND) callconv(.winapi) ?HWND;
        pub extern "user32" fn ReleaseCapture() callconv(.winapi) BOOL;
        pub extern "user32" fn TrackMouseEvent(lpEventTrack: *TRACKMOUSEEVENT) callconv(.winapi) BOOL;
        pub extern "user32" fn OpenClipboard(hWndNewOwner: ?HWND) callconv(.winapi) BOOL;
        pub extern "user32" fn CloseClipboard() callconv(.winapi) BOOL;
        pub extern "user32" fn EmptyClipboard() callconv(.winapi) BOOL;
        pub extern "user32" fn GetClipboardData(uFormat: UINT) callconv(.winapi) ?HANDLE;
        pub extern "user32" fn SetClipboardData(
            uFormat: UINT,
            hMem: ?HANDLE,
        ) callconv(.winapi) ?HANDLE;
        pub extern "user32" fn MessageBeep(uType: UINT) callconv(.winapi) BOOL;
        pub extern "user32" fn MessageBoxW(
            hWnd: ?HWND,
            lpText: LPCWSTR,
            lpCaption: LPCWSTR,
            uType: UINT,
        ) callconv(.winapi) c_int;
        pub extern "user32" fn SetForegroundWindow(hWnd: HWND) callconv(.winapi) BOOL;
    };
    pub const gdi32 = struct {
        pub extern "gdi32" fn ChoosePixelFormat(
            hdc: HDC,
            ppfd: *const PIXELFORMATDESCRIPTOR,
        ) callconv(.winapi) c_int;
        pub extern "gdi32" fn SetPixelFormat(
            hdc: HDC,
            format: c_int,
            ppfd: *const PIXELFORMATDESCRIPTOR,
        ) callconv(.winapi) BOOL;
        pub extern "gdi32" fn StretchDIBits(
            hdc: HDC,
            xDest: c_int,
            yDest: c_int,
            DestWidth: c_int,
            DestHeight: c_int,
            xSrc: c_int,
            ySrc: c_int,
            SrcWidth: c_int,
            SrcHeight: c_int,
            lpBits: ?*const anyopaque,
            lpbmi: *const BITMAPINFO,
            iUsage: UINT,
            rop: DWORD,
        ) callconv(.winapi) c_int;
    };
    pub const opengl32 = struct {
        pub extern "opengl32" fn wglCreateContext(hdc: HDC) callconv(.winapi) ?HGLRC;
        pub extern "opengl32" fn wglDeleteContext(hglrc: HGLRC) callconv(.winapi) BOOL;
        pub extern "opengl32" fn wglMakeCurrent(hdc: ?HDC, hglrc: ?HGLRC) callconv(.winapi) BOOL;
        pub extern "opengl32" fn wglGetProcAddress(name: [*:0]const u8) callconv(.winapi) ?PROC;
    };
    pub const ntdll = struct {
        pub extern "ntdll" fn NtCreateFile(
            FileHandle: *HANDLE,
            DesiredAccess: ACCESS_MASK,
            ObjectAttributes: *OBJECT_ATTRIBUTES,
            IoStatusBlock: *IO_STATUS_BLOCK,
            AllocationSize: ?*LARGE_INTEGER,
            FileAttributes: ULONG,
            ShareAccess: ULONG,
            CreateDisposition: ULONG,
            CreateOptions: ULONG,
            EaBuffer: ?*anyopaque,
            EaLength: ULONG,
        ) callconv(.winapi) NTSTATUS;
        pub extern "ntdll" fn NtOpenFile(
            FileHandle: *HANDLE,
            DesiredAccess: ACCESS_MASK,
            ObjectAttributes: *OBJECT_ATTRIBUTES,
            IoStatusBlock: *IO_STATUS_BLOCK,
            ShareAccess: ULONG,
            OpenOptions: ULONG,
        ) callconv(.winapi) NTSTATUS;
        pub extern "ntdll" fn NtClose(Handle: HANDLE) callconv(.winapi) NTSTATUS;
        pub extern "ntdll" fn NtReadFile(
            FileHandle: HANDLE,
            Event: ?HANDLE,
            ApcRoutine: ?*const anyopaque,
            ApcContext: ?*anyopaque,
            IoStatusBlock: *IO_STATUS_BLOCK,
            Buffer: *anyopaque,
            Length: ULONG,
            ByteOffset: ?*const LARGE_INTEGER,
            Key: ?*const ULONG,
        ) callconv(.winapi) NTSTATUS;
        pub extern "ntdll" fn NtQueryInformationFile(
            FileHandle: HANDLE,
            IoStatusBlock: *IO_STATUS_BLOCK,
            FileInformation: *anyopaque,
            Length: ULONG,
            FileInformationClass: FILE_INFORMATION_CLASS,
        ) callconv(.winapi) NTSTATUS;
        pub extern "ntdll" fn NtSetInformationFile(
            FileHandle: HANDLE,
            IoStatusBlock: *IO_STATUS_BLOCK,
            FileInformation: *anyopaque,
            Length: ULONG,
            FileInformationClass: FILE_INFORMATION_CLASS,
        ) callconv(.winapi) NTSTATUS;
        pub extern "ntdll" fn NtDeviceIoControlFile(
            FileHandle: HANDLE,
            Event: ?HANDLE,
            ApcRoutine: ?*const anyopaque,
            ApcContext: ?*anyopaque,
            IoStatusBlock: *IO_STATUS_BLOCK,
            IoControlCode: CTL_CODE,
            InputBuffer: ?*const anyopaque,
            InputBufferLength: ULONG,
            OutputBuffer: ?*anyopaque,
            OutputBufferLength: ULONG,
        ) callconv(.winapi) NTSTATUS;
        /// Resolves a Win32 path against the process working directory and
        /// canonicalizes it, keeping any `\\?\` or `\\.\` prefix. Returns
        /// the byte length written excluding the terminator, the required
        /// byte length if the buffer is too small, or 0 on failure.
        pub extern "ntdll" fn RtlGetFullPathName_U(
            FileName: [*:0]const u16,
            BufferByteLength: ULONG,
            Buffer: [*]u16,
            ShortName: ?*[*:0]const u16,
        ) callconv(.winapi) ULONG;
        /// The futex primitives that kernel32's WaitOnAddress and
        /// WakeByAddress* forward to. Timeout is a relative (negative)
        /// interval in 100ns units, null to wait forever.
        pub extern "ntdll" fn RtlWaitOnAddress(
            Address: *const anyopaque,
            CompareAddress: *const anyopaque,
            AddressSize: SIZE_T,
            Timeout: ?*const LARGE_INTEGER,
        ) callconv(.winapi) NTSTATUS;
        pub extern "ntdll" fn RtlWakeAddressSingle(Address: *const anyopaque) callconv(.winapi) void;
        pub extern "ntdll" fn RtlWakeAddressAll(Address: *const anyopaque) callconv(.winapi) void;
    };
};

pub const ProcThreadAttributeNumber = enum(DWORD) {
    ProcThreadAttributePseudoConsole = 22,
    _,
};

/// Corresponds to the ProcThreadAttributeValue define in WinBase.h
pub fn ProcThreadAttributeValue(
    comptime attribute: ProcThreadAttributeNumber,
    comptime thread: bool,
    comptime input: bool,
    comptime additive: bool,
) DWORD {
    return (@backingInt(attribute) & PROC_THREAD_ATTRIBUTE_NUMBER) |
        (if (thread) PROC_THREAD_ATTRIBUTE_THREAD else 0) |
        (if (input) PROC_THREAD_ATTRIBUTE_INPUT else 0) |
        (if (additive) PROC_THREAD_ATTRIBUTE_ADDITIVE else 0);
}
