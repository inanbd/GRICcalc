using System.ComponentModel.DataAnnotations;
using GirCalculator.Web.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace GirCalculator.Web.Pages;

[EnableRateLimiting("contact")]
public class ContactModel : PageModel
{
    private readonly IEmailSender _emailSender;
    private readonly IOptionsMonitor<EmailOptions> _emailOptions;
    private readonly ILogger<ContactModel> _logger;

    public ContactModel(
        IEmailSender emailSender,
        IOptionsMonitor<EmailOptions> emailOptions,
        ILogger<ContactModel> logger)
    {
        _emailSender = emailSender;
        _emailOptions = emailOptions;
        _logger = logger;
    }

    [BindProperty]
    public InputModel Input { get; set; } = new();

    /// <summary>True once a message has been delivered.</summary>
    public bool Sent { get; private set; }

    /// <summary>
    /// Whether SMTP is set up. When it is not, the form is not shown at all,
    /// rather than accepting a message that would be silently dropped.
    /// </summary>
    public bool CanSend => _emailOptions.CurrentValue.IsConfigured;

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!CanSend)
        {
            ModelState.AddModelError(
                string.Empty,
                "The contact form is not available at the moment.");
            return Page();
        }

        // A bot fills in every field it finds; a person never sees this one.
        // Answer as though it worked, so there is nothing to tune against.
        if (!string.IsNullOrWhiteSpace(Input.Website))
        {
            _logger.LogInformation("Contact form honeypot triggered.");
            Sent = true;
            ModelState.Clear();
            Input = new InputModel();
            return Page();
        }

        if (!ModelState.IsValid) return Page();

        var message = new ContactMessage(
            Input.Name.Trim(),
            Input.Email.Trim(),
            Input.Subject.Trim(),
            Input.Message.Trim());

        try
        {
            await _emailSender.SendContactMessageAsync(message, cancellationToken);
        }
        catch (Exception ex)
        {
            // The reason belongs in the log, not on the page: it would tell an
            // attacker about the mail setup and means nothing to a visitor.
            _logger.LogError(ex, "Contact message could not be delivered.");
            ModelState.AddModelError(
                string.Empty,
                "Sorry - that could not be sent just now. Please try again later.");
            return Page();
        }

        Sent = true;
        ModelState.Clear();
        Input = new InputModel();
        return Page();
    }

    public sealed class InputModel
    {
        [Required(ErrorMessage = "Please enter your name.")]
        [StringLength(100, ErrorMessage = "Please keep the name under 100 characters.")]
        [Display(Name = "Name")]
        public string Name { get; set; } = string.Empty;

        [Required(ErrorMessage = "Please enter an email address so a reply can reach you.")]
        [EmailAddress(ErrorMessage = "That does not look like an email address.")]
        [StringLength(200)]
        [Display(Name = "Email")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Please enter a subject.")]
        [StringLength(150, ErrorMessage = "Please keep the subject under 150 characters.")]
        [Display(Name = "Subject")]
        public string Subject { get; set; } = string.Empty;

        [Required(ErrorMessage = "Please enter a message.")]
        [StringLength(5000, MinimumLength = 10,
            ErrorMessage = "Please write between 10 and 5000 characters.")]
        [Display(Name = "Message")]
        public string Message { get; set; } = string.Empty;

        /// <summary>
        /// Honeypot. Hidden from people by CSS and left out of the tab order;
        /// anything in it means the submission was automated.
        /// </summary>
        public string? Website { get; set; }
    }
}
