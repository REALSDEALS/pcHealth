using CommunityToolkit.Mvvm.ComponentModel;
using NLog;
using pcHealth.Services;

namespace pcHealth.ViewModels;

/// <summary>
/// Shared state for the pages that drive a single winget operation.
/// </summary>
/// <remarks>
/// The COM API reports a stage and a percentage, so these pages show a label
/// and a progress bar rather than a scrolling log. Both pages bind the same
/// property names, which is also why they look alike.
/// </remarks>
public abstract partial class WinGetViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    protected readonly IWinGet WinGet;

    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial double Percent { get; set; }
    [ObservableProperty] public partial bool IsIndeterminate { get; set; } = true;
    [ObservableProperty] public partial bool IsRunning { get; set; }

    public Microsoft.UI.Xaml.Visibility ProgressVisibility =>
        IsRunning ? Microsoft.UI.Xaml.Visibility.Visible : Microsoft.UI.Xaml.Visibility.Collapsed;

    partial void OnIsRunningChanged(bool value) => OnPropertyChanged(nameof(ProgressVisibility));

    protected WinGetViewModel(IWinGet winGet) => WinGet = winGet;

    protected bool CanStart() => !IsRunning;

    /// <summary>Run one winget operation, reporting its progress into this page.</summary>
    protected async Task ExecuteAsync(
        Func<IProgress<WinGetProgress>, Task<WinGetResult>> operation,
        string starting)
    {
        IsRunning = true;
        IsIndeterminate = true;
        Percent = 0;
        Status = starting;

        try
        {
            // Progress<T> posts back to the thread that constructed it, which
            // is the UI thread here, so the bindings need no dispatcher.
            var result = await operation(new Progress<WinGetProgress>(Show));
            Status = result.RebootRequired
                ? $"{result.Message} A restart is required."
                : result.Message;
        }
        catch (OperationCanceledException)
        {
            Status = "Cancelled.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "winget operation failed");
            Status = ex.Message;
        }
        finally
        {
            IsRunning = false;
            IsIndeterminate = false;
            Percent = 0;
        }
    }

    private void Show(WinGetProgress step)
    {
        Status = step.Stage;
        IsIndeterminate = step.Percent is null;
        if (step.Percent is double percent) Percent = percent;
    }
}
