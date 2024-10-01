import gleam/hackney
import gleam/json

pub type Error {
  FailedToCreateRequest
  HackneyError(hackney.Error)
  DecodeError(json.DecodeError)
}
