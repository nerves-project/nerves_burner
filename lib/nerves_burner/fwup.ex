# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule NervesBurner.Fwup do
  @moduledoc """
  Interface to the fwup tool for burning firmware to MicroSD cards.
  """

  @doc """
  Checks if fwup is available on the system.
  """
  @spec available?() :: boolean()
  def available?() do
    case System.cmd("fwup", ["--version"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    ErlangError -> false
  end

  @doc """
  Scans for available devices (MicroSD cards).
  """
  @spec scan_devices() :: {:ok, [map()]} | {:error, String.t()}
  def scan_devices() do
    case System.cmd("fwup", ["--detect"], stderr_to_stdout: true) do
      {output, 0} ->
        devices =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&parse_device_line/1)
          |> Enum.reject(&is_nil/1)

        {:ok, devices}

      {error, _} ->
        if String.contains?(error, "No potential target devices found") do
          {:ok, []}
        else
          {:error, error}
        end
    end
  rescue
    e in ErlangError ->
      if e.original == :enoent do
        {:error,
         "fwup not found. Please install fwup: https://github.com/fwup-home/fwup#installing"}
      else
        {:error, "Failed to run fwup: #{inspect(e)}"}
      end
  end

  @doc """
  Burns firmware to the specified device

  Optionally accepts WiFi configuration to pass as environment variables.
  """
  @spec burn(String.t(), String.t(), map()) :: :ok | {:error, String.t()}
  def burn(firmware_path, device_path, wifi_config \\ %{}) do
    fwup_args = ["-d", device_path, firmware_path]

    {cmd, args} =
      if requires_sudo?() do
        {"sudo", ["fwup" | fwup_args]}
      else
        {"fwup", fwup_args}
      end

    env = build_wifi_env(wifi_config)

    case InteractiveCmd.cmd(cmd, args, env: env) do
      {_, 0} -> :ok
      {_, exit_code} -> {:error, "Failed to burn firmware: fwup error: #{exit_code}"}
    end
  end

  defp build_wifi_env(wifi_config) do
    env = %{}

    env =
      if Map.has_key?(wifi_config, :ssid) do
        Map.put(env, "NERVES_WIFI_SSID", wifi_config.ssid)
      else
        env
      end

    env =
      if Map.has_key?(wifi_config, :passphrase) do
        Map.put(env, "NERVES_WIFI_PASSPHRASE", wifi_config.passphrase)
      else
        env
      end

    env
  end

  defp requires_sudo?() do
    case :os.type() do
      {:unix, :linux} -> true
      {:unix, :darwin} -> false
      _ -> false
    end
  end

  # Parse a device line from fwup --detect output
  # Example: "/dev/sdc,15931539456"
  defp parse_device_line(line) do
    case String.split(line, ",", parts: 2) do
      [path, size_str] ->
        size =
          case Integer.parse(size_str) do
            {num, _} -> num
            _ -> nil
          end

        %{path: path, size: size}

      [path] ->
        %{path: path, size: nil}

      _ ->
        nil
    end
  end
end
