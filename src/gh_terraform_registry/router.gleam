import gh_terraform_registry/error
import gh_terraform_registry/gh_client
import gh_terraform_registry/web
import gleam/dynamic
import gleam/hackney
import gleam/http.{Get}
import gleam/json
import gleam/list
import gleam/result
import wisp.{type Request, type Response}

pub type Context {
  Context(gh_api_key: String, gh_owner: String, gh_modules_repo: String)
}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    // The remote service discovery endpoint
    [".well-known", "terraform.json"] -> remote_service_discovery()

    // Everything else should be namespaced under /api/modules/v1 to 
    // mimic the existing version (in case someone built custom workflows)
    ["api", "modules", "v1", ..rest] ->
      case rest {
        // Get the versions of a particular module.
        [namespace, name, system, "versions"] -> module_versions(req, ctx, name)

        // [namespace, name, system, version, "download"] -> download_module(req, ctx, name, version)
        _ -> wisp.not_found()
      }
    _ -> wisp.not_found()
  }
}

fn remote_service_discovery() {
  let res =
    json.object([#("modules.v1", json.string("/api/modules/v1"))])
    |> json.to_string_builder

  wisp.ok() |> wisp.string_builder_body(res)
}

type Tag {
  Tag(name: String)
}

fn tag_decoder() {
  dynamic.list(of: dynamic.decode1(Tag, dynamic.field("name", dynamic.string)))
}

// Retrieves the version of a particular module. Currently, our modules are not specifically versioned,
// so we use the version 
fn module_versions(req: Request, ctx: Context, name: String) -> Response {
  use <- wisp.require_method(req, Get)

  let res = {
    use req <- result.try(
      gh_client.github_request(
        ctx.gh_api_key,
        to: "/repos/"
          <> ctx.gh_owner
          <> "/"
          <> ctx.gh_modules_repo
          <> "/contents/config.toml",
      )
      |> result.replace_error(error.FailedToCreateRequest),
    )
    use res <- result.try(
      hackney.send(req) |> result.map_error(error.HackneyError),
    )

    use tags <- result.try(
      json.decode(res.body, tag_decoder())
      |> result.map_error(error.DecodeError),
    )
    let tags = list.map(tags, fn(tag) { tag.name })

    Ok(
      json.object([
        #(
          "modules",
          json.preprocessed_array([
            json.object([
              #("source", json.string("modules/" <> name <> "/coder")),
              #("versions", json.array(tags, of: json.string)),
            ]),
          ]),
        ),
      ]),
    )
  }

  case res {
    Error(e) -> wisp.internal_server_error()
    Ok(versions) ->
      wisp.ok() |> wisp.string_builder_body(versions |> json.to_string_builder)
  }
}
