import gh_terraform_registry/error
import gleam/dynamic
import gleam/hackney
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import toy
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

// ------------------------------------- Module Contents ----------------------------

pub fn module_contents(
  gh_client: GithubClient,
  dir: String,
) -> Result(List(GithubFile), error.Error) {
  wisp.log_debug("updating module contents")

  let slug = "/repos/" <> gh_client.owner <> "/modules/contents/" <> dir

  use req <- result.try(
    get(gh_client, slug:)
    |> result.replace_error(error.FailedToCreateRequest(slug:)),
  )

  use res <- result.try(
    hackney.send(req) |> result.map_error(error.HackneyError),
  )

  case res.status {
    200 -> {
      use the_json <- result.try(
        json.decode(res.body, dynamic.dynamic)
        |> result.map_error(error.DecodeError),
      )
      use contents <- result.try(
        the_json
        |> toy.decode(toy.list(github_file_decoder()))
        |> result.map_error(error.ToyDecodeError),
      )
      Ok(contents)
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

pub type GithubFile {
  GithubFile(
    name: String,
    path: String,
    sha: String,
    size: Int,
    url: String,
    html_url: String,
    git_url: String,
    download_url: String,
    type_: String,
    links: GithubLinkObject,
  )
}

pub type GithubLinkObject {
  GithubLinkObject(self: String, git: String, html: String)
}

pub fn github_file_decoder() {
  use name <- toy.field("name", toy.string)
  use path <- toy.field("path", toy.string)
  use sha <- toy.field("sha", toy.string)
  use size <- toy.field("size", toy.int)
  use url <- toy.field("url", toy.string)
  use html_url <- toy.field("html_url", toy.string)
  use git_url <- toy.field("git_url", toy.string)
  use download_url <- toy.field("download_url", toy.string)
  use type_ <- toy.field("type", toy.string)
  use links <- toy.field("_links", github_link_object_decoder())
  toy.decoded(GithubFile(
    name:,
    path:,
    sha:,
    size:,
    url:,
    html_url:,
    git_url:,
    download_url:,
    type_:,
    links:,
  ))
}

fn github_link_object_decoder() {
  use self <- toy.field("self", toy.string)
  use git <- toy.field("git", toy.string)
  use html <- toy.field("html", toy.string)
  toy.decoded(GithubLinkObject(self:, git:, html:))
}
