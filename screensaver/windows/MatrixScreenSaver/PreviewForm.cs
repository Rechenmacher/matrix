using System;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Web.WebView2.WinForms;

namespace MatrixScreenSaver;

/// <summary>
/// Renders a preview of the screensaver inside the Windows Settings thumbnail.
/// The form is parented to the HWND provided by the /p argument.
/// </summary>
class PreviewForm : Form
{
    private readonly WebView2 _webView;

    [DllImport("user32.dll")]
    private static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    private static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left, Top, Right, Bottom;
    }

    private const int GWL_STYLE = -16;
    private const int WS_CHILD = 0x40000000;

    public PreviewForm(IntPtr parentHwnd)
    {
        FormBorderStyle = FormBorderStyle.None;
        BackColor = Color.Black;
        ShowInTaskbar = false;

        // Make this form a child of the preview window
        SetParent(Handle, parentHwnd);
        SetWindowLong(Handle, GWL_STYLE,
            GetWindowLong(Handle, GWL_STYLE) | WS_CHILD);

        // Size to fill the parent
        GetClientRect(parentHwnd, out var rect);
        Bounds = new Rectangle(0, 0, rect.Right - rect.Left, rect.Bottom - rect.Top);

        _webView = new WebView2
        {
            Dock = DockStyle.Fill,
            DefaultBackgroundColor = Color.Black,
        };

        Controls.Add(_webView);

        Load += async (_, _) =>
        {
            var env = await Microsoft.Web.WebView2.Core.CoreWebView2Environment.CreateAsync(
                userDataFolder: Path.Combine(Path.GetTempPath(), "MatrixScreenSaver_WebView2"));

            await _webView.EnsureCoreWebView2Async(env);

            _webView.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
            _webView.CoreWebView2.Settings.AreDevToolsEnabled = false;

            var webRoot = FindWebRoot();
            var indexPath = Path.Combine(webRoot, "index.html");
            var settings = Settings.Load();
            // Lower resolution for the tiny preview thumbnail
            var queryString = settings.DefaultQueryString + "&resolution=0.5";
            var url = $"file:///{indexPath.Replace('\\', '/')}?{queryString}";
            _webView.CoreWebView2.Navigate(url);
        };
    }

    private static string FindWebRoot()
    {
        var exeDir = AppContext.BaseDirectory;
        var webDir = Path.Combine(exeDir, "web");
        if (File.Exists(Path.Combine(webDir, "index.html")))
            return webDir;

        var repoRoot = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", "..", ".."));
        if (File.Exists(Path.Combine(repoRoot, "index.html")))
            return repoRoot;

        return Directory.GetCurrentDirectory();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
            _webView.Dispose();
        base.Dispose(disposing);
    }
}
