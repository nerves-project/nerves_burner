# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule NervesBurner.FirmwareImagesTest do
  use ExUnit.Case
  doctest NervesBurner.FirmwareImages

  describe "list/0" do
    test "returns a list of firmware images" do
      images = NervesBurner.FirmwareImages.list()

      assert is_list(images)
      assert length(images) > 0
    end

    test "each image has a name and config" do
      images = NervesBurner.FirmwareImages.list()

      Enum.each(images, fn {name, config} ->
        assert is_binary(name)
        assert is_map(config)
        assert Map.has_key?(config, :repo)
        assert Map.has_key?(config, :targets)
        assert Map.has_key?(config, :fw_asset_pattern)
        assert Map.has_key?(config, :image_asset_pattern)
        assert Map.has_key?(config, :description)
        assert Map.has_key?(config, :long_description)
        assert Map.has_key?(config, :url)
      end)
    end

    test "includes Circuits Quickstart" do
      images = NervesBurner.FirmwareImages.list()
      names = Enum.map(images, fn {name, _} -> name end)

      assert "Circuits Quickstart" in names
    end

    test "includes Nerves Livebook" do
      images = NervesBurner.FirmwareImages.list()
      names = Enum.map(images, fn {name, _} -> name end)

      assert "Nerves Livebook" in names
    end

    test "each image has valid targets" do
      images = NervesBurner.FirmwareImages.list()

      Enum.each(images, fn {_name, config} ->
        assert is_list(config.targets)
        assert length(config.targets) > 0
        Enum.each(config.targets, &assert(is_binary(&1)))
      end)
    end

    test "includes expected targets" do
      images = NervesBurner.FirmwareImages.list()

      # Raspberry Pi 4 and 5 should be supported everywhere
      expected_targets = [
        "rpi4",
        "rpi5"
      ]

      Enum.each(images, fn {_name, config} ->
        Enum.each(expected_targets, fn target ->
          assert target in config.targets,
                 "Target #{target} should be in the targets list"
        end)
      end)
    end

    test "each image has description and url" do
      images = NervesBurner.FirmwareImages.list()

      Enum.each(images, fn {_name, config} ->
        assert is_binary(config.description)
        assert String.length(config.description) > 0
        assert is_binary(config.long_description)
        assert String.length(config.long_description) > 0
        assert is_binary(config.url)
        assert String.starts_with?(config.url, "https://")
      end)
    end

    test "Circuits Quickstart has proper description and url" do
      images = NervesBurner.FirmwareImages.list()
      {_name, config} = Enum.find(images, fn {name, _} -> name == "Circuits Quickstart" end)

      assert config.description =~ ~r/GPIO|I2C|SPI/i
      assert config.long_description =~ ~r/GPIO|I2C|SPI/i
      assert config.url == "https://github.com/elixir-circuits/circuits_quickstart"
    end

    test "Nerves Livebook has proper description and url" do
      images = NervesBurner.FirmwareImages.list()
      {_name, config} = Enum.find(images, fn {name, _} -> name == "Nerves Livebook" end)

      assert config.description =~ ~r/notebook|learning|Elixir|Nerves/i
      assert config.long_description =~ ~r/Livebook|interactive/i
      assert config.url == "https://github.com/nerves-livebook/nerves_livebook"
    end
  end

  describe "target_name/1" do
    test "returns friendly names for known targets" do
      assert NervesBurner.FirmwareImages.target_display_name("rpi") ==
               "Raspberry Pi Model B (rpi)"

      assert NervesBurner.FirmwareImages.target_display_name("rpi0") ==
               "Raspberry Pi Zero (rpi0)"

      assert NervesBurner.FirmwareImages.target_display_name("rpi0_2") ==
               "Raspberry Pi Zero 2W in 64-bit mode (rpi0_2)"

      assert NervesBurner.FirmwareImages.target_display_name("rpi3a") ==
               "Raspberry Pi Zero 2W or 3A in 32-bit mode (rpi3a)"

      assert NervesBurner.FirmwareImages.target_display_name("bbb") ==
               "Beaglebone Black and other Beaglebone variants (bbb)"

      assert NervesBurner.FirmwareImages.target_display_name("grisp2") ==
               "GRiSP 2 (grisp2)"
    end

    test "returns target code for unknown targets" do
      assert NervesBurner.FirmwareImages.target_display_name("unknown") == "unknown"
    end
  end

  describe "next_steps/2" do
    test "returns nil for image config without next_steps" do
      config = %{repo: "test/test", targets: ["rpi"]}
      assert NervesBurner.FirmwareImages.next_steps(config, "rpi") == nil
    end

    test "returns default next steps when no target-specific steps exist" do
      config = %{
        next_steps: "Default steps here"
      }

      assert NervesBurner.FirmwareImages.next_steps(config, "rpi") == "Default steps here"
    end

    test "returns target-specific next steps when available via overrides" do
      config = %{
        next_steps: "Default steps",
        overrides: %{
          "rpi" => %{
            next_steps: "RPi specific steps"
          }
        }
      }

      assert NervesBurner.FirmwareImages.next_steps(config, "rpi") == "RPi specific steps"
    end

    test "falls back to default when target-specific steps not found in overrides" do
      config = %{
        next_steps: "Default steps",
        overrides: %{
          "rpi" => %{
            next_steps: "RPi specific steps"
          }
        }
      }

      assert NervesBurner.FirmwareImages.next_steps(config, "bbb") == "Default steps"
    end

    test "Circuits Quickstart has next steps defined" do
      images = NervesBurner.FirmwareImages.list()
      {_name, config} = Enum.find(images, fn {name, _} -> name == "Circuits Quickstart" end)

      assert Map.has_key?(config, :next_steps)
      assert is_binary(config.next_steps)
      assert String.length(config.next_steps) > 0
    end

    test "Nerves Livebook has next steps defined" do
      images = NervesBurner.FirmwareImages.list()
      {_name, config} = Enum.find(images, fn {name, _} -> name == "Nerves Livebook" end)

      assert Map.has_key?(config, :next_steps)
      assert is_binary(config.next_steps)
      assert String.length(config.next_steps) > 0
    end

    test "next_steps for Circuits Quickstart returns proper steps for grisp2 target" do
      images = NervesBurner.FirmwareImages.list()
      {_name, config} = Enum.find(images, fn {name, _} -> name == "Circuits Quickstart" end)

      steps = NervesBurner.FirmwareImages.next_steps(config, "grisp2")
      assert is_binary(steps)
      assert steps =~ ~r/GRiSP 2/i
    end

    test "next_steps for Circuits Quickstart falls back to default for targets without specific steps" do
      images = NervesBurner.FirmwareImages.list()
      {_name, config} = Enum.find(images, fn {name, _} -> name == "Circuits Quickstart" end)

      steps = NervesBurner.FirmwareImages.next_steps(config, "bbb")
      assert is_binary(steps)
      assert steps == config.next_steps
    end

    test "next_steps for Nerves Livebook returns default steps" do
      images = NervesBurner.FirmwareImages.list()
      {_name, config} = Enum.find(images, fn {name, _} -> name == "Nerves Livebook" end)

      steps = NervesBurner.FirmwareImages.next_steps(config, "rpi4")
      assert is_binary(steps)
      assert steps =~ ~r/nerves-livebook\/nerves_livebook/i
    end
  end

  describe "get_target_override/2" do
    test "returns nil when no overrides exist" do
      config = %{repo: "test/test", targets: ["rpi"]}
      assert NervesBurner.FirmwareImages.get_target_override(config, "rpi") == nil
    end

    test "returns nil when target not in overrides" do
      config = %{
        overrides: %{
          "rpi" => %{use_image_asset: true}
        }
      }

      assert NervesBurner.FirmwareImages.get_target_override(config, "bbb") == nil
    end

    test "returns override config when target exists" do
      config = %{
        overrides: %{
          "rpi" => %{use_image_asset: true, next_steps: "RPi steps"}
        }
      }

      override = NervesBurner.FirmwareImages.get_target_override(config, "rpi")
      assert override == %{use_image_asset: true, next_steps: "RPi steps"}
    end

    test "grisp2 has override defined" do
      images = NervesBurner.FirmwareImages.list()
      {_name, config} = Enum.find(images, fn {name, _} -> name == "Circuits Quickstart" end)

      override = NervesBurner.FirmwareImages.get_target_override(config, "grisp2")
      assert override != nil
      assert override.use_image_asset == true
      assert is_binary(override.next_steps)
    end
  end
end
