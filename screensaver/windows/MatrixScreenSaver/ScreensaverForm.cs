using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using Microsoft.Web.WebView2.WinForms;

namespace MatrixScreenSaver;

/// <summary>
/// Fullscreen borderless form with a WebView2 control that loads the Matrix digital rain.
/// One instance is created per monitor when running in /s mode.
/// </summary>
class ScreensaverForm : Form
{
    private readonly WebView2 _webView;
    private Point? _initialMousePos;

    public ScreensaverForm(Screen screen)
    {
        FormBorderStyle = FormBorderStyle.None;
        BackColor = Color.Black;
        StartPosition = FormStartPosition.Manual;
        Bounds = screen.Bounds;
        WindowState = FormWindowState.Normal;
        TopMost = true;
        ShowInTaskbar = false;
        DoubleBuffered = true;

        // Hide the cursor while the screensaver is running
        Cursor.Hide();

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

            // Disable all interactive features — this is a screensaver, not a browser
            _webView.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
            _webView.CoreWebView2.Settings.AreDevToolsEnabled = false;
            _webView.CoreWebView2.Settings.IsStatusBarEnabled = false;
            _webView.CoreWebView2.Settings.IsZoomControlEnabled = false;
            _webView.CoreWebView2.Settings.AreBrowserAcceleratorKeysEnabled = false;

            var url = BuildUrl();
            _webView.CoreWebView2.Navigate(url);
        };

        // Input events — exit on any interaction (after grace period)
        var graceTimer = new Timer { Interval = 2000 };
        graceTimer.Tick += (_, _) =>
        {
            graceTimer.Stop();
            graceTimer.Dispose();
            _initialMousePos = Cursor.Position;
            InstallInputHandlers();
        };
        graceTimer.Start();
    }

    private void InstallInputHandlers()
    {
        MouseMove += OnMouseMoved;
        MouseClick += (_, _) => ExitScreensaver();
        KeyDown += (_, _) => ExitScreensaver();

        // Also capture input on the WebView2 control
        _webView.MouseMove += OnMouseMoved;
        _webView.MouseClick += (_, _) => ExitScreensaver();
        _webView.KeyDown += (_, _) => ExitScreensaver();
    }

    private void OnMouseMoved(object? sender, MouseEventArgs e)
    {
        if (_initialMousePos is { } initial)
        {
            var dx = Math.Abs(Cursor.Position.X - initial.X);
            var dy = Math.Abs(Cursor.Position.Y - initial.Y);
            if (dx > 10 || dy > 10)
                ExitScreensaver();
        }
    }

    private void ExitScreensaver()
    {
        Cursor.Show();
        Application.Exit();
    }

    private static string BuildUrl()
    {
        var webRoot = FindWebRoot();
        var indexPath = Path.Combine(webRoot, "index.html");
        var settings = Settings.Load();
        return $"file:///{indexPath.Replace('\\', '/')}?{settings.DefaultQueryString}";
    }

    /// <summary>
    /// Locates the web assets directory. Checks in order:
    /// 1. A "web" folder next to the .scr/.exe
    /// 2. The parent directory (for development — running from within screensaver/windows/)
    /// </summary>
    private static string FindWebRoot()
    {
        var exeDir = AppContext.BaseDirectory;

        // Production layout: web/ folder next to the .scr
        var webDir = Path.Combine(exeDir, "web");
        if (File.Exists(Path.Combine(webDir, "index.html")))
            return webDir;

        // Dev layout: exe is in screensaver/windows/..., web root is repo root
        var repoRoot = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", "..", ".."));
        if (File.Exists(Path.Combine(repoRoot, "index.html")))
            return repoRoot;

        // Fallback: current directory
        return Directory.GetCurrentDirectory();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
            _webView.Dispose();
        base.Dispose(disposing);
    }
}
