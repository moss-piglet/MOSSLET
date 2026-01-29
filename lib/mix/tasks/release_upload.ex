defmodule Mix.Tasks.Release.Upload do
  @moduledoc """
  Uploads desktop release artifacts to Tigris object storage.

  ## Usage

      # Upload all artifacts from _build/desktop for version in mix.exs
      mix release.upload

      # Upload all artifacts for a specific version
      mix release.upload --version 0.17.0

      # Upload from a custom directory
      mix release.upload --version 0.17.0 --dir /path/to/artifacts

      # Upload a single file
      mix release.upload --version 0.17.0 --file Mosslet-0.17.0-macos.dmg

  ## Environment Variables

  Requires the following environment variables (same as your Tigris setup):

    * `RELEASES_BUCKET` - Tigris bucket for releases
    * `AWS_ACCESS_KEY_ID` - Access key
    * `AWS_SECRET_ACCESS_KEY` - Secret key
    * `AWS_REGION` - Region (usually "auto" for Tigris)
    * `AWS_HOST` - Host (e.g., "fly.storage.tigris.dev")

  ## Creating the Tigris Bucket

  Run this command to create a public releases bucket on Fly.io:

      fly storage create --name mosslet-releases --public

  Then set the RELEASES_BUCKET secret:

      fly secrets set RELEASES_BUCKET=mosslet-releases
  """
  use Mix.Task

  @shortdoc "Uploads release artifacts to Tigris storage"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [version: :string, dir: :string, file: :string],
        aliases: [v: :version, d: :dir, f: :file]
      )

    version = opts[:version] || get_app_version()
    dir = opts[:dir] || "_build/desktop"
    file = opts[:file]

    IO.puts("\n📦 MOSSLET Release Upload")
    IO.puts("   Version: #{version}")
    IO.puts("   Bucket: #{System.get_env("RELEASES_BUCKET")}")
    IO.puts("")

    if file do
      upload_single(version, dir, file)
    else
      upload_all(version, dir)
    end
  end

  defp upload_single(version, dir, filename) do
    file_path = Path.join(dir, filename)

    if File.exists?(file_path) do
      IO.puts("⬆️  Uploading #{filename}...")

      case Mosslet.Releases.Storage.upload(version, file_path) do
        {:ok, url} ->
          IO.puts("✅ #{filename}")
          IO.puts("   #{url}")

        {:error, reason} ->
          IO.puts("❌ #{filename}: #{inspect(reason)}")
      end
    else
      IO.puts("❌ File not found: #{file_path}")
    end
  end

  defp upload_all(version, dir) do
    if File.dir?(dir) do
      IO.puts("⬆️  Uploading all artifacts from #{dir}...\n")

      results = Mosslet.Releases.Storage.upload_all(version, dir)

      if results == [] do
        IO.puts("⚠️  No release artifacts found in #{dir}")
        IO.puts("   Run ./scripts/build_desktop.sh first")
      else
        IO.puts("")

        Enum.each(results, fn {filename, result} ->
          case result do
            {:ok, url} ->
              IO.puts("✅ #{filename}")
              IO.puts("   #{url}")

            {:error, reason} ->
              IO.puts("❌ #{filename}: #{inspect(reason)}")
          end

          IO.puts("")
        end)

        success_count = Enum.count(results, fn {_, r} -> match?({:ok, _}, r) end)
        IO.puts("📊 Uploaded #{success_count}/#{length(results)} files")
      end
    else
      IO.puts("❌ Directory not found: #{dir}")
      IO.puts("   Run ./scripts/build_desktop.sh first")
    end
  end

  defp get_app_version do
    Mix.Project.config()[:version]
  end
end
