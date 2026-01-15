defmodule Mix.Tasks.Mobile.Build do
  @moduledoc """
  Build Mosslet mobile apps for iOS and/or Android.

  ## Usage

      mix mobile.build [platform] [options]

  ## Platforms

    * `ios` - Build for iOS only
    * `android` - Build for Android only
    * `all` - Build for both platforms (default)

  ## Options

    * `--release` - Build release version (default: debug)
    * `--skip-otp` - Skip OTP build check (use cached)
    * `--otp-dir` - Path to otp_build repo (default: ~/otp_build)

  ## Examples

      # Build both platforms (debug)
      mix mobile.build

      # Build iOS release
      mix mobile.build ios --release

      # Build Android with custom OTP path
      mix mobile.build android --otp-dir /path/to/otp_build

  ## Prerequisites

  First time setup requires cloning the OTP build tools:

      git clone https://github.com/nickvander/otp_build ~/otp_build

  The task will prompt you if not found.
  """
  use Mix.Task

  @shortdoc "Build mobile apps for iOS and/or Android"

  @otp_build_repo "https://github.com/nickvander/otp_build"

  def run(args) do
    {opts, platform, _} =
      OptionParser.parse(args,
        switches: [release: :boolean, skip_otp: :boolean, otp_dir: :string],
        aliases: [r: :release]
      )

    platform = List.first(platform) || "all"
    otp_dir = opts[:otp_dir] || Path.expand("~/otp_build")
    release? = opts[:release] || false

    Mix.shell().info([:green, "🔨 Mosslet Mobile Build", :reset])
    Mix.shell().info("Platform: #{platform}")
    Mix.shell().info("Build type: #{if release?, do: "release", else: "debug"}")
    Mix.shell().info("")

    unless opts[:skip_otp] do
      ensure_otp_build(otp_dir, platform)
    end

    build_elixir_release()

    case platform do
      "ios" ->
        build_ios(otp_dir, release?)

      "android" ->
        build_android(otp_dir, release?)

      "all" ->
        build_ios(otp_dir, release?)
        build_android(otp_dir, release?)

      _ ->
        Mix.raise("Unknown platform: #{platform}. Use ios, android, or all.")
    end

    Mix.shell().info("")
    Mix.shell().info([:green, "✅ Build complete!", :reset])
  end

  defp ensure_otp_build(otp_dir, platform) do
    unless File.dir?(otp_dir) do
      Mix.shell().info([:yellow, "⚠️  OTP build tools not found at #{otp_dir}", :reset])
      Mix.shell().info("")

      if Mix.shell().yes?("Clone otp_build repository now?") do
        Mix.shell().info("Cloning #{@otp_build_repo}...")

        case System.cmd("git", ["clone", @otp_build_repo, otp_dir]) do
          {_, 0} -> Mix.shell().info([:green, "✓ Cloned successfully", :reset])
          {error, _} -> Mix.raise("Failed to clone: #{error}")
        end
      else
        Mix.raise("""
        OTP build tools required. Clone manually:

            git clone #{@otp_build_repo} #{otp_dir}
        """)
      end
    end

    case platform do
      "ios" ->
        ensure_ios_otp(otp_dir)

      "android" ->
        ensure_android_otp(otp_dir)

      "all" ->
        ensure_ios_otp(otp_dir)
        ensure_android_otp(otp_dir)
    end
  end

  defp ensure_ios_otp(otp_dir) do
    framework_path = Path.join([otp_dir, "build", "ios", "OTP.xcframework"])

    unless File.dir?(framework_path) do
      Mix.shell().info([
        :yellow,
        "Building OTP for iOS (this takes 15-30 minutes first time)...",
        :reset
      ])

      case System.cmd("./build_ios.sh", [], cd: otp_dir, into: IO.stream(:stdio, :line)) do
        {_, 0} -> Mix.shell().info([:green, "✓ iOS OTP built", :reset])
        {_, code} -> Mix.raise("iOS OTP build failed with code #{code}")
      end
    else
      Mix.shell().info([:green, "✓ iOS OTP framework found", :reset])
    end
  end

  defp ensure_android_otp(otp_dir) do
    jnilib_path = Path.join([otp_dir, "build", "android", "jniLibs", "arm64-v8a"])

    unless File.dir?(jnilib_path) do
      Mix.shell().info([
        :yellow,
        "Building OTP for Android (this takes 15-30 minutes first time)...",
        :reset
      ])

      ndk_home = System.get_env("ANDROID_NDK_HOME") || find_android_ndk()

      if ndk_home do
        System.put_env("ANDROID_NDK_HOME", ndk_home)
      end

      case System.cmd("./build_android.sh", [], cd: otp_dir, into: IO.stream(:stdio, :line)) do
        {_, 0} -> Mix.shell().info([:green, "✓ Android OTP built", :reset])
        {_, code} -> Mix.raise("Android OTP build failed with code #{code}")
      end
    else
      Mix.shell().info([:green, "✓ Android OTP libraries found", :reset])
    end
  end

  defp find_android_ndk do
    sdk_path = System.get_env("ANDROID_HOME") || Path.expand("~/Library/Android/sdk")
    ndk_base = Path.join(sdk_path, "ndk")

    if File.dir?(ndk_base) do
      case File.ls(ndk_base) do
        {:ok, versions} when versions != [] ->
          latest = versions |> Enum.sort() |> List.last()
          Path.join(ndk_base, latest)

        _ ->
          nil
      end
    end
  end

  defp build_elixir_release do
    Mix.shell().info("")
    Mix.shell().info([:cyan, "📦 Building Elixir release...", :reset])

    System.put_env("MIX_TARGET", "native")
    System.put_env("MIX_ENV", "prod")

    Mix.Task.run("deps.get", [])
    Mix.Task.run("compile", [])
    Mix.Task.run("assets.deploy", [])
    Mix.Task.run("release", ["mobile", "--overwrite"])

    Mix.shell().info([:green, "✓ Elixir release built", :reset])
  end

  defp build_ios(otp_dir, _release?) do
    Mix.shell().info("")
    Mix.shell().info([:cyan, "🍎 Building iOS app...", :reset])

    project_root = File.cwd!()
    ios_dir = Path.join(project_root, "native/ios")
    frameworks_dir = Path.join(ios_dir, "Frameworks")

    File.mkdir_p!(frameworks_dir)
    otp_framework = Path.join([otp_dir, "build", "ios", "OTP.xcframework"])

    if File.dir?(otp_framework) do
      dest = Path.join(frameworks_dir, "OTP.xcframework")
      File.rm_rf!(dest)
      File.cp_r!(otp_framework, dest)
      Mix.shell().info("✓ Copied OTP framework")
    end

    case System.cmd("./scripts/package_ios.sh", [],
           cd: project_root,
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} -> :ok
      {_, code} -> Mix.raise("iOS packaging failed with code #{code}")
    end

    Mix.shell().info([:green, "✓ iOS build complete", :reset])
    Mix.shell().info("  Open native/ios/Mosslet.xcodeproj in Xcode to run")
  end

  defp build_android(otp_dir, release?) do
    Mix.shell().info("")
    Mix.shell().info([:cyan, "🤖 Building Android app...", :reset])

    project_root = File.cwd!()
    android_dir = Path.join(project_root, "native/android")
    jnilib_dir = Path.join([android_dir, "app", "src", "main", "jniLibs"])

    File.mkdir_p!(jnilib_dir)
    otp_jnilib = Path.join([otp_dir, "build", "android", "jniLibs"])

    if File.dir?(otp_jnilib) do
      for abi <- ["arm64-v8a", "armeabi-v7a", "x86_64"] do
        src = Path.join(otp_jnilib, abi)

        if File.dir?(src) do
          dest = Path.join(jnilib_dir, abi)
          File.mkdir_p!(dest)
          File.cp_r!(src, dest)
        end
      end

      Mix.shell().info("✓ Copied OTP native libraries")
    end

    case System.cmd("./scripts/package_android.sh", [],
           cd: project_root,
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} -> :ok
      {_, code} -> Mix.raise("Android packaging failed with code #{code}")
    end

    gradle_task = if release?, do: "bundleRelease", else: "assembleDebug"

    Mix.shell().info("Running Gradle #{gradle_task}...")

    case System.cmd("./gradlew", [gradle_task], cd: android_dir, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        Mix.shell().info([:green, "✓ Android build complete", :reset])

        if release? do
          Mix.shell().info(
            "  AAB: native/android/app/build/outputs/bundle/release/app-release.aab"
          )
        else
          Mix.shell().info("  APK: native/android/app/build/outputs/apk/debug/app-debug.apk")
        end

      {_, code} ->
        Mix.raise("Gradle build failed with code #{code}")
    end
  end
end
