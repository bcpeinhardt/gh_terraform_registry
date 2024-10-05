//// Bindings to erl_tar

/// Pack a list of files into a tar file, gzip compressed. 
/// By convention the filename should end in .tar.gz or .tgz
@external(erlang, "gh_terraform_registry_ffi", "pack_compressed_tar")
pub fn pack_compressed_tar(
  // A list of tuples with #(filename_in_tar, file_contents)
  files: List(#(String, String)),
) -> Result(BitArray, Nil)
