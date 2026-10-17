using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace pcHealth.Helpers;

/// <summary>
/// Factory methods for common ContentDialog patterns.
/// Avoids copy-pasting the same Title/Content/CloseButtonText/XamlRoot boilerplate.
/// </summary>
internal static class DialogHelper
{
    /// <summary>
    /// Shows a simple error dialog and waits for the user to dismiss it.
    /// Must be called on the UI thread.
    /// </summary>
    internal static async Task ShowErrorAsync(XamlRoot xamlRoot, string title, string message)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            Content = message,
            CloseButtonText = "OK",
            XamlRoot = xamlRoot,
        };
        await dialog.ShowAsync();
    }

    /// <summary>
    /// Asks the user to confirm something consequential. The close button is
    /// the default, so leaning on Enter cannot start anything.
    /// Must be called on the UI thread.
    /// </summary>
    internal static async Task<bool> ShowConfirmAsync(
        XamlRoot xamlRoot,
        string title,
        string message,
        string confirmText)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            Content = message,
            PrimaryButtonText = confirmText,
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = xamlRoot,
        };
        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }
}
