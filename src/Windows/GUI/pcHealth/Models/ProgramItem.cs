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

    // Installing used to open a console window. The card shows the progress
    // and the outcome itself now, so nothing has to pop up over the app.
    private bool _isBusy;
    public bool IsBusy
    {
        get => _isBusy;
        set
        {
            if (_isBusy == value) return;
            _isBusy = value;
            Notify(nameof(IsBusy));
            Notify(nameof(IsIdle));
            Notify(nameof(BusyVisibility));
        }
    }

    public bool IsIdle => !_isBusy;

    // The page binds Visibility properties rather than converting bools, which
    // is how NoteVisibility below already does it.
    public Microsoft.UI.Xaml.Visibility BusyVisibility =>
        _isBusy ? Microsoft.UI.Xaml.Visibility.Visible : Microsoft.UI.Xaml.Visibility.Collapsed;

    private string _status = "";
    public string Status
    {
        get => _status;
        set
        {
            if (_status == value) return;
            _status = value;
            Notify(nameof(Status));
            Notify(nameof(StatusVisibility));
        }
    }

    public Microsoft.UI.Xaml.Visibility StatusVisibility =>
        string.IsNullOrEmpty(Status)
            ? Microsoft.UI.Xaml.Visibility.Collapsed
            : Microsoft.UI.Xaml.Visibility.Visible;

    public string ButtonLabel =>
        IsInstalled ? "Installed" :
        string.IsNullOrEmpty(WingetId) ? "Open Download Page" :
                               "Install";

    public Microsoft.UI.Xaml.Visibility NoteVisibility =>
        string.IsNullOrEmpty(Note)
            ? Microsoft.UI.Xaml.Visibility.Collapsed
            : Microsoft.UI.Xaml.Visibility.Visible;
}
