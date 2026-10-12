using System.Management;
using System.Runtime.InteropServices;
using HWControl.HardwareIdentification;

if (args.Contains("--self-test", StringComparer.Ordinal))
{
    RunSelfTests();
    return;
}

if (!OperatingSystem.IsWindows())
{
    Console.Error.WriteLine("This collector is Windows-only.");
    Environment.ExitCode = 2;
    return;
}

var warnings = new List<string>();
var computers = Query("Win32_ComputerSystem", warnings);
var bios = Query("Win32_BIOS", warnings);
var boards = Query("Win32_BaseBoard", warnings);
var processors = Query("Win32_Processor", warnings);
var videoControllers = Query("Win32_VideoController", warnings);

var computer = computers.FirstOrDefault();
var biosItem = bios.FirstOrDefault();
var board = boards.FirstOrDefault();

var cpus = processors.Select(item =>
{
    var manufacturer = GetString(item, "Manufacturer");
    var model = HardwareCatalog.Normalize(GetString(item, "Name"));
    return new CpuIdentity
    {
        Manufacturer = HardwareCatalog.Normalize(manufacturer),
        Model = model,
        Architecture = RuntimeInformation.ProcessArchitecture.ToString(),
        PhysicalCores = GetInt(item, "NumberOfCores"),
        LogicalProcessors = GetInt(item, "NumberOfLogicalProcessors"),
        VendorFamily = HardwareCatalog.IdentifyCpuFamily(manufacturer, model)
    };
}).ToArray();

var gpus = videoControllers
    .Where(item => !string.IsNullOrWhiteSpace(GetString(item, "Name")))
    .Select(item =>
    {
        var manufacturer = GetString(item, "AdapterCompatibility");
        var model = HardwareCatalog.Normalize(GetString(item, "Name"));
        return new GpuIdentity
        {
            Manufacturer = HardwareCatalog.IdentifyVendor(manufacturer, model),
            Model = model,
            DriverProvider = HardwareCatalog.Normalize(GetString(item, "DriverProviderName")),
            DriverVersion = HardwareCatalog.Normalize(GetString(item, "DriverVersion")),
            PciDeviceId = ExtractPciDeviceId(GetString(item, "PNPDeviceID")),
            VendorFamily = HardwareCatalog.IdentifyVendor(manufacturer, model)
        };
    })
    .DistinctBy(gpu => $"{gpu.Model}|{gpu.PciDeviceId}")
    .ToArray();

var systemManufacturer = HardwareCatalog.Normalize(GetString(computer, "Manufacturer"));
var systemModel = HardwareCatalog.Normalize(GetString(computer, "Model"));
var systemFamily = HardwareCatalog.Normalize(GetString(computer, "SystemFamily"));

var inventory = new HardwareInventory
{
    Status = computer is not null || cpus.Length > 0 || gpus.Length > 0 ? "ok" : "unavailable",
    SystemManufacturer = systemManufacturer,
    SystemModel = systemModel,
    SystemFamily = HardwareCatalog.IdentifySystemFamily(systemManufacturer, systemModel, systemFamily)
        ?? systemFamily,
    BiosVendor = HardwareCatalog.Normalize(GetString(biosItem, "Manufacturer")),
    BiosVersion = HardwareCatalog.Normalize(GetString(biosItem, "SMBIOSBIOSVersion")),
    MotherboardVendor = HardwareCatalog.Normalize(GetString(board, "Manufacturer")),
    MotherboardModel = HardwareCatalog.Normalize(GetString(board, "Product")),
    MotherboardVersion = HardwareCatalog.Normalize(GetString(board, "Version")),
    Cpus = cpus,
    Gpus = gpus,
    Warnings = warnings.Distinct().ToArray()
};

Console.Out.WriteLine(System.Text.Json.JsonSerializer.Serialize(inventory, HardwareJson.Options));

static List<ManagementBaseObject> Query(string className, List<string> warnings)
{
    try
    {
        using var searcher = new ManagementObjectSearcher($"SELECT * FROM {className}");
        using var results = searcher.Get();
        return results.Cast<ManagementBaseObject>().ToList();
    }
    catch (ManagementException)
    {
        warnings.Add($"WMI query unavailable: {className}");
    }
    catch (UnauthorizedAccessException)
    {
        warnings.Add($"Access denied for WMI query: {className}");
    }
    catch (System.Runtime.InteropServices.COMException)
    {
        warnings.Add($"WMI provider error: {className}");
    }

    return [];
}

static string? GetString(ManagementBaseObject? item, string property)
{
    try
    {
        return item is not null ? item[property]?.ToString() : null;
    }
    catch (ManagementException)
    {
        return null;
    }
}

static int? GetInt(ManagementBaseObject item, string property)
{
    var value = GetString(item, property);
    return int.TryParse(value, out var parsed) && parsed >= 0 ? parsed : null;
}

static string? ExtractPciDeviceId(string? pnpDeviceId)
{
    if (string.IsNullOrWhiteSpace(pnpDeviceId))
        return null;

    // Keep only the vendor/device portion; discard instance-specific suffixes.
    var match = System.Text.RegularExpressions.Regex.Match(
        pnpDeviceId,
        @"(?i)VEN_[0-9A-F]{4}&DEV_[0-9A-F]{4}");
    return match.Success ? match.Value.ToUpperInvariant() : null;
}

static void RunSelfTests()
{
    Assert(HardwareCatalog.IdentifyCpuFamily("GenuineIntel", "13th Gen Intel(R) Core(TM) i9-13900H") == "Intel Core i9", "Intel Core i9 recognition");
    Assert(HardwareCatalog.IdentifyCpuFamily("AuthenticAMD", "AMD Ryzen 9 9950X") == "AMD Ryzen 9", "AMD Ryzen 9 recognition");
    Assert(HardwareCatalog.IdentifyVendor("NVIDIA Corporation", "NVIDIA GeForce RTX 5090") == "NVIDIA", "NVIDIA vendor recognition");
    Assert(HardwareCatalog.IdentifySystemFamily("HP", "OMEN Laptop 16", "OMEN") == "HP OMEN", "HP OMEN family recognition");
    Assert(HardwareCatalog.IdentifySystemFamily("HP", "EliteBook 840", "EliteBook") == "HP EliteBook", "HP EliteBook family recognition");
    Assert(HardwareCatalog.Normalize("  example   device  ") == "example device", "Whitespace normalization");
    Console.WriteLine("Hardware identification catalog self-tests passed.");
}

static void Assert(bool condition, string name)
{
    if (!condition)
        throw new InvalidOperationException($"Self-test failed: {name}");
}
