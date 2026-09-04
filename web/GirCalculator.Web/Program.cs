using System.Threading.RateLimiting;
using GirCalculator.Web.Services;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services
    .AddOptions<EmailOptions>()
    .Bind(builder.Configuration.GetSection(EmailOptions.SectionName))
    .ValidateDataAnnotations();

builder.Services
    .AddOptions<SiteOptions>()
    .Bind(builder.Configuration.GetSection(SiteOptions.SectionName));

builder.Services.AddSingleton<IEmailSender, SmtpEmailSender>();

// One submission every few seconds per address is plenty for a contact form,
// and stops the mailbox being used as a megaphone.
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("contact", limiter =>
    {
        limiter.PermitLimit = 5;
        limiter.Window = TimeSpan.FromMinutes(10);
        limiter.QueueLimit = 0;
    });
});

WebApplication app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
});

// The calculator runs entirely in the browser and posts nothing. A tight
// policy keeps it that way: no third-party origins to send anything to, and
// nothing but same-origin scripts.
app.Use(async (context, next) =>
{
    IHeaderDictionary headers = context.Response.Headers;
    headers["Content-Security-Policy"] =
        "default-src 'self'; "
        + "script-src 'self'; "
        + "style-src 'self'; "
        + "img-src 'self' data:; "
        + "font-src 'self'; "
        + "connect-src 'self'; "
        + "form-action 'self'; "
        + "frame-ancestors 'none'; "
        + "base-uri 'self'";
    headers["X-Content-Type-Options"] = "nosniff";
    headers["Referrer-Policy"] = "no-referrer";
    headers["X-Frame-Options"] = "DENY";
    await next();
});

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();
app.MapRazorPages();

app.Run();

/// <summary>Exposed so the test project can spin the app up in memory.</summary>
public partial class Program;
