# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule NervesBurner.FirmwareImages do
  @moduledoc """
  Configuration for available firmware images.
  """

  @doc """
  Lists all available firmware images with their configurations.
  """
  def list do
    [
      {"Circuits Quickstart",
       %{
         repo: "elixir-circuits/circuits_quickstart",
         description: "Minimal image for trying out GPIO, I2C, SPI and more",
         long_description: """
         This is a good first image if you'd like to Nerves on a device. It
         sets up networking and an ssh server for remote access to an IEx
         prompt.

         All Elixir Circuits libraries are included for ease of trying out
         hardware programming using I2C, SPI, GPIOs and UARTs. It also serves
         as a known good image when debugging boot and hardware initialization
         problems.
         """,
         url: "https://github.com/elixir-circuits/circuits_quickstart",
         targets: [
           "rpi",
           "rpi0",
           "rpi0_2",
           "rpi2",
           "rpi3",
           "rpi3a",
           "rpi4",
           "rpi5",
           "bbb",
           "osd32mp1",
           "npi_imx6ull",
           "grisp2",
           "mangopi_mq_pro"
         ],
         fw_asset_pattern: fn target -> "circuits_quickstart_#{target}.fw" end,
         image_asset_pattern: fn target -> "circuits_quickstart_#{target}.img.gz" end,
         next_steps: """
         For instructions on using Circuits Quickstart, please visit:
         https://github.com/elixir-circuits/circuits_quickstart?tab=readme-ov-file#testing-the-firmware
         """,
         overrides: %{
           "grisp2" => %{
             use_image_asset: true,
             next_steps: """
             For GRiSP 2 installation instructions, please visit:
             https://github.com/elixir-circuits/circuits_quickstart?tab=readme-ov-file#grisp-2-installation
             """
           }
         }
       }},
      {"Nerves Livebook",
       %{
         repo: "nerves-livebook/nerves_livebook",
         description: "Interactive notebooks for learning Elixir and Nerves",
         long_description: """
         Run Livebook directly on your embedded device for an interactive development or learning experience.

         Includes:

         - Pre-installed notebooks with Nerves examples and tutorials
         - Many Elixir libraries for use in notebooks
         - Support for storing notebooks on device

         Ideal for experimenting with Nerves or building prototypes interactively.
         """,
         url: "https://github.com/nerves-livebook/nerves_livebook",
         targets: [
           "rpi",
           "rpi0",
           "rpi0_2",
           "rpi2",
           "rpi3",
           "rpi3a",
           "rpi4",
           "rpi5",
           "bbb",
           "osd32mp1",
           "npi_imx6ull",
           "grisp2",
           "mangopi_mq_pro"
         ],
         fw_asset_pattern: fn target -> "nerves_livebook_#{target}.fw" end,
         image_asset_pattern: fn target -> "nerves_livebook_#{target}.img.gz" end,
         next_steps: """
         For instructions on getting started, please visit:
         https://github.com/nerves-livebook/nerves_livebook#readme
         """,
         overrides: %{
           "grisp2" => %{
             use_image_asset: true,
             next_steps: """
             For GRiSP 2 installation instructions, please visit:
             https://github.com/nerves-livebook/nerves_livebook?tab=readme-ov-file#grisp-2-installation
             """
           }
         }
       }},
      {"Nerves Web Kiosk Demo",
       %{
         repo: "nerves-web-kiosk/kiosk_demo",
         description: "Kiosk demo using an embedded web browser and Phoenix LiveView",
         long_description: """
         This firmware works on the Raspberry Pi 4 and 5. You'll also need either the
         Raspberry Pi Touch Display 2 or an HDMI display. If using an HDMI display, connect
         a mouse to use the UI. Some HDMI monitors with USB touchscreens work.
         """,
         url: "https://github.com/nerves-web-kiosk/kiosk_demo",
         targets: [
           "rpi4",
           "rpi5"
         ],
         fw_asset_pattern: fn target -> "kiosk_demo_#{target}.fw" end,
         image_asset_pattern: fn target -> "kiosk_demo_#{target}.img.gz" end,
         next_steps: """
         For instructions on getting started, please visit:
         https://github.com/nerves-web-kiosk/kiosk_demo#readme
         """,
         overrides: %{}
       }}
    ]
  end

  @doc """
  Returns a human-friendly display name for a target

  Examples:

      iex> NervesBurner.FirmwareImages.target_display_name("rpi")
      "Raspberry Pi Model B (rpi)"
  """
  @spec target_display_name(String.t()) :: String.t()
  def target_display_name(target) do
    case target do
      "rpi" -> "Raspberry Pi Model B (rpi)"
      "rpi0" -> "Raspberry Pi Zero (rpi0)"
      "rpi0_2" -> "Raspberry Pi Zero 2W in 64-bit mode (rpi0_2)"
      "rpi2" -> "Raspberry Pi 2 (rpi2)"
      "rpi3" -> "Raspberry Pi 3 (rpi3)"
      "rpi3a" -> "Raspberry Pi Zero 2W or 3A in 32-bit mode (rpi3a)"
      "rpi4" -> "Raspberry Pi 4 (rpi4)"
      "rpi5" -> "Raspberry Pi 5 (rpi5)"
      "bbb" -> "Beaglebone Black and other Beaglebone variants (bbb)"
      "osd32mp1" -> "OSD32MP1 (osd32mp1)"
      "npi_imx6ull" -> "NPI i.MX6 ULL (npi_imx6ull)"
      "grisp2" -> "GRiSP 2 (grisp2)"
      "mangopi_mq_pro" -> "MangoPi MQ Pro (mangopi_mq_pro)"
      _ -> target
    end
  end

  @doc """
  Returns the next steps for a given firmware image and target.

  Checks for target-specific next steps in overrides first, then falls back to default.
  Returns nil if no next steps are defined.
  """
  def next_steps(image_config, target) do
    # Check for target overrides first
    case get_target_override(image_config, target) do
      %{next_steps: override_steps} ->
        override_steps

      _ ->
        # Fall back to default next steps
        Map.get(image_config, :next_steps)
    end
  end

  @doc """
  Returns the target-specific override configuration if it exists.
  """
  def get_target_override(image_config, target) do
    case Map.get(image_config, :overrides) do
      nil -> nil
      overrides -> Map.get(overrides, target)
    end
  end
end
