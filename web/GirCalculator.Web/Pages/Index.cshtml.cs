using Microsoft.AspNetCore.Mvc.RazorPages;

namespace GirCalculator.Web.Pages;

/// <summary>
/// The calculator. There is deliberately no server-side model: every figure is
/// computed in the browser and nothing typed here is posted anywhere.
/// </summary>
public class IndexModel : PageModel
{
    public void OnGet()
    {
    }
}
