-module(gh_terraform_registry_ffi).

-export([pack_compressed_tar/1]).

pack_compressed_tar(Files) ->
    NewFiles = lists:map(
        fun({Name, Contents}) -> {unicode:characters_to_list(Name), Contents} end, Files
    ),
    case erl_tar:open({binary, <<>>}, [read]) of
        {error, _} ->
            {error, nil};
        {ok, TarDescriptor} ->
            lists:foreach(
                fun({Name, Contents}) -> erl_tar:add(TarDescriptor, {Name, Contents}, []) end, NewFiles
            ),
            file:read(TarDescriptor)
    end.
