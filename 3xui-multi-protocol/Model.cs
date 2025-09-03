using Microsoft.EntityFrameworkCore;

public class MultiProtocolContext : DbContext
{
    public DbSet<Inbound> Inbounds { get; set; }
    public DbSet<Client_Traffics> Client_Traffics { get; set; }

    public string DbPath { get; }

    public MultiProtocolContext()
    {
        var folder = "/etc/x-ui/";
        DbPath = Path.Join(folder, "x-ui.db");
    }

    protected override void OnConfiguring(DbContextOptionsBuilder options)
        => options.UseSqlite($"Data Source={DbPath}");
}

public class Inbound
{
    public int? Id { get; set; }
    public string? listen { get; set; }
    public int? user_id { get; set; }
    public long? Up { get; set; }
    public long? Down { get; set; }
    public long? Total { get; set; }
    public string? Settings { get; set; }
    public string? tag { get; set; }
    public string? sniffing { get; set; }
    public string? Stream_Settings { get; set; }
    public string? Remark { get; set; }
    public bool? Enable { get; set; }
    public long? Expiry_Time { get; set; }
    public int? Port { get; set; }
    public string? Protocol { get; set; }
}

public class Client_Traffics
{
    public int? Id { get; set; }
    public int? Inbound_Id { get; set; }
    public int? Reset { get; set; }
    public string? Email { get; set; }
    public long? Up { get; set; }
    public long? Down { get; set; }
    public long? Total { get; set; }
    public long? Expiry_Time { get; set; }
    public bool? Enable { get; set; }
}

public class Client
{
    public string? email { get; set; }
    public bool? enable { get; set; }
    public long? expiryTime { get; set; }
    public string? flow { get; set; }
    public string? id { get; set; }
    public int? limitIp { get; set; }
    public bool? reset { get; set; }
    public string? subId { get; set; }
    public string? tgId { get; set; }
    public long? totalGB { get; set; }
}

// Renamed to PascalCase
public class InboundSetting 
{
    public required List<Client> clients { get; set; }
    public string? decryption { get; set; }
    public List<object>? fallbacks { get; set; }
}

// Renamed to PascalCase
public class LocalDB 
{
    public int Sec { get; set; }
    public required List<Client_Traffics> clients { get; set; }
}