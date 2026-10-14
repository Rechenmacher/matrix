/// MatrixScreenSaver — Windows screensaver entry point.
/// Windows screensavers are .exe files renamed to .scr, invoked with:
///   /s         — run screensaver fullscreen
///   /p <HWND>  — render preview in the Settings thumbnail
///   /c         — show configuration dialog
///   (no args)  — show configuration dialog

using System;
using System.Linq;
using System.Windows.Forms;

namespace MatrixScreenSaver;

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        ApplicationConfiguration.Initialize();

        var mode = ParseMode(args);

        switch (mode)
        {
            case ScreensaverMode.Screensaver:
                RunScreensaver();
                break;

            case ScreensaverMode.Preview when TryParseHwnd(args, out var hwnd):
                RunPreview(hwnd);
                break;

            case ScreensaverMode.Configure:
            default:
                RunConfigure();
                break;
        }
    }

    private static void RunScreensaver()
    {
        // Create a fullscreen form on every connected monitor
        var forms = Screen.AllScreens.Select(screen =>
        {
            var form = new ScreensaverForm(screen);
            form.Show();
            return form;
        }).ToList();

        if (forms.Count > 0)
            Application.Run(forms[0]);
    }

    private static void RunPreview(IntPtr hwnd)
    {
        var form = new PreviewForm(hwnd);
        form.Show();
        Application.Run(form);
    }

    private static void RunConfigure()
    {
        Application.Run(new PreferencesForm());
    }

    // MARK: - Argument parsing

    private enum ScreensaverMode { Screensaver, Preview, Configure }

    private static ScreensaverMode ParseMode(string[] args)
    {
        if (args.Length == 0) return ScreensaverMode.Configure;

        // Windows passes args like /s, /S, /p, /P, /c, /C or -s, -S, etc.
        var flag = args[0].TrimStart('/', '-').ToLowerInvariant();

        return flag switch
        {
            "s" => ScreensaverMode.Screensaver,
            "p" => ScreensaverMode.Preview,
            "c" => ScreensaverMode.Configure,
            _ => ScreensaverMode.Configure,
        };
    }

    private static bool TryParseHwnd(string[] args, out IntPtr hwnd)
    {
        hwnd = IntPtr.Zero;

        // HWND can be in args[1] or appended to /p like /p:12345
        string? hwndStr = null;

        if (args.Length >= 2)
        {
            hwndStr = args[1];
        }
        else if (args[0].Contains(':'))
        {
            hwndStr = args[0].Split(':')[1];
        }

        if (hwndStr != null && long.TryParse(hwndStr, out var value))
        {
            hwnd = new IntPtr(value);
            return true;
        }

        return false;
    }
}
