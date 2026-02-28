using Microsoft.AspNetCore.Mvc;

namespace SimpleApi.Controllers;

public class HomeController : Controller
{

    private readonly IConfiguration _config;
    private readonly ILogger<HomeController> _logger;

    public HomeController(IConfiguration config, ILogger<HomeController> logger)
    {
        _config = config;
        _logger = logger;
    }

    [HttpGet("/")]
    public IActionResult Index()
    {
        _logger.LogInformation("Index page visited.");
        return View();
    }

    [HttpGet("/status")]
    public IActionResult Status()
    {   
        _logger.LogInformation("Status endpoint called.");
        return Json(new
        {
            service = "SimpleApi",
            uptime = (DateTime.UtcNow - System.Diagnostics.Process.GetCurrentProcess().StartTime.ToUniversalTime()).ToString(@"dd\.hh\:mm\:ss"),
            version = "1.0.0",
            healthy = true
        });
    }

    [HttpGet("/config")]
    public IActionResult Config()
    {
        _logger.LogInformation("Config endpoint called.");
        return Ok(new
        {
            environment = _config["ASPNETCORE_ENVIRONMENT"] ?? "Unknown",
            otlpEndpoint = _config["OTEL_EXPORTER_OTLP_ENDPOINT"] ?? "Not configured",
            exporterEnabled = !string.IsNullOrWhiteSpace(_config["OTEL_EXPORTER_OTLP_ENDPOINT"])
        });

    }
}
