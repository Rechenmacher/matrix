using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MatrixScreenSaver;

/// <summary>
/// Persisted user preferences, stored as JSON in %APPDATA%\MatrixScreenSaver\settings.json.
/// </summary>
class Settings
{
    public string Version { get; set; } = "classic";
    public string Effect { get; set; } = "plain";
    public double AnimationSpeed { get; set; } = 1.0;
    public double BloomStrength { get; set; } = 0.7;

    // --- Default URL parameters (Matrix 1 movie style, matching Mac version) ---

    [JsonIgnore]
    public string DefaultQueryString
    {
        get
        {
            var p = new[]
            {
                ("skipIntro", "true"),
                ("suppressWarnings", "true"),
                ("version", Version),
                ("effect", Effect),
                ("font", "matrixcode"),
                ("numColumns", "90"),
                ("fallSpeed", "0.3"),
                ("cycleSpeed", "0.015"),
                ("raindropLength", "1.0"),
                ("bloomStrength", BloomStrength.ToString("F2")),
                ("bloomSize", "0.7"),
                ("highPassThreshold", "0.0"),
                ("cursorHSL", "0.33,1,0.1"),
                ("cursorIntensity", "0.0"),
                ("isolateCursor", "false"),
                ("brightnessDecay", "3.0"),
                ("baseBrightness", "-0.8"),
                ("baseContrast", "1.5"),
                ("paletteHSL", "0.33,0.95,0,0,0.33,1,0.3,30,0.33,1,0.6,70,0.34,0.85,0.8,100"),
                ("fps", "60"),
                ("resolution", "1"),
                ("animationSpeed", AnimationSpeed.ToString("F2")),
            };

            return string.Join("&", Array.ConvertAll(p,
                kv => $"{Uri.EscapeDataString(kv.Item1)}={Uri.EscapeDataString(kv.Item2)}"));
        }
    }

    // --- Persistence ---

    private static readonly string SettingsDir =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                     "MatrixScreenSaver");

    private static readonly string SettingsFile = Path.Combine(SettingsDir, "settings.json");

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    public static Settings Load()
    {
        try
        {
            if (File.Exists(SettingsFile))
            {
                var json = File.ReadAllText(SettingsFile);
                return JsonSerializer.Deserialize<Settings>(json, JsonOptions) ?? new Settings();
            }
        }
        catch
        {
            // Corrupt file — return defaults
        }
        return new Settings();
    }

    public void Save()
    {
        Directory.CreateDirectory(SettingsDir);
        var json = JsonSerializer.Serialize(this, JsonOptions);
        File.WriteAllText(SettingsFile, json);
    }
}
