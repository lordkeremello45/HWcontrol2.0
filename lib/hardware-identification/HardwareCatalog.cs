using System.Text.RegularExpressions;

namespace HWControl.HardwareIdentification;

/// <summary>
/// Conservative, offline vendor/family recognition. Raw OS-reported model strings
/// are retained; this catalog adds labels and never guesses an exact SKU.
/// </summary>
public static partial class HardwareCatalog
{
    public static string? Normalize(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;

        var normalized = WhitespaceRegex().Replace(value.Trim(), " ");
        return normalized.Length == 0 ? null : normalized;
    }

    public static string? IdentifyVendor(string? manufacturer, string? model = null)
    {
        var text = $"{manufacturer} {model}".Trim().ToLowerInvariant();
        if (text.Length == 0)
            return null;

        if (ContainsAny(text, "nvidia", "geforce", "quadro", "tesla"))
            return "NVIDIA";
        if (ContainsAny(text, "advanced micro devices", "amd", "radeon"))
            return "AMD";
        if (ContainsAny(text, "intel", "arc graphics", "iris xe", "uhd graphics"))
            return "Intel";
        if (ContainsAny(text, "hewlett-packard", "hewlett packard", " hp "))
            return "HP";
        if (ContainsAny(text, "lenovo"))
            return "Lenovo";
        if (ContainsAny(text, "dell"))
            return "Dell";
        if (ContainsAny(text, "asus", "asustek"))
            return "ASUS";
        if (ContainsAny(text, "micro-star", "msi"))
            return "MSI";
        if (ContainsAny(text, "gigabyte"))
            return "Gigabyte";
        if (ContainsAny(text, "acer"))
            return "Acer";
        if (ContainsAny(text, "apple"))
            return "Apple";

        return Normalize(manufacturer);
    }

    public static string? IdentifyCpuFamily(string? manufacturer, string? model)
    {
        var text = $"{manufacturer} {model}".ToLowerInvariant();
        if (ContainsAny(text, "intel core ultra"))
            return "Intel Core Ultra";
        if (ContainsAny(text, "intel core i9", "core i9"))
            return "Intel Core i9";
        if (ContainsAny(text, "intel core i7", "core i7"))
            return "Intel Core i7";
        if (ContainsAny(text, "intel core i5", "core i5"))
            return "Intel Core i5";
        if (ContainsAny(text, "intel core i3", "core i3"))
            return "Intel Core i3";
        if (ContainsAny(text, "ryzen threadripper"))
            return "AMD Ryzen Threadripper";
        if (ContainsAny(text, "ryzen 9"))
            return "AMD Ryzen 9";
        if (ContainsAny(text, "ryzen 7"))
            return "AMD Ryzen 7";
        if (ContainsAny(text, "ryzen 5"))
            return "AMD Ryzen 5";
        if (ContainsAny(text, "ryzen 3"))
            return "AMD Ryzen 3";
        return null;
    }

    public static string? IdentifySystemFamily(string? manufacturer, string? model, string? family)
    {
        var text = $"{manufacturer} {model} {family}".ToLowerInvariant();
        if (text.Contains("omen")) return "HP OMEN";
        if (text.Contains("elitebook")) return "HP EliteBook";
        if (text.Contains("probook")) return "HP ProBook";
        if (text.Contains("pavilion")) return "HP Pavilion";
        if (text.Contains("victus")) return "HP Victus";
        if (text.Contains("thinkpad")) return "Lenovo ThinkPad";
        if (text.Contains("legion")) return "Lenovo Legion";
        if (text.Contains("ideapad")) return "Lenovo IdeaPad";
        if (text.Contains("precision")) return "Dell Precision";
        if (text.Contains("latitude")) return "Dell Latitude";
        if (text.Contains("alienware")) return "Dell Alienware";
        if (text.Contains("rog")) return "ASUS ROG";
        if (text.Contains("tuf")) return "ASUS TUF";
        if (text.Contains("predator")) return "Acer Predator";
        if (text.Contains("nitro")) return "Acer Nitro";
        return null;
    }

    private static bool ContainsAny(string text, params string[] candidates) =>
        candidates.Any(candidate => text.Contains(candidate, StringComparison.OrdinalIgnoreCase));

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhitespaceRegex();
}
