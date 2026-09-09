using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;

namespace pcHealth.ViewModels;

public partial class LicenseKeyViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    [ObservableProperty] public partial bool IsLoading { get; set; } = true;
    [ObservableProperty] public partial string ErrorMessage { get; set; } = "";
    [ObservableProperty] public partial bool HasKey { get; set; }

    public LicenseResult? Result { get; private set; }

    [RelayCommand]
    public async Task LoadAsync()
    {
        try
        {
            Result = await Task.Run(KeyExtractor.Extract);
            HasKey = Result.BestKey is not null;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "License key extraction failed");
            ErrorMessage = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }
}
