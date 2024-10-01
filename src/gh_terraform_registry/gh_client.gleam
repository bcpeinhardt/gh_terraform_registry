import gh_terraform_registry/error
import gleam/dynamic
import gleam/hackney
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import wisp

const base_url = "https://api.github.com"

pub opaque type GithubClient {
  GithubClient(token: String, owner: String, modules_repo: String)
}

pub fn new(
  token token: String,
  owner owner: String,
  modules_repo modules_repo: String,
) -> GithubClient {
  GithubClient(token:, owner:, modules_repo:)
}

/// Create a basic request to send to Github. Errors if the url
/// fails to parse.
fn get(
  gh_client: GithubClient,
  slug slug: String,
) -> Result(Request(String), Nil) {
  use req <- result.map(request.to(base_url <> slug))
  req
  |> request.set_method(http.Get)
  |> request.set_header("Authorization", "Bearer " <> gh_client.token)
  |> request.set_header("X-GitHub-Api-Version", "2022-11-28")
}

pub type GithubError {
  GithubError(message: String, documentation_url: String, status: Int)
}

fn github_error_decoder() {
  dynamic.decode3(
    GithubError,
    dynamic.field("message", of: dynamic.string),
    dynamic.field("documentation_url", of: dynamic.string),
    dynamic.field("status", of: dynamic.int),
  )
}

// --------------------------------- Tags ----------------------------------------------------

type Tag {
  Tag(name: String)
}

fn tag_decoder() {
  dynamic.list(of: dynamic.decode1(Tag, dynamic.field("name", dynamic.string)))
}

pub fn module_repo_tags(
  gh_client: GithubClient,
) -> Result(List(String), error.Error) {
  wisp.log_debug("Updating module repo tags")

  let slug =
    "/repos/" <> gh_client.owner <> "/" <> gh_client.modules_repo <> "/tags"

  use req <- result.try(
    get(gh_client, slug:)
    |> result.replace_error(error.FailedToCreateRequest(slug:)),
  )

  use res <- result.try(
    hackney.send(req) |> result.map_error(error.HackneyError),
  )

  case res.status {
    200 -> {
      use tags <- result.try(
        json.decode(res.body, tag_decoder())
        |> result.map_error(error.DecodeError),
      )

      let tags = list.map(tags, fn(tag) { tag.name })
      Ok(tags)
    }
    _ -> {
      use gh_error <- result.try(
        json.decode(res.body, github_error_decoder())
        |> result.map_error(error.DecodeError),
      )
      wisp.log_error(string.inspect(gh_error))
      Error(error.GithubError(string.inspect(gh_error)))
    }
  }
}
