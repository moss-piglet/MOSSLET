defmodule Mix.Tasks.MetamorphicCrypto.CheckWasm do
  @shortdoc "Check vendor WASM integrity and for newer metamorphic-crypto releases"
  @moduledoc """
  Verifies local vendor WASM integrity and checks for newer releases.

  Checks:
    1. Local SHA-512 integrity — vendor files match their SHA512SUMS
    2. Version comparison — is a newer release available on GitHub?

  ## Usage

      mix metamorphic_crypto.check_wasm          # check against latest release
      mix metamorphic_crypto.check_wasm v0.4.0   # check against a specific version
  """

  use Mix.Task

  @repo "moss-piglet/metamorphic-crypto"
  @vendor_dir "assets/vendor/metamorphic-crypto"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    target_tag = List.first(args)

    with :ok <- check_local_integrity(),
         {:ok, local_version} <- read_local_version(),
         {:ok, latest_tag} <- fetch_latest_tag(target_tag) do
      if local_version == latest_tag do
        Mix.shell().info([:green, "OK — vendor intact, up-to-date with #{latest_tag}"])
      else
        Mix.shell().info([:yellow, "Update available: #{local_version} -> #{latest_tag}"])
        Mix.shell().info("  Run: update-wasm.sh #{latest_tag}")
      end
    else
      {:local_mismatch, file} ->
        Mix.shell().error("Integrity FAILED: #{file} does not match SHA512SUMS")
        Mix.shell().error("Re-run update-wasm.sh to restore artifacts")
        exit({:shutdown, 1})

      {:no_local_checksums} ->
        Mix.shell().error("No SHA512SUMS found in #{@vendor_dir}/")
        Mix.shell().error("Run update-wasm.sh to vendor artifacts with checksums")
        exit({:shutdown, 1})

      {:no_local_version} ->
        Mix.shell().error("No VERSION file in #{@vendor_dir}/")
        Mix.shell().error("Run update-wasm.sh to vendor artifacts")
        exit({:shutdown, 1})

      {:error, reason} ->
        Mix.shell().error("Remote check failed: #{reason}")
        exit({:shutdown, 1})
    end
  end

  defp check_local_integrity do
    sums_path = Path.join(@vendor_dir, "SHA512SUMS")

    if File.exists?(sums_path) do
      sums_path
      |> File.read!()
      |> String.trim()
      |> String.split("\n")
      |> Enum.reduce_while(:ok, fn line, :ok ->
        [expected, filename] = String.split(line, ~r/\s+/, parts: 2)
        filename = String.trim(filename)
        path = Path.join(@vendor_dir, filename)

        cond do
          not File.exists?(path) ->
            {:halt, {:local_mismatch, filename}}

          sha512_hex(File.read!(path)) != expected ->
            {:halt, {:local_mismatch, filename}}

          true ->
            Mix.shell().info("  #{filename}: OK")
            {:cont, :ok}
        end
      end)
    else
      {:no_local_checksums}
    end
  end

  defp read_local_version do
    version_path = Path.join(@vendor_dir, "VERSION")

    if File.exists?(version_path) do
      {:ok, version_path |> File.read!() |> String.trim()}
    else
      {:no_local_version}
    end
  end

  defp fetch_latest_tag(nil) do
    fetch_tag_from("https://api.github.com/repos/#{@repo}/releases/latest")
  end

  defp fetch_latest_tag(tag), do: {:ok, tag}

  defp fetch_tag_from(url) do
    case Req.get(url, headers: [{"accept", "application/vnd.github+json"}]) do
      {:ok, %{status: 200, body: %{"tag_name" => tag}}} ->
        {:ok, tag}

      {:ok, %{status: status}} ->
        {:error, "GitHub API returned #{status}"}

      {:error, err} ->
        {:error, inspect(err)}
    end
  end

  defp sha512_hex(data) do
    :crypto.hash(:sha512, data) |> Base.encode16(case: :lower)
  end
end
