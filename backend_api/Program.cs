using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartTodo.Api.Data;

var builder = WebApplication.CreateBuilder(args);

// Render cung cấp biến môi trường PORT (mặc định 8080)
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Cho phép app Flutter trên mọi thiết bị Android gọi API
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});

// Tự động kết nối Supabase PostgreSQL qua biến môi trường DATABASE_URL (trên Render),
// hoặc dùng SQLite cục bộ khi chạy test trên máy dev chưa cấu hình DATABASE_URL.
var databaseUrl = Environment.GetEnvironmentVariable("DATABASE_URL")
    ?? builder.Configuration.GetConnectionString("DefaultConnection");

builder.Services.AddDbContext<AppDbContext>(options =>
{
    if (!string.IsNullOrWhiteSpace(databaseUrl))
    {
        var npgsqlConn = BuildNpgsqlConnectionString(databaseUrl);
        options.UseNpgsql(npgsqlConn);
    }
    else
    {
        options.UseSqlite("Data Source=workspace_dev.db");
    }
});

var app = builder.Build();

// Tự động khởi tạo 5 bảng trong Supabase PostgreSQL / SQLite nếu chưa tồn tại
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
}

// Bật Swagger UI ở cả Production để dễ kiểm thử & trình bày trong Báo cáo đồ án
app.UseSwagger();
app.UseSwaggerUI();

app.UseCors();
app.MapControllers();
app.MapGet("/", () => Results.Redirect("/swagger"));

app.Run();

static string BuildNpgsqlConnectionString(string raw)
{
    var trimmed = raw.Trim().Trim('"', '\'');
    if (!trimmed.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase) &&
        !trimmed.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
    {
        return trimmed;
    }

    // Tự tách thủ công theo dấu '@' CUỐI CÙNG để không bị lỗi UriFormatException
    // ngay cả khi mật khẩu Supabase chứa ký tự đặc biệt (@, #, ?, :, / ...)
    var schemeEnd = trimmed.IndexOf("://", StringComparison.Ordinal);
    var remainder = trimmed[(schemeEnd + 3)..];

    var lastAt = remainder.LastIndexOf('@');
    if (lastAt < 0)
    {
        throw new InvalidOperationException(
            "DATABASE_URL thiếu phần user:password@host.");
    }

    var userInfoPart = remainder[..lastAt];
    var hostAndDbPart = remainder[(lastAt + 1)..];

    var firstColon = userInfoPart.IndexOf(':');
    var username = firstColon >= 0
        ? Uri.UnescapeDataString(userInfoPart[..firstColon])
        : Uri.UnescapeDataString(userInfoPart);
    var password = firstColon >= 0
        ? Uri.UnescapeDataString(userInfoPart[(firstColon + 1)..])
        : string.Empty;

    // Tách query string (nếu có ?sslmode=...)
    var queryIndex = hostAndDbPart.IndexOf('?');
    var hostPath = queryIndex >= 0 ? hostAndDbPart[..queryIndex] : hostAndDbPart;

    var slashIndex = hostPath.IndexOf('/');
    var hostPort = slashIndex >= 0 ? hostPath[..slashIndex] : hostPath;
    var database = slashIndex >= 0 ? hostPath[(slashIndex + 1)..] : "postgres";

    var portColon = hostPort.LastIndexOf(':');
    var host = portColon >= 0 ? hostPort[..portColon] : hostPort;
    var port = portColon >= 0 && int.TryParse(hostPort[(portColon + 1)..], out var parsedPort)
        ? parsedPort
        : 5432;

    var csBuilder = new NpgsqlConnectionStringBuilder
    {
        Host = host,
        Port = port,
        Database = string.IsNullOrWhiteSpace(database) ? "postgres" : database,
        Username = username,
        Password = password,
        SslMode = SslMode.Require,
        Pooling = true
    };
    return csBuilder.ConnectionString;
}
