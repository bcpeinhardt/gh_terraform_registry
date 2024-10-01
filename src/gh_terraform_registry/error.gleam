import gleam/hackney
import gleam/json

pub type Error {
  FailedToCreateRequest(slug: String)
  HackneyError(hackney.Error)
  DecodeError(json.DecodeError)
  GithubError(context: String)
}
