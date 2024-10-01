import carpenter/table
import gh_terraform_registry/gh_client.{type GithubClient}
import gleam/dynamic
import gleam/result
import gleam/string
import repeatedly
import wisp

const module_repo_tags = "module_repo_tags"

/// An opaque cache type wrapping the ets table to confine 
/// casting dynamics to this module.
pub opaque type Cache {
  Cache(inner_table: table.Set(String, dynamic.Dynamic))
}

/// Build the ets table for storing responses from github
pub fn new() -> Result(Cache, Nil) {
  // Setup ETS table for caching info
  use cache <- result.try(
    table.build("GH Terraform Registry Cache")
    |> table.privacy(table.Public)
    |> table.write_concurrency(table.AutoWriteConcurrency)
    |> table.read_concurrency(True)
    |> table.decentralized_counters(True)
    |> table.compression(False)
    |> table.set,
  )

  Ok(Cache(cache))
}

/// Performs an intial fetch to github to get 
pub fn populate_module_version(
  cache cache: Cache,
  gh_client gh_client: GithubClient,
  refetch_period_minutes refetch_period_minutes: Int,
) {
  let timeout_ms = refetch_period_minutes * 1000 * 60
  use Nil <- result.try(update_modules(cache, gh_client))
  repeatedly.call(timeout_ms, Nil, fn(_, _) { update_modules(cache, gh_client) })
  Ok(Nil)
}

fn update_modules(cache: Cache, gh_client: GithubClient) {
  case gh_client.module_repo_tags(gh_client) {
    Error(e) -> {
      wisp.log_error(
        "There was an error updating the module versions! error: "
        <> string.inspect(e),
      )
      Error(e)
    }
    Ok(tags) -> {
      table.insert(cache.inner_table, [#(module_repo_tags, dynamic.from(tags))])
      Ok(Nil)
    }
  }
}

pub fn get_modules(cache: Cache) -> List(String) {
  let assert [#(_, tags)] = table.lookup(cache.inner_table, module_repo_tags)
  let assert Ok(tags) = dynamic.list(of: dynamic.string)(tags)
  tags
}
