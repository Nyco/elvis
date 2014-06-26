-module(elvis_SUITE).

-export([
         all/0,
         init_per_suite/1,
         end_per_suite/1
        ]).

-export([
         rock_with_empty_config/1,
         rock_with_incomplete_config/1,
         rock_with_file_config/1,
         check_configuration/1,
         find_file_and_check_src/1,
         verify_line_length_rule/1,
         verify_no_tabs_rule/1
        ]).

-define(EXCLUDED_FUNS,
        [
         module_info,
         all,
         test,
         init_per_suite,
         end_per_suite
        ]).

-type config() :: [{atom(), term()}].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Common test
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec all() -> [atom()].
all() ->
    Exports = elvis_SUITE:module_info(exports),
    [F || {F, _} <- Exports, not lists:member(F, ?EXCLUDED_FUNS)].

-spec init_per_suite(config()) -> config().
init_per_suite(Config) ->
    application:start(elvis),
    Config.

-spec end_per_suite(config()) -> config().
end_per_suite(Config) ->
    application:stop(elvis),
    Config.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Test Cases
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec rock_with_empty_config(config()) -> any().
rock_with_empty_config(_Config) ->
    ok = try
             elvis:rock([]),
             fail
         catch
             throw:invalid_config -> ok
         end.

-spec rock_with_incomplete_config(config()) -> any().
rock_with_incomplete_config(_Config) ->
    ElvisConfig = [{src_dirs, ["src"]}],
    ok = try
             elvis:rock(ElvisConfig),
             fail
         catch
             throw:invalid_config -> ok
         end.

-define(ROCK_WITH_TESTS,
        ["# ../../test/examples/fail_line_length.erl [FAIL]\n",
         "  - line_length\n",
         "    - Line 14 is too long: \"    io:format(\\\"This line is 81 "
         ++ "characters long and should be detected, yeah!!!\\\").\".\n",
         "    - Line 20 is too long: \"    io:format(\\\"This line is 90 "
         ++ "characters long and should be detected!!!!!!!!!!!!!!!!!!\\\")"
         ++ ".\".\n",
         "# ../../test/examples/fail_no_tabs.erl [FAIL]\n",
         "  - no_tabs\n",
         "    - Line 6 has a tab at column 0.\n",
         "    - Line 15 has a tab at column 0.\n",
         "# ../../test/examples/small.erl [OK]\n"]).

-spec rock_with_file_config(config()) -> ok.
rock_with_file_config(_Config) ->
    ct:capture_start(),
    ok = elvis:rock(),
    ct:capture_stop(),

    Captured = ct:capture_get([]),

    ?ROCK_WITH_TESTS = Captured.

-spec check_configuration(config()) -> any().
check_configuration(_Config) ->
    Config = [
              {src_dirs, ["src", "test"]},
              {rules, [{module, rule1, []}]}
             ],
    ["src", "test"] = elvis_utils:source_dirs(Config),
    [{module, rule1, []}] = elvis_utils:rules(Config).

-spec find_file_and_check_src(config()) -> any().
find_file_and_check_src(_Config) ->
    Dirs = ["../../test/examples"],

    [] = elvis_utils:find_files(Dirs, "doesnt_exist.erl"),
    [Path] = elvis_utils:find_files(Dirs, "small.erl"),

    {ok, <<"-module(small).\n">>} = elvis_utils:src([], Path),
    {error, enoent} = elvis_utils:src([], "doesnt_exist.erl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Rules
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec verify_line_length_rule(config()) -> any().
verify_line_length_rule(_Config) ->
    ElvisConfig = application:get_all_env(elvis),
    SrcDirs = elvis_utils:source_dirs(ElvisConfig),

    File = "fail_line_length.erl",
    {ok, Path} = elvis_test_utils:find_file(SrcDirs, File),

    Results = elvis_style:line_length(ElvisConfig, Path, [80]),
    ok = case length(Results) of
        2 -> ok;
        _ -> long_lines_undetected
    end.

-spec verify_no_tabs_rule(config()) -> any().
verify_no_tabs_rule(_Config) ->
    ElvisConfig = application:get_all_env(elvis),
    SrcDirs = elvis_utils:source_dirs(ElvisConfig),

    File = "fail_no_tabs.erl",
    {ok, Path} = elvis_test_utils:find_file(SrcDirs, File),

    Results = elvis_style:no_tabs(ElvisConfig, Path, []),
    ok = case length(Results) of
        2 -> ok;
        _ -> tabs_undetected
    end.
