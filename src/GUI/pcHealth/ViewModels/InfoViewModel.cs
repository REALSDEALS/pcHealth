using CommunityToolkit.Mvvm.ComponentModel;
using System.Reflection;

namespace pcHealth.ViewModels;

public partial class InfoViewModel : ObservableObject
{
    public string Version { get; }

    public InfoViewModel()
    {
        var v = Assembly.GetExecutingAssembly().GetName().Version;
        Version = v is not null ? $"Version {v.Major}.{v.Minor}.{v.Build}" : "Version unknown";
    }
}
