using System.ComponentModel;

namespace pcHealth;

public sealed class ProgramItem : INotifyPropertyChanged
{
    public ProgramItem()
    {
        Name = string.Empty;
        Glyph = string.Empty;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public string Name { get; set; } = string.Empty;
    public string Glyph { get; set; } = string.Empty;
    public string Note { get; set; } = "";
    public string WingetId { get; set; } = "";
    public string BrowserUrl { get; set; } = "";
    public string ExeName { get; set; } = "";
    public string RegistryName { get; set; } = "";
    public string Category { get; set; } = "General";

    private void Notify(string name) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    private bool _isInstalled;
    public bool IsInstalled
    {
        get => _isInstalled;
        set
        {
            if (_isInstalled == value) return;
            _isInstalled = value;
            Notify(nameof(IsInstalled));
            Notify(nameof(ButtonLabel));
        }
    }

    public string ButtonLabel =>
        IsInstalled ? "Installed" :
        string.IsNullOrEmpty(WingetId) ? "Open Download Page" :
                               "Install";

    public Microsoft.UI.Xaml.Visibility NoteVisibility =>
        string.IsNullOrEmpty(Note)
            ? Microsoft.UI.Xaml.Visibility.Collapsed
            : Microsoft.UI.Xaml.Visibility.Visible;
}
