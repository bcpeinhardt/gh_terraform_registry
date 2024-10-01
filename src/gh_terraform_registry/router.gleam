import gh_terraform_registry/cache
import gh_terraform_registry/gh_client
import gh_terraform_registry/web
import gleam/http.{Get}
import gleam/json
import gleam/string
import wisp.{type Request, type Response}

pub type Context {
  Context(gh_client: gh_client.GithubClient, cache: cache.Cache)
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
        ["modules", name, "coder", "versions"] ->
          module_versions(req, ctx, name)

        // :namespace/:name/:system/:version/download
        ["modules", name, "coder", version, "download"] ->
          download_module(req, name, version)

        _ -> wisp.not_found()
      }

    _ -> wisp.not_found()
  }
}

fn download_module(req: Request, name: String, version: String) {
  use <- wisp.require_method(req, http.Get)

  let version = case string.starts_with(version, "v") {
    True -> version 
    False -> "v" <> version
  }

  wisp.no_content()
  |> wisp.set_header("X-Terraform-Get", "/api/modules/" <> name <> "?archive=tar.gz&ref=" <> version)
}

fn remote_service_discovery() {
  let res =
    json.object([#("modules.v1", json.string("/api/modules/v1"))])
    |> json.to_string_builder

  wisp.ok() |> wisp.string_builder_body(res)
}

// Retrieves the version of a particular module. Currently, our modules are not specifically versioned,
// so we use the version 
fn module_versions(req: Request, ctx: Context, name: String) -> Response {
  use <- wisp.require_method(req, Get)

  let res = {
    let tags = cache.get_modules(ctx.cache)

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
    Error(e) -> {
      wisp.log_error(e |> string.inspect)
      wisp.internal_server_error()
    }
    Ok(versions) ->
      wisp.ok() |> wisp.string_builder_body(versions |> json.to_string_builder)
  }
}
