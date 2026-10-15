using System;
using System.Text;
using System.Runtime.InteropServices;

public static class KalingNative {
    public static Action<int> OnHotkey;
    public static Action OnSuspend;
    public static IntPtr HandleMessage(IntPtr h, int message, IntPtr w, IntPtr l, ref bool handled) {
        if(message==0x312){if(OnHotkey!=null)OnHotkey(w.ToInt32());handled=true;}
        else if(message==0x218 && w.ToInt32()==4){if(OnSuspend!=null)OnSuspend();}
        return IntPtr.Zero;
    }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct MonitorInfo { public int Size; public Rect Monitor, Work; public uint Flags; }
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point p);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
    [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr h, ref MonitorInfo info);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int count);
    [DllImport("user32.dll", EntryPoint="GetWindowLongW", SetLastError=true)] public static extern int GetStyle(IntPtr h, int index);
    [DllImport("user32.dll", EntryPoint="SetWindowLongW", SetLastError=true)] static extern int SetStyle(IntPtr h, int index, int value);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool RegisterHotKey(IntPtr h, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern uint GetDoubleClickTime();
    public static void ClickThrough(IntPtr h, bool enabled) {
        int s=GetStyle(h,-20) | 0x08000000 | 0x80; // NOACTIVATE + TOOLWINDOW
        s=enabled ? s|0x20 : s&~0x20;
        SetStyle(h,-20,s);
        SetWindowPos(h,IntPtr.Zero,0,0,0,0,0x37); // retain bounds/z-order/activation; refresh styles
    }
    public static bool CoversMonitor(Rect r, Rect m) {
        return r.Left<=m.Left+2 && r.Top<=m.Top+2 && r.Right>=m.Right-2 && r.Bottom>=m.Bottom-2;
    }
    public static bool IsFullscreen(IntPtr candidate, IntPtr pet) {
        if(candidate==IntPtr.Zero || candidate==pet || !IsWindowVisible(candidate) || IsIconic(candidate))return false;
        var name=new StringBuilder(256);GetClassName(candidate,name,256);
        string c=name.ToString();if(c=="Progman" || c=="WorkerW" || c=="Shell_TrayWnd" || c=="Shell_SecondaryTrayWnd")return false;
        IntPtr mon=MonitorFromWindow(candidate,2);if(mon!=MonitorFromWindow(pet,2))return false;
        var info=new MonitorInfo();info.Size=Marshal.SizeOf(info);Rect rect;
        return GetMonitorInfo(mon,ref info) && GetWindowRect(candidate,out rect) && CoversMonitor(rect,info.Monitor);
    }
}
