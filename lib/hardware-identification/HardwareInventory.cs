using System.Text.Json.Serialization;

namespace HWControl.HardwareIdentification;

public sealed record HardwareInventory
{
    public int SchemaVersion { get; init; } = 1;
    public string Collector { get; init; } = "HWcontrol2.0 C# Hardware Identification";
    public string Platform { get; init; } = "windows";
    public string Status { get; init; } = "partial";
    public string? SystemManufacturer { get; init; }
    public string? SystemModel { get; init; }
    public string? SystemFamily { get; init; }
    public string? BiosVendor { get; init; }
    public string? BiosVersion { get; init; }
    public string? MotherboardVendor { get; init; }
    public string? MotherboardModel { get; init; }
    public string? MotherboardVersion { get; init; }
    public IReadOnlyList<CpuIdentity> Cpus { get; init; } = [];
    public IReadOnlyList<GpuIdentity> Gpus { get; init; } = [];
    public IReadOnlyList<string> Warnings { get; init; } = [];

    // Deliberately absent: serial numbers, UUIDs, MAC addresses, usernames,
    // product keys, and other stable identifiers not needed for model detection.
}

public sealed record CpuIdentity
{
    public string? Manufacturer { get; init; }
    public string? Model { get; init; }
    public string? Architecture { get; init; }
    public int? PhysicalCores { get; init; }
    public int? LogicalProcessors { get; init; }
    public string? VendorFamily { get; init; }
}

public sealed record GpuIdentity
{
    public string? Manufacturer { get; init; }
    public string? Model { get; init; }
    public string? DriverProvider { get; init; }
    public string? DriverVersion { get; init; }
    public string? PciDeviceId { get; init; }
    public string? VendorFamily { get; init; }
}

public static class HardwareJson
{
    public static readonly System.Text.Json.JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        WriteIndented = false
    };
}
