//// This service will provision data from github ahead of time 
//// for use by Coder applications, rather than relying on Github
//// to be available. 
//// This is to prevent issues with rate limiting/expired tokens/etc.
//// from slowing down registry.coder.com

import dot_env
import dot_env/env
import gh_terraform_registry/router
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  dot_env.load_default()
  let assert Ok(gh_api_key) = env.get_string("GH_ACCESS_TOKEN")
  let assert Ok(gh_modules_repo) = env.get_string("GH_MODULES_REPO")
  let assert Ok(gh_owner) = env.get_string("GH_OWNER")

  let assert Ok(_) =
    wisp_mist.handler(
      router.handle_request(_, router.Context(
        gh_api_key:,
        gh_owner:,
        gh_modules_repo:,
      )),
      secret_key_base,
    )
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
