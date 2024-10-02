import gleam/hackney
import gleam/json
import toy

pub type Error {
  FailedToCreateRequest(slug: String)
  HackneyError(hackney.Error)
  DecodeError(json.DecodeError)
  ToyDecodeError(List(toy.ToyError))
  GithubError(context: String)
}
