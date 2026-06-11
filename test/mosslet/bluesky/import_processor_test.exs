defmodule Mosslet.Bluesky.ImportProcessorTest do
  use ExUnit.Case, async: true

  alias Mosslet.Bluesky.ImportProcessor

  describe "process_post/2 quote handling" do
    test "appends a quote attribution link for embed.record quote posts" do
      uri = "at://did:plc:abc123/app.bsky.feed.post/3kqz"

      post_data = %{
        record: %{
          text: "Great point",
          embed: %{
            "$type": "app.bsky.embed.record",
            record: %{uri: uri, cid: "bafycid"}
          }
        }
      }

      assert {:ok, processed} = ImportProcessor.process_post(post_data, visibility: :private)

      assert processed.quote_url == "https://bsky.app/profile/did:plc:abc123/post/3kqz"
      assert processed.text =~ "Great point"
      assert processed.text =~ "Quoting https://bsky.app/profile/did:plc:abc123/post/3kqz"
    end

    test "handles recordWithMedia by reading the nested quoted record uri" do
      uri = "at://did:plc:xyz/app.bsky.feed.post/3abc"

      post_data = %{
        record: %{
          text: "look at this",
          embed: %{
            "$type": "app.bsky.embed.recordWithMedia",
            record: %{record: %{uri: uri, cid: "bafy2"}},
            media: %{images: []}
          }
        }
      }

      assert {:ok, processed} = ImportProcessor.process_post(post_data, visibility: :private)
      assert processed.quote_url == "https://bsky.app/profile/did:plc:xyz/post/3abc"
      assert processed.text =~ "look at this"
    end

    test "leaves text untouched when there is no quote embed" do
      post_data = %{record: %{text: "just a normal post"}}

      assert {:ok, processed} = ImportProcessor.process_post(post_data, visibility: :private)
      assert processed.quote_url == nil
      assert processed.text == "just a normal post"
    end

    test "uses the quote link as body when the post has no text" do
      uri = "at://did:plc:q/app.bsky.feed.post/3only"

      post_data = %{
        record: %{
          text: "",
          embed: %{record: %{uri: uri, cid: "c"}}
        }
      }

      assert {:ok, processed} = ImportProcessor.process_post(post_data, visibility: :private)
      assert processed.text == "↪ Quoting https://bsky.app/profile/did:plc:q/post/3only"
    end
  end
end
