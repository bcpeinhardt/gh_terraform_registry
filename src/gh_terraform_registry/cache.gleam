import carpenter/table
import gh_terraform_registry/gh_client.{type GithubClient}
import gleam/dynamic
import gleam/result
import gleam/string
import repeatedly
import toy
import wisp

const module_repo_tags = "module_repo_tags"

/// An opaque cache type wrapping the ets table to confine 
/// casting dynamics to this module.
pub opaque type Cache(a) {
  Cache(inner_table: table.Set(String, a))
}

/// Build the ets table for storing responses from github
pub fn new(name: String) -> Result(Cache(a), Nil) {
  // Setup ETS table for caching info
  use cache <- result.try(
    table.build(name)
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
  cache cache: Cache(List(String)),
  gh_client gh_client: GithubClient,
  refetch_period_minutes refetch_period_minutes: Int,
) {
  let timeout_ms = refetch_period_minutes * 1000 * 60
  use Nil <- result.try(update_module_versions(cache, gh_client))
  repeatedly.call(timeout_ms, Nil, fn(_, _) {
    update_module_versions(cache, gh_client)
  })
  Ok(Nil)
}

fn update_module_versions(cache: Cache(List(String)), gh_client: GithubClient) {
  case gh_client.module_repo_tags(gh_client) {
    Error(e) -> {
      wisp.log_error(
        "There was an error updating the module versions! error: "
        <> string.inspect(e),
      )
      Error(e)
    }
    Ok(tags) -> {
      table.insert(cache.inner_table, [#(module_repo_tags, tags)])
      Ok(Nil)
    }
  }
}

pub fn get_module_versions(cache: Cache(List(String))) -> List(String) {
  let assert [#(_, tags)] = table.lookup(cache.inner_table, module_repo_tags)
  tags
}

pub fn populate_module_contents(
  cache cache: Cache(List(gh_client.GithubFile)),
  gh_client gh_client: GithubClient,
  refetch_period_minutes refetch_period_minutes: Int,
  dir dir: String,
) {
  let timeout_ms = refetch_period_minutes * 1000 * 60
  use Nil <- result.try(update_module_contents(cache, gh_client, dir))
  repeatedly.call(timeout_ms, Nil, fn(_, _) {
    update_module_contents(cache, gh_client, dir)
  })
  Ok(Nil)
}

pub fn update_module_contents(
  cache: Cache(List(gh_client.GithubFile)),
  gh_client: GithubClient,
  dir: String,
) {
  case gh_client.module_contents(gh_client, dir) {
    Error(e) -> {
      wisp.log_error(
        "There was an error updating the module contents for module "
        <> dir
        <> "! error: "
        <> string.inspect(e),
      )
      Error(e)
    }
    Ok(files) -> {
      table.insert(cache.inner_table, [#(dir, files)])
      Ok(Nil)
    }
  }
}

import gleam/io

pub fn get_module_contents(
  cache: Cache(List(gh_client.GithubFile)),
  dir: String,
) -> List(gh_client.GithubFile) {
  let assert [#(_, files)] = table.lookup(cache.inner_table, dir)
  files
}
