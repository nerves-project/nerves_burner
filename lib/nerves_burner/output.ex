# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule NervesBurner.Output do
  @moduledoc """
  Helper functions for formatted console output with ANSI colors.
  """

  @doc """
  Prints a section header (cyan, bright).
  """
  @spec section(String.t()) :: :ok
  def section(message) do
    IO.puts(IO.ANSI.format([:cyan, :bright, message, :reset]))
  end

  @doc """
  Prints a success message (green, bright).
  """
  @spec success(String.t()) :: :ok
  def success(message) do
    IO.puts(IO.ANSI.format([:green, :bright, message, :reset]))
  end

  @doc """
  Prints an info message (cyan).
  """
  @spec info(String.t()) :: :ok
  def info(message) do
    IO.puts(IO.ANSI.format([:cyan, message, :reset]))
  end

  @doc """
  Prints a warning message (yellow).
  """
  @spec warning(String.t()) :: :ok
  def warning(message) do
    IO.puts(IO.ANSI.format([:yellow, message, :reset]))
  end

  @doc """
  Prints an error message (red, bright).
  """
  @spec error(String.t()) :: :ok
  def error(message) do
    IO.puts(IO.ANSI.format([:red, :bright, message, :reset]))
  end

  @doc """
  Prints a menu option with a number (yellow number, normal text).
  """
  @spec menu_option(integer() | String.t(), String.t()) :: :ok
  def menu_option(number, text) do
    IO.puts(IO.ANSI.format(["  ", :yellow, "#{number}.", :reset, " #{text}"]))
  end

  @doc """
  Prints a menu option with formatted components.
  """
  @spec menu_option_with_parts(integer(), String.t(), String.t() | nil) :: :ok
  def menu_option_with_parts(number, main_text, secondary_text) do
    IO.puts(
      IO.ANSI.format([
        "  ",
        :yellow,
        "#{number}.",
        :reset,
        " ",
        :bright,
        main_text,
        :reset
      ])
    )

    if secondary_text do
      IO.puts(IO.ANSI.format(["     ", :faint, secondary_text, :reset]))
    end

    :ok
  end

  @doc """
  Prints a prompt and returns formatted prompt for IO.gets/1.
  """
  @spec prompt(String.t()) :: IO.ANSI.ansidata()
  def prompt(message) do
    IO.ANSI.format([:green, message, :reset])
  end

  @doc """
  Prints a critical warning (red, bright with warning symbol).
  """
  @spec critical_warning(String.t()) :: :ok
  def critical_warning(message) do
    IO.puts(IO.ANSI.format([:red, :bright, "⚠️  WARNING: ", :reset, :red, message, :reset]))
  end

  @doc """
  Prints formatted text with a label and value.
  """
  @spec labeled(String.t(), String.t(), atom()) :: :ok
  def labeled(label, value, label_color \\ :cyan) do
    IO.puts(IO.ANSI.format([label_color, label, :reset, :bright, value, :reset]))
  end
end
