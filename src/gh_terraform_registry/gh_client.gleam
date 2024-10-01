import gleam/http/request.{type Request}
import gleam/result

const base_url = "https://api.github.com"

/// Create a basic request to send to Github. Errors if the url
/// fails to parse.
pub fn github_request(
  api_key: String,
  to slug: String,
) -> Result(Request(String), Nil) {
  use req <- result.map(request.to(base_url <> slug))
  req
  |> request.set_header("Authorization", "Bearer " <> api_key)
  |> request.set_header("X-GitHub-Api-Version", "2022-11-28")
}
