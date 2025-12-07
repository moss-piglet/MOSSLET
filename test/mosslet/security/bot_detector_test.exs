defmodule Mosslet.Security.BotDetectorTest do
  use ExUnit.Case, async: true

  alias Mosslet.Security.BotDetector

  describe "bad_bot?/1" do
    test "detects known bad bots" do
      assert BotDetector.bad_bot?("Mozilla/5.0 (compatible; AhrefsBot/7.0)")
      assert BotDetector.bad_bot?("Mozilla/5.0 (compatible; GPTBot/1.0)")
      assert BotDetector.bad_bot?("Mozilla/5.0 (compatible; SemrushBot/7.0)")
      assert BotDetector.bad_bot?("ClaudeBot/1.0")
      assert BotDetector.bad_bot?("Bytespider")
    end

    test "allows legitimate user agents" do
      refute BotDetector.bad_bot?("Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0")
      refute BotDetector.bad_bot?("Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)")

      refute BotDetector.bad_bot?(
               "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/605.1.15"
             )
    end

    test "handles nil user agent" do
      refute BotDetector.bad_bot?(nil)
    end

    test "is case insensitive" do
      assert BotDetector.bad_bot?("AHREFSBOT")
      assert BotDetector.bad_bot?("gptbot")
      assert BotDetector.bad_bot?("GptBot")
    end
  end

  describe "suspicious_path?/1" do
    test "detects path traversal attempts" do
      assert BotDetector.suspicious_path?("/../etc/passwd")
      assert BotDetector.suspicious_path?("/app/..\\..\\windows\\system32")
    end

    test "detects SQL injection attempts" do
      assert BotDetector.suspicious_path?("/users?id=1 UNION SELECT * FROM users")
      assert BotDetector.suspicious_path?("/search?q=admin' UNION SELECT password FROM users--")
    end

    test "detects common scan targets" do
      assert BotDetector.suspicious_path?("/wp-admin/login.php")
      assert BotDetector.suspicious_path?("/.env")
      assert BotDetector.suspicious_path?("/.git/config")
      assert BotDetector.suspicious_path?("/phpmyadmin")
    end

    test "allows normal paths" do
      refute BotDetector.suspicious_path?("/")
      refute BotDetector.suspicious_path?("/app/timeline")
      refute BotDetector.suspicious_path?("/auth/log_in")
      refute BotDetector.suspicious_path?("/users/settings")
    end
  end
end
