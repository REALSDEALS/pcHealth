using NLog;
using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class LicenseKeyPage : Page
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    public LicenseKeyViewModel ViewModel { get; } = App.Services.GetRequiredService<LicenseKeyViewModel>();

    private DispatcherQueueTimer? _copyResetTimer;

    public LicenseKeyPage()
    {
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            await ViewModel.LoadCommand.ExecuteAsync(null);
            PopulateUi();
        };
    }

    private void PopulateUi()
    {
        var result = ViewModel.Result;
        if (result is null) return;

        OsInfoText.Text = result.OsCaption;

        SetMethodCard(Oa3StatusText, Oa3KeyText, Oa3Icon, result.Oa3Key,
            "Not found - key not embedded in firmware");
        SetMethodCard(RegStatusText, RegKeyText, RegIcon, result.RegKey,
            "Not found - DigitalProductId registry value unavailable");

        if (result.BestKey is not null)
        {
            PrimaryKeyText.Text = result.BestKey;
            KeySourceText.Text = $"Source: {result.BestSource}";
            PrimaryKeyText.Foreground = result.IsGeneric
                ? (Brush)App.Current.Resources["SystemFillColorCautionBrush"]
                : new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x0F, 0x9D, 0x58));
            GenericWarning.IsOpen = result.IsGeneric;
            CopyBtn.IsEnabled = true;
            SaveBtn.IsEnabled = true;
        }
        else
        {
            PrimaryKeyText.Text = "No product key found.";
            PrimaryKeyText.Foreground = (Brush)App.Current.Resources["SystemFillColorCriticalBrush"];
            KeySourceText.Text =
                "Your system may use a digital licence linked to your Microsoft account, " +
                "or was activated via volume licensing (KMS/MAK).";
        }
    }

    private static void SetMethodCard(TextBlock statusText, TextBlock keyText, FontIcon icon, string? key, string notFoundMsg)
    {
        if (key is not null)
        {
            statusText.Text = "Found";
            keyText.Text = key;
            keyText.Visibility = Visibility.Visible;
            icon.Glyph = "";
            icon.Foreground = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x0F, 0x9D, 0x58));
        }
        else
        {
            statusText.Text = notFoundMsg;
            keyText.Visibility = Visibility.Collapsed;
            icon.Glyph = "";
            icon.Foreground = (Brush)App.Current.Resources["TextFillColorTertiaryBrush"];
        }
    }

    private void CopyBtn_Click(object sender, RoutedEventArgs e)
    {
        if (ViewModel.Result?.BestKey is null) return;
        var pkg = new DataPackage();
        pkg.SetText(ViewModel.Result.BestKey);
        Clipboard.SetContent(pkg);

        // Brief visual feedback before reverting the label.
        CopyBtn.Content = "Copied!";
        _copyResetTimer ??= DispatcherQueue.CreateTimer();
        _copyResetTimer.Stop();
        _copyResetTimer.Interval = TimeSpan.FromSeconds(1.5);
        _copyResetTimer.Tick += (_, _) => { CopyBtn.Content = "Copy Key"; _copyResetTimer.Stop(); };
        _copyResetTimer.Start();
    }

    // async void: anything that escapes here reaches no caller, so the process
    // fail-fasts. The whole body is guarded for that reason, and the catch is
    // broad because killing the app is worse than any exception it may hide.
    private async void SaveBtn_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            await SaveReportAsync();
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Saving the license key report failed");
            await ShowSaveFailedAsync(ex.Message);
        }
    }

    private async Task SaveReportAsync()
    {
        var result = ViewModel.Result;
        if (result?.BestKey is null) return;

        var picker = new FileSavePicker
        {
            SuggestedStartLocation = PickerLocationId.Desktop,
            SuggestedFileName = "windows-license-key",
        };

        // The leading dot is not decoration: FileTypeChoices rejects an
        // extension without one, and from an async void handler that rejection
        // took the app down rather than the dialog.
        picker.FileTypeChoices.Add("Text file", [".txt"]);

        if (App.MainWindow is null) return;
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(App.MainWindow));

        var file = await picker.PickSaveFileAsync();
        if (file is null) return;

        var lines = new[]
        {
            "pcHealth - Windows License Key Report",
            $"Generated : {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC",
            "",
            $"OS        : {result.OsCaption}",
            "",
            "Method 1 - OA3 (UEFI/BIOS Firmware):",
            $"  {result.Oa3Key ?? "Not found"}",
            "",
            "Method 2 - Registry (DigitalProductId):",
            $"  {result.RegKey ?? "Not found"}",
            "",
            $"Primary Key : {result.BestKey}",
            $"Source      : {result.BestSource}",
            result.IsGeneric
                ? $"\nWARNING: Generic placeholder key ({result.GenericEdition}). This key will not activate Windows."
                : "",
        };

        await Windows.Storage.FileIO.WriteLinesAsync(file, lines);
        Log.Info("Saved the license key report to {Path}", file.Path);
    }

    private async Task ShowSaveFailedAsync(string message)
    {
        var dialog = new ContentDialog
        {
            Title = "Save failed",
            Content = $"Could not save the report: {message}",
            CloseButtonText = "OK",
            XamlRoot = XamlRoot,
        };
        await dialog.ShowAsync();
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
