//// This service will provision data from github ahead of time 
//// for use by Coder applications, rather than relying on Github
//// to be available. 
//// This is to prevent issues with rate limiting/expired tokens/etc.
//// from slowing down registry.coder.com

import dot_env
import dot_env/env
import gh_terraform_registry/cache
import gh_terraform_registry/gh_client
import gh_terraform_registry/router
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  // Configure Logging
  wisp.configure_logger()
  wisp.set_logger_level(wisp.DebugLevel)
  wisp.log_debug("Logger configured")

  // Setup secret key
  let secret_key_base = wisp.random_string(64)

  // Load environment variables
  dot_env.load_default()
  let assert Ok(token) = env.get_string("GH_ACCESS_TOKEN")
  let assert Ok(modules_repo) = env.get_string("GH_MODULES_REPO")
  let assert Ok(owner) = env.get_string("GH_OWNER")
  let assert Ok(refetch_period_minutes) =
    env.get_int("CACHE_REFETCH_PERIOD_MINUTES")

  // Setup our github client and gh info cache
  let gh_client = gh_client.new(token:, owner:, modules_repo:)
  let assert Ok(versions_cache) = cache.new("Versions Cache")
  let assert Ok(file_cache) = cache.new("Files Cache")
  let assert Ok(Nil) =
    cache.populate_module_version(
      versions_cache,
      gh_client,
      refetch_period_minutes,
    )
  let assert Ok(Nil) =
    cache.populate_module_contents(
      file_cache,
      gh_client,
      refetch_period_minutes,
      "code-server",
      "main"
    )

  // Run the server
  let assert Ok(_) =
    wisp_mist.handler(
      router.handle_request(_, router.Context(
        gh_client:,
        versions_cache:,
        file_cache:,
      )),
      secret_key_base,
    )
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
