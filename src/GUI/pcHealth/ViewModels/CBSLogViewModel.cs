using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using System.Diagnostics;

namespace pcHealth.ViewModels;

public partial class CBSLogViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private readonly string _logPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.Windows),
        "Logs", "CBS", "CBS.log");

    [ObservableProperty] public partial string LogText { get; set; } = "Loading last 200 lines...";
    [ObservableProperty] public partial bool CanOpen { get; set; }
    public string LogPath => _logPath;

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (!File.Exists(_logPath))
        {
            LogText = "CBS.log not found.";
            CanOpen = false;
            return;
        }

        CanOpen = true;
        try
        {
            var lines = await Task.Run(ReadTail);
            LogText = string.Join("\n", lines);
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Could not read CBS.log");
            LogText = $"Could not read log: {ex.Message}";
        }
    }

    [RelayCommand(CanExecute = nameof(CanOpen))]
    public void OpenInNotepad()
    {
        if (!File.Exists(_logPath)) return;
        var psi = new ProcessStartInfo { FileName = "notepad.exe" };
        psi.ArgumentList.Add(_logPath);
        Process.Start(psi);
    }

    private List<string> ReadTail()
    {
        const int tailSize = 200;
        var queue = new Queue<string>(tailSize + 1);
        using var stream = new FileStream(_logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        using var reader = new StreamReader(stream, System.Text.Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
        string? line;
        while ((line = reader.ReadLine()) is not null)
        {
            if (queue.Count == tailSize) queue.Dequeue();
            queue.Enqueue(line);
        }
        return [.. queue];
    }
}
