namespace GirCalculator.Web.Services;

/// <summary>What someone typed into the contact form.</summary>
/// <param name="Name">Sender's name.</param>
/// <param name="Email">Sender's address, used as reply-to.</param>
/// <param name="Subject">Subject line.</param>
/// <param name="Message">Body.</param>
public sealed record ContactMessage(
    string Name,
    string Email,
    string Subject,
    string Message);
