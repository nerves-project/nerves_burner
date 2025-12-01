# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule NervesBurner.VersionChecker do
  @moduledoc """
  Checks for new versions of nerves_burner on GitHub releases.
  """

  alias NervesBurner.Output

  @repo "fhunleth/nerves_burner"

  @doc """
  Checks if a new version is available on GitHub and prompts user to download it.

  Exits if update succeeds so user can rerun.

  Errors are printed as warnings and the upgrade is skipped.
  """
  @spec check_and_prompt_update() :: :ok
  def check_and_prompt_update() do
    case check_for_update() do
      {:update_available, new_version, download_url} ->
        prompt_and_download_update(new_version, download_url)

      :up_to_date ->
        :ok

      {:error, reason} ->
        Output.warning("⚠ Version check skipped: #{reason}")
        :ok
    end
  end

  defp check_for_update() do
    url = "https://api.github.com/repos/#{@repo}/releases/latest"

    case Req.get(url, headers: github_headers()) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"tag_name" => tag_name, "assets" => assets} ->
            new_version = normalize_version(tag_name)
            curr_version = normalize_version(current_version())

            # Check if NERVES_BURNER_FORCE_UPDATE is set to skip version comparison
            force_update = System.get_env("NERVES_BURNER_FORCE_UPDATE") in ["1", "true", "yes"]

            cond do
              force_update ->
                # Force update regardless of version
                case find_executable_asset(assets) do
                  {:ok, download_url} ->
                    {:update_available, tag_name, download_url}

                  :not_found ->
                    {:error, "No executable found in release assets"}
                end

              Version.compare(new_version, curr_version) == :gt ->
                # Normal update check - newer version available
                case find_executable_asset(assets) do
                  {:ok, download_url} ->
                    {:update_available, tag_name, download_url}

                  :not_found ->
                    {:error, "No executable found in release assets"}
                end

              true ->
                :up_to_date
            end

          _ ->
            {:error, "Unexpected API response format"}
        end

      {:ok, %{status: status}} when status in [403, 429] ->
        {:error, "GitHub API rate limit exceeded"}

      {:ok, %{status: status}} ->
        {:error, "GitHub API returned status #{status}"}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  rescue
    error ->
      {:error, "Exception: #{inspect(error)}"}
  end

  defp find_executable_asset(assets) when is_list(assets) do
    # Look for 'nerves_burner' executable (no extension)
    case Enum.find(assets, fn asset -> asset["name"] == "nerves_burner" end) do
      %{"browser_download_url" => url} ->
        {:ok, url}

      nil ->
        :not_found
    end
  end

  defp find_executable_asset(_), do: :not_found

  defp prompt_and_download_update(new_version, download_url) do
    IO.puts("")
    Output.info("🎉 A new version of nerves_burner is available: #{new_version}")
    Output.info("Current version: #{current_version()}")
    IO.puts("")

    case get_user_input("Would you like to download the new version? (y/n): ") do
      input when input in ["y", "Y", "yes", "Yes", "YES"] ->
        download_new_version(new_version, download_url)

      _ ->
        Output.info("Continuing with current version...")
        :ok
    end
  end

  defp download_new_version(new_version, download_url) do
    temp_path = Path.join(System.tmp_dir!(), "nerves_burner_#{new_version}")

    Output.info("Downloading new version...")

    case download_file(download_url, temp_path) do
      :ok ->
        # Make executable
        case File.chmod(temp_path, 0o755) do
          :ok ->
            Output.success("✓ Download complete!")
            IO.puts("")

            # Try to replace the existing version
            case replace_current_executable(temp_path) do
              :ok ->
                Output.success("✓ Successfully replaced the current version!")
                Output.info("Run nerves_burner again to use the new version.")
                System.halt(0)

              {:error, reason} ->
                # Fall back to manual instructions
                Output.warning("⚠ Could not replace current version: #{reason}")
                Output.info("New version downloaded to: #{temp_path}")
                Output.info("Please replace the existing version manually and rerun.")
                System.halt(0)
            end

          {:error, reason} ->
            Output.warning("⚠ Failed to make file executable: #{inspect(reason)}")
            Output.info("Continuing with current version...")
            :ok
        end

      {:error, reason} ->
        Output.warning("⚠ Download failed: #{reason}")
        Output.info("Continuing with current version...")
        :ok
    end
  end

  defp replace_current_executable(new_path) do
    # Get the path to the current executable
    case get_current_executable_path() do
      {:ok, current_path} ->
        # Try to replace the current executable with the new one
        case File.cp(new_path, current_path) do
          :ok ->
            :ok

          {:error, reason} ->
            {:error, inspect(reason)}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_current_executable_path() do
    # When running as an escript, :escript.script_name() gives us the path
    script_name = :escript.script_name()
    path = List.to_string(script_name)
    {:ok, path}
  rescue
    _ ->
      {:error, "Not running as escript"}
  end

  defp download_file(url, dest_path) do
    case Req.get(url, headers: github_headers()) do
      {:ok, %{status: 200, body: body}} ->
        case File.write(dest_path, body) do
          :ok ->
            :ok

          {:error, reason} ->
            {:error, "Failed to write file: #{inspect(reason)}"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  rescue
    error ->
      {:error, inspect(error)}
  end

  defp get_user_input(prompt) do
    formatted_prompt = Output.prompt(prompt)

    IO.gets(formatted_prompt)
    |> to_string()
    |> String.trim()
  end

  # Normalize version string by removing 'v' prefix and other non-numeric characters
  defp normalize_version(version) when is_binary(version) do
    version
    |> String.trim()
    |> String.trim_leading("v")
    |> String.trim_leading("V")
  end

  # Get the current version from the application spec
  defp current_version() do
    :nerves_burner
    |> Application.spec(:vsn)
    |> to_string()
  end

  # Build headers for GitHub API requests, including auth token if available
  defp github_headers() do
    base_headers = [{"accept", "application/vnd.github+json"}]

    token = System.get_env("GITHUB_TOKEN") || System.get_env("GITHUB_API_TOKEN")

    case token do
      nil ->
        base_headers

      "" ->
        base_headers

      token ->
        [{"authorization", "token #{token}"} | base_headers]
    end
  end
end
