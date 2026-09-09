using System.Collections.ObjectModel;

namespace pcHealth.Models
{
    public sealed class ItemGroup<T> : ObservableCollection<T>
    {
        public string Key { get; }

        public ItemGroup(string key, IEnumerable<T> items) : base(items ?? new List<T>())
        {
            Key = key;
        }
    }
}
