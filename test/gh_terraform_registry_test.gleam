import gh_terraform_registry/gh_client
import gh_terraform_registry/tar
import gleam/dynamic
import gleam/io
import gleeunit
import gleeunit/should
import simplifile

pub fn main() {
  // gleeunit.main()
  let assert Ok(b) = tar.pack_compressed_tar([#("x.txt", "Hello"), #("y.txt", "GoodBye")])
  simplifile.write_bits(b, to: "./test/i_am_a.tar.gz")
}

// pub fn pack_tar_test() {
//   let assert Ok(Nil) = simplifile.write("x", to: "./test/x.txt")
//   let assert Ok(Nil) = simplifile.write("y", to: "./test/y.txt")
//   let assert Ok(b) = tar.pack_compressed_tar([#("x.txt", "Hello"), #("y.txt", "GoodBye")])
//   let assert Ok(Nil) = simplifile.delete_all(["./test/x.txt", "./test/y.txt"])
//   simplifile.write_bits(b, to: "./test/i_am_a.tar.gz")
// }
