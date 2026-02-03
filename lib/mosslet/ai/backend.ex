defmodule Mosslet.AI.Backend do
  @moduledoc """
  Abstracts the Nx backend and compiler selection.

  Uses EXLA on macOS/Linux (where precompiled binaries exist) and
  Torchx on Windows.
  """

  @doc """
  Returns the appropriate defn compiler options for Bumblebee servings.
  """
  def defn_options do
    [compiler: compiler()]
  end

  @doc """
  Returns the compiler module to use for Nx defn.
  """
  def compiler do
    case os_type() do
      :windows -> Torchx
      _ -> EXLA
    end
  end

  @doc """
  Returns the default backend configuration for Nx.
  """
  def default_backend do
    case os_type() do
      :windows -> Torchx.Backend
      _ -> {EXLA.Backend, client: :host}
    end
  end

  @doc """
  Returns true if running on Windows.
  """
  def windows? do
    os_type() == :windows
  end

  defp os_type do
    case :os.type() do
      {:win32, _} -> :windows
      _ -> :unix
    end
  end
end
