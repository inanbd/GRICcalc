namespace GirCalculator.Web.Services;

/// <summary>Delivers a contact form submission.</summary>
public interface IEmailSender
{
    /// <summary>
    /// Sends <paramref name="message"/> to the configured recipient.
    /// Throws if delivery fails, so the caller can tell the sender rather than
    /// showing a success page for a message that never left.
    /// </summary>
    Task SendContactMessageAsync(
        ContactMessage message,
        CancellationToken cancellationToken = default);
}
