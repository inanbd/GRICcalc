using System.ComponentModel.DataAnnotations;

namespace GirCalculator.Web.Services;

/// <summary>
/// SMTP settings for the contact form, bound from the "Email" section of
/// appsettings.json.
/// </summary>
/// <remarks>
/// The password is deliberately blank in the committed file. Supply it out of
/// band - <c>dotnet user-secrets</c> in development, or the environment
/// variable <c>Email__Password</c> in production - so no credential is ever
/// committed.
/// </remarks>
public sealed class EmailOptions
{
    public const string SectionName = "Email";

    /// <summary>SMTP host, e.g. smtp.gmail.com.</summary>
    public string Host { get; set; } = string.Empty;

    /// <summary>SMTP port. 587 for STARTTLS, 465 for implicit TLS.</summary>
    [Range(1, 65535)]
    public int Port { get; set; } = 587;

    /// <summary>
    /// True for STARTTLS on a plain port (587), false for implicit TLS (465).
    /// </summary>
    public bool UseStartTls { get; set; } = true;

    public string UserName { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;

    /// <summary>Address the message is sent from. Many providers require this
    /// to match the authenticated account.</summary>
    public string FromAddress { get; set; } = string.Empty;

    public string FromName { get; set; } = "NICU GIR Calculator";

    /// <summary>Where contact messages are delivered.</summary>
    public string ToAddress { get; set; } = string.Empty;

    public string ToName { get; set; } = string.Empty;

    /// <summary>
    /// Seconds to wait on the SMTP conversation before giving up, so a
    /// unreachable server cannot hold a request open indefinitely.
    /// </summary>
    [Range(1, 120)]
    public int TimeoutSeconds { get; set; } = 20;

    /// <summary>
    /// Whether enough is configured to actually send. The contact page checks
    /// this so it can say the form is unavailable rather than accepting a
    /// message it will silently drop.
    /// </summary>
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(Host)
        && !string.IsNullOrWhiteSpace(FromAddress)
        && !string.IsNullOrWhiteSpace(ToAddress);
}
