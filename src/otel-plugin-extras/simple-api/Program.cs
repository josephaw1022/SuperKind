using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.ServiceDiscovery;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

const string HealthEndpointPath = "/health";
const string AlivenessEndpointPath = "/alive";

var builder = WebApplication.CreateBuilder(args);

// OpenTelemetry (logs + metrics + traces)
builder.Logging.AddOpenTelemetry(o =>
{
    o.IncludeFormattedMessage = true;
    o.IncludeScopes = true;
});

builder.Services.AddOpenTelemetry()
    .WithMetrics(m =>
    {
        m.AddAspNetCoreInstrumentation()
         .AddHttpClientInstrumentation()
         .AddRuntimeInstrumentation();
    })
    .WithTracing(t =>
    {
        t.AddSource(builder.Environment.ApplicationName)
         .AddAspNetCoreInstrumentation(o =>
         {
             o.Filter = ctx =>
                 !ctx.Request.Path.StartsWithSegments(HealthEndpointPath) &&
                 !ctx.Request.Path.StartsWithSegments(AlivenessEndpointPath);
         })
         .AddHttpClientInstrumentation();
    });

// OTLP exporter enabled when endpoint is provided
if (!string.IsNullOrWhiteSpace(builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]))
{
    builder.Services.AddOpenTelemetry().UseOtlpExporter();
}

// Service discovery + resilient HTTP
builder.Services.AddServiceDiscovery();
builder.Services.ConfigureHttpClientDefaults(http =>
{
    http.AddStandardResilienceHandler();
    http.AddServiceDiscovery();
});

// Health checks
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy(), new[] { "live" });

// Add controllers
builder.Services.AddControllers();
builder.Services.AddControllersWithViews();


var app = builder.Build();

// Health endpoints (always exposed)
app.MapHealthChecks(HealthEndpointPath);
app.MapHealthChecks(AlivenessEndpointPath, new HealthCheckOptions
{
    Predicate = r => r.Tags.Contains("live")
});

app.UseDefaultFiles();
app.UseStaticFiles();

// Map controllers
app.MapControllers();

app.Run();
