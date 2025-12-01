# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule NervesBurner.InteractiveShell do
  @moduledoc """
  Interactive shell utilities for running commands that take over the terminal.
  """

  @doc """
  Start an interactive shell

  This shell will take over the terminal so that it's possible for the user
  to interact with whatever program is run. All input is sent to the called
  application including CTRL+C.

  It's not possible to get the exit code, so this only returns `:ok`.

  Options:
  * `:env` - a map of string key/value pairs to be put into the environment.
    See `System.put_env/1`.
  """
  @spec shell(binary(), [binary()], keyword()) :: :ok
  def shell(cmd, args, options \\ []) do
    original_env = System.get_env()

    command = cmd <> " " <> Enum.join(args, " ")

    # Everything after the trailing ; gets trimmed, so
    # the filename that's appended to the end by Erlang's
    # prompt editor support will get ignored.
    script_cmd =
      "script -q /dev/null " <>
        case :os.type() do
          {:unix, :linux} -> "-c \"#{command}\";"
          {:unix, _bsd} -> "#{command};"
        end

    System.put_env(Keyword.get(options, :env, %{}))
    System.put_env("VISUAL", script_cmd)
    send(:user_drv, {self(), {:open_editor, ""}})

    receive do
      {_pid, {:editor_data, _result}} -> :ok
    end

    restore_env(original_env)
  end

  defp restore_env(original) do
    env = System.get_env()
    System.put_env(original)

    to_delete = Map.keys(env) -- Map.keys(original)
    Enum.each(to_delete, &System.delete_env/1)
  end
end
