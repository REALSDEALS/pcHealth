namespace pcHealth;

public sealed class ToolItem
{
    public ToolItem()
    {
        Name = string.Empty;
        Glyph = string.Empty;
        PageType = typeof(object);
    }

    public string Name { get; set; } = string.Empty;
    public string Glyph { get; set; } = string.Empty;
    public string Note { get; set; } = "";
    public Type PageType { get; set; } = typeof(object);
    public string Category { get; set; } = "General";
    public string[] Platforms { get; set; } = new[] { "Windows", "Linux" };

    public Visibility NoteVisibility =>
        string.IsNullOrEmpty(Note) ? Visibility.Collapsed : Visibility.Visible;
}
