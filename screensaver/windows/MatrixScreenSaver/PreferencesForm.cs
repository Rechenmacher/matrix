using System;
using System.Drawing;
using System.Windows.Forms;

namespace MatrixScreenSaver;

/// <summary>
/// Settings dialog shown when the user right-clicks the .scr and selects "Configure",
/// or when the screensaver is invoked with /c.
/// </summary>
class PreferencesForm : Form
{
    private readonly ComboBox _versionCombo;
    private readonly ComboBox _effectCombo;
    private readonly TrackBar _speedTrack;
    private readonly TrackBar _bloomTrack;
    private readonly Label _speedValueLabel;
    private readonly Label _bloomValueLabel;

    private static readonly string[] Versions =
    {
        "classic", "3d", "operator", "nightmare", "paradise",
        "resurrections", "trinity", "megacity",
        "palimpsest", "twilight", "morpheus", "bugs"
    };

    private static readonly string[] Effects =
    {
        "plain", "pride", "stripes", "image", "mirror", "none"
    };

    public PreferencesForm()
    {
        Text = "Matrix Screensaver Options";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(360, 240);

        var y = 20;
        const int labelX = 20;
        const int controlX = 160;
        const int controlW = 170;
        const int rowH = 36;

        // Version
        AddLabel("Version:", labelX, y);
        _versionCombo = new ComboBox
        {
            DropDownStyle = ComboBoxStyle.DropDownList,
            Location = new Point(controlX, y),
            Width = controlW,
        };
        _versionCombo.Items.AddRange(Versions);
        Controls.Add(_versionCombo);

        y += rowH;

        // Effect
        AddLabel("Effect:", labelX, y);
        _effectCombo = new ComboBox
        {
            DropDownStyle = ComboBoxStyle.DropDownList,
            Location = new Point(controlX, y),
            Width = controlW,
        };
        _effectCombo.Items.AddRange(Effects);
        Controls.Add(_effectCombo);

        y += rowH;

        // Animation Speed (0.1 – 3.0, stored as int 1–30 in TrackBar)
        AddLabel("Animation speed:", labelX, y);
        _speedTrack = new TrackBar
        {
            Minimum = 1,
            Maximum = 30,
            TickFrequency = 5,
            Location = new Point(controlX, y),
            Width = controlW - 40,
        };
        _speedTrack.ValueChanged += (_, _) =>
            _speedValueLabel!.Text = (_speedTrack.Value / 10.0).ToString("F1");
        Controls.Add(_speedTrack);

        _speedValueLabel = new Label
        {
            Location = new Point(controlX + controlW - 35, y + 4),
            Width = 35,
            TextAlign = ContentAlignment.MiddleLeft,
        };
        Controls.Add(_speedValueLabel);

        y += rowH + 4;

        // Bloom Strength (0.0 – 1.0, stored as int 0–10)
        AddLabel("Bloom strength:", labelX, y);
        _bloomTrack = new TrackBar
        {
            Minimum = 0,
            Maximum = 10,
            TickFrequency = 2,
            Location = new Point(controlX, y),
            Width = controlW - 40,
        };
        _bloomTrack.ValueChanged += (_, _) =>
            _bloomValueLabel!.Text = (_bloomTrack.Value / 10.0).ToString("F1");
        Controls.Add(_bloomTrack);

        _bloomValueLabel = new Label
        {
            Location = new Point(controlX + controlW - 35, y + 4),
            Width = 35,
            TextAlign = ContentAlignment.MiddleLeft,
        };
        Controls.Add(_bloomValueLabel);

        y += rowH + 12;

        // OK / Cancel buttons
        var okButton = new Button
        {
            Text = "OK",
            DialogResult = DialogResult.OK,
            Location = new Point(ClientSize.Width - 170, y),
            Width = 75,
        };
        okButton.Click += OnOkClicked;
        Controls.Add(okButton);
        AcceptButton = okButton;

        var cancelButton = new Button
        {
            Text = "Cancel",
            DialogResult = DialogResult.Cancel,
            Location = new Point(ClientSize.Width - 90, y),
            Width = 75,
        };
        Controls.Add(cancelButton);
        CancelButton = cancelButton;

        LoadSettings();
    }

    private void AddLabel(string text, int x, int y)
    {
        Controls.Add(new Label
        {
            Text = text,
            Location = new Point(x, y + 4),
            AutoSize = true,
        });
    }

    private void LoadSettings()
    {
        var s = Settings.Load();
        _versionCombo.SelectedItem = s.Version;
        _effectCombo.SelectedItem = s.Effect;
        _speedTrack.Value = Math.Clamp((int)(s.AnimationSpeed * 10), 1, 30);
        _bloomTrack.Value = Math.Clamp((int)(s.BloomStrength * 10), 0, 10);
        _speedValueLabel.Text = s.AnimationSpeed.ToString("F1");
        _bloomValueLabel.Text = s.BloomStrength.ToString("F1");
    }

    private void OnOkClicked(object? sender, EventArgs e)
    {
        var s = new Settings
        {
            Version = _versionCombo.SelectedItem?.ToString() ?? "classic",
            Effect = _effectCombo.SelectedItem?.ToString() ?? "plain",
            AnimationSpeed = _speedTrack.Value / 10.0,
            BloomStrength = _bloomTrack.Value / 10.0,
        };
        s.Save();
        Close();
    }
}
