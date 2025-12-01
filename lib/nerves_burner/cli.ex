# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule NervesBurner.CLI do
  @moduledoc """
  Main CLI entry point for the Nerves Burner application.
  """

  alias NervesBurner.Output

  @spec main([String.t()]) :: no_return()
  def main(_args) do
    print_banner()

    # Check for version updates
    NervesBurner.VersionChecker.check_and_prompt_update()

    fwup_available = NervesBurner.Fwup.available?()

    with {:ok, image_config} <- select_firmware_image(),
         {:ok, target} <- select_target(image_config) do
      # Check if this target uses image assets
      target_override = NervesBurner.FirmwareImages.get_target_override(image_config, target)

      uses_image_asset = target_override && target_override.use_image_asset

      if uses_image_asset do
        # Image asset workflow - download only, no WiFi config, no burning
        case download_firmware(image_config, target) do
          {:ok, firmware_path} ->
            print_image_asset_instructions(firmware_path, image_config, target)

          {:error, reason} ->
            Output.error("\n✗ Error: #{reason}\n")
            System.halt(1)
        end
      else
        # Standard workflow with fwup
        if fwup_available do
          # Full workflow with fwup
          with {:ok, wifi_config} <- get_wifi_credentials(),
               {:ok, firmware_path} <- download_firmware(image_config, target),
               :ok <- select_device_and_burn(firmware_path, wifi_config) do
            Output.success("\n✓ Firmware burned successfully!\n")
            Output.info("You can now safely remove the MicroSD card.\n")
            print_next_steps(image_config, target)
          else
            {:error, :cancelled} ->
              IO.puts(IO.ANSI.format([:yellow, "\nOperation cancelled by user.\n", :reset]))
              System.halt(0)

            {:error, reason} ->
              IO.puts(
                IO.ANSI.format([
                  :red,
                  :bright,
                  "\n✗ Error: ",
                  :reset,
                  :red,
                  "#{reason}\n",
                  :reset
                ])
              )

              System.halt(1)
          end
        else
          # Download-only workflow without fwup
          case download_firmware(image_config, target) do
            {:ok, firmware_path} ->
              print_manual_burn_instructions(firmware_path)

            {:error, reason} ->
              Output.error("\n✗ Error: #{reason}\n")
              System.halt(1)
          end
        end
      end
    else
      {:error, :cancelled} ->
        Output.warning("\nOperation cancelled by user.\n")
        System.halt(0)

      {:error, reason} ->
        Output.error("\n✗ Error: #{reason}\n")
        System.halt(1)
    end
  end

  defp print_banner() do
    logo = """
    \e[38;5;24m████▄▄    \e[38;5;74m▐███
    \e[38;5;24m█▌  ▀▀██▄▄  \e[38;5;74m▐█
    \e[38;5;24m█▌  \e[38;5;74m▄▄  \e[38;5;24m▀▀  \e[38;5;74m▐█   \e[39mN  E  R  V  E  S
    \e[38;5;24m█▌  \e[38;5;74m▀▀██▄▄  ▐█
    \e[38;5;24m███▌    \e[38;5;74m▀▀████\e[0m
    """

    version = get_version()
    IO.puts(["\n", logo])
    IO.puts(IO.ANSI.format([:faint, "Nerves Burner v#{version}\n", :reset]))
  end

  defp select_firmware_image() do
    Output.section("Select a firmware image:\n")

    images = NervesBurner.FirmwareImages.list()

    images
    |> Enum.with_index(1)
    |> Enum.each(fn {{name, config}, index} ->
      Output.menu_option_with_parts(index, name, config[:description])
    end)

    Output.menu_option("?", "Learn more about a firmware image")

    case get_user_input("\nEnter your choice (1-#{length(images)} or ?): ") do
      "" ->
        {:error, :cancelled}

      "?" ->
        show_firmware_details(images)
        select_firmware_image()

      input ->
        case Integer.parse(input) do
          {num, _} when num >= 1 and num <= length(images) ->
            {_name, config} = Enum.at(images, num - 1)
            {:ok, config}

          _ ->
            Output.error("Invalid choice. Please try again.")
            select_firmware_image()
        end
    end
  end

  defp show_firmware_details(images) do
    Output.section("\nFirmware Details:\n")

    images
    |> Enum.with_index(1)
    |> Enum.each(fn {{name, config}, index} ->
      IO.puts(IO.ANSI.format(["\n", :yellow, "#{index}. ", :bright, "#{name}", :reset]))

      if Map.has_key?(config, :long_description) do
        IO.puts(IO.ANSI.format(["   ", :faint, String.trim(config.long_description), :reset]))
      end

      if Map.has_key?(config, :url) do
        Output.info("\n   More info: #{config.url}")
      end
    end)

    IO.puts("\n")
  end

  defp select_target(image_config) do
    targets = image_config.targets

    Output.section("\nSelect a target:\n")

    targets
    |> Enum.with_index(1)
    |> Enum.each(fn {target, index} ->
      friendly_name = NervesBurner.FirmwareImages.target_display_name(target)
      Output.menu_option(index, friendly_name)
    end)

    case get_user_choice(
           "\nEnter your choice (1-#{length(targets)}): ",
           1..length(targets)
         ) do
      {:ok, choice} ->
        {:ok, Enum.at(targets, choice - 1)}

      error ->
        error
    end
  end

  defp get_wifi_credentials() do
    Output.section("\nWould you like to configure WiFi credentials?")

    case get_user_input("Configure WiFi? (y/n): ") do
      input when input in ["y", "Y", "yes", "Yes", "YES"] ->
        get_wifi_details()

      _ ->
        {:ok, %{}}
    end
  end

  defp get_wifi_details() do
    ssid = get_user_input("\nEnter WiFi SSID: ")

    if ssid == "" do
      Output.warning("WiFi SSID cannot be empty. Skipping WiFi configuration.")
      {:ok, %{}}
    else
      passphrase = get_user_input("Enter WiFi passphrase: ")

      if passphrase == "" do
        Output.warning("WiFi passphrase cannot be empty. Skipping WiFi configuration.")
        {:ok, %{}}
      else
        {:ok, %{ssid: ssid, passphrase: passphrase}}
      end
    end
  end

  defp download_firmware(image_config, target) do
    Output.section("\nDownloading firmware...")

    case NervesBurner.Downloader.download(image_config, target) do
      {:ok, path} ->
        Output.labeled("✓ Download complete: ", "#{path}\n", :green)
        {:ok, path}

      {:error, reason} ->
        {:error, "Download failed: #{reason}"}
    end
  end

  defp select_device() do
    case scan_devices() do
      {:ok, [_ | _] = devices} ->
        choose_device(devices)

      {:ok, []} ->
        Output.warning("\nNo MicroSD cards detected.")

        case get_user_input("\nWould you like to rescan? (y/n): ") do
          input when input in ["y", "Y", "yes", "Yes"] ->
            select_device()

          _ ->
            {:error, :cancelled}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp scan_devices() do
    Output.info("\nScanning for MicroSD cards...")

    case NervesBurner.Fwup.scan_devices() do
      {:ok, devices} ->
        {:ok, devices}

      {:error, reason} ->
        {:error, "Failed to scan devices: #{reason}"}
    end
  end

  defp choose_device(devices) do
    Output.section("\nAvailable devices:\n")

    devices
    |> Enum.with_index(1)
    |> Enum.each(fn {device, index} ->
      size_info = if device.size, do: " (#{format_size(device.size)})", else: ""
      Output.menu_option(index, "#{device.path}#{size_info}")
    end)

    Output.menu_option(length(devices) + 1, "Rescan")

    case get_user_choice(
           "\nEnter your choice (1-#{length(devices) + 1}): ",
           1..(length(devices) + 1)
         ) do
      {:ok, choice} when choice == length(devices) + 1 ->
        select_device()

      {:ok, choice} ->
        device = Enum.at(devices, choice - 1)
        confirm_device(device)

      error ->
        error
    end
  end

  defp confirm_device(device) do
    Output.critical_warning("All data on #{device.path} will be erased!")

    case get_user_input("Are you sure you want to continue? (yes/no): ") do
      input when input in ["yes", "Yes", "YES"] ->
        {:ok, device.path}

      _ ->
        Output.warning("\nDevice selection cancelled.")
        select_device()
    end
  end

  defp select_device_and_burn(firmware_path, wifi_config) do
    with {:ok, device} <- select_device() do
      case burn_firmware(firmware_path, device, wifi_config) do
        :ok ->
          :ok

        {:error, reason} ->
          Output.error("\n✗ Error: #{reason}\n")

          case get_user_input("\nWould you like to try again? (y/n): ") do
            input when input in ["y", "Y", "yes", "Yes", "YES"] ->
              select_device_and_burn(firmware_path, wifi_config)

            _ ->
              {:error, :cancelled}
          end
      end
    end
  end

  defp burn_firmware(firmware_path, device_path, wifi_config) do
    Output.section("\nBurning firmware to #{device_path}...")

    if Map.has_key?(wifi_config, :ssid) do
      Output.info("Setting WiFi SSID: #{wifi_config.ssid}")
    end

    Output.warning("This may take several minutes. Please do not remove the card.\n")

    NervesBurner.Fwup.burn(firmware_path, device_path, wifi_config)
  end

  defp get_user_choice(prompt, range) do
    case get_user_input(prompt) do
      "" ->
        {:error, :cancelled}

      input ->
        case Integer.parse(input) do
          {num, _} ->
            if num in range do
              {:ok, num}
            else
              Output.error("Invalid choice. Please try again.")
              get_user_choice(prompt, range)
            end

          _ ->
            Output.error("Invalid choice. Please try again.")
            get_user_choice(prompt, range)
        end
    end
  end

  defp get_user_input(prompt) do
    formatted_prompt = Output.prompt(prompt)

    IO.gets(formatted_prompt)
    |> to_string()
    |> String.trim()
  end

  defp format_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000_000_000 ->
        "#{Float.round(bytes / 1_000_000_000_000, 2)} TB"

      bytes >= 1_000_000_000 ->
        "#{Float.round(bytes / 1_000_000_000, 2)} GB"

      bytes >= 1_000_000 ->
        "#{Float.round(bytes / 1_000_000, 2)} MB"

      bytes >= 1_000 ->
        "#{Float.round(bytes / 1_000, 2)} KB"

      true ->
        "#{bytes} B"
    end
  end

  defp format_size(_), do: ""

  defp print_manual_burn_instructions(firmware_path) do
    Output.success("\n✓ Firmware downloaded successfully!\n")

    IO.puts(
      IO.ANSI.format([
        :yellow,
        :bright,
        "⚠️  Note: fwup is not installed on this system.\n",
        :reset
      ])
    )

    Output.labeled("File location: ", "#{firmware_path}\n")
    Output.section("\nYou can burn this image to a MicroSD card using:\n")

    # Determine the file type and provide appropriate instructions
    cond do
      String.ends_with?(firmware_path, ".zip") ->
        Output.info(
          "1. Extract the ZIP file to get the .img file\n2. Use one of the following tools:\n"
        )

      String.ends_with?(firmware_path, ".img.gz") ->
        Output.info(
          "1. Extract the .img.gz file (e.g., gunzip) to get the .img file\n2. Use one of the following tools:\n"
        )

      String.ends_with?(firmware_path, ".img") ->
        Output.info("Use one of the following tools:\n")

      true ->
        Output.info("Use one of the following tools:\n")
    end

    IO.puts(
      IO.ANSI.format([
        "\n  ",
        :yellow,
        "• Etcher",
        :reset,
        " (Recommended - Cross-platform GUI tool)\n",
        "    Download from: ",
        :bright,
        "https://etcher.balena.io/\n",
        :reset
      ])
    )

    IO.puts(
      IO.ANSI.format([
        "\n  ",
        :yellow,
        "• dd",
        :reset,
        " (Linux/macOS command-line tool)\n",
        "    Example: ",
        :bright,
        "sudo dd if=<img-file> of=/dev/sdX bs=4M status=progress\n",
        :reset,
        "    ",
        :red,
        "⚠️  Warning: Double-check the device path (of=...) to avoid data loss!\n",
        :reset
      ])
    )

    IO.puts(
      IO.ANSI.format([
        "\n  ",
        :yellow,
        "• Win32 Disk Imager",
        :reset,
        " (Windows)\n",
        "    Download from: ",
        :bright,
        "https://sourceforge.net/projects/win32diskimager/\n",
        :reset
      ])
    )

    IO.puts(
      IO.ANSI.format([
        "\n",
        :cyan,
        "For more information about fwup, visit: ",
        :reset,
        :bright,
        "https://github.com/fwup-home/fwup#installing\n",
        :reset
      ])
    )
  end

  defp print_image_asset_instructions(firmware_path, image_config, target) do
    Output.success("\n✓ Firmware downloaded successfully!\n")

    Output.section("Downloaded Image:\n")
    Output.labeled("File location: ", "#{firmware_path}\n", :cyan)

    print_next_steps(image_config, target)
  end

  defp print_next_steps(image_config, target) do
    case NervesBurner.FirmwareImages.next_steps(image_config, target) do
      nil ->
        :ok

      next_steps ->
        Output.section("\n📋 Next Steps:\n")
        Output.info(String.trim(next_steps) <> "\n")
    end
  end

  defp get_version() do
    :nerves_burner
    |> Application.spec(:vsn)
    |> to_string()
  end
end
