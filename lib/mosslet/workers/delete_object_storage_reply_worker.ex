defmodule Mosslet.Workers.DeleteObjectStorageReplyWorker do
  @moduledoc """
  Oban job for deleting Reply files from object storage.
  Currently, these will be images from Trix.
  """
  use Oban.Worker,
    max_attempts: 3,
    queue: :storage

  use MossletWeb, :verified_routes
  import Ecto.Query, warn: false

  require Logger

  alias Mosslet.Encrypted

  @doc """
  This handles deleting all Reply images from the cloud.
  """
  def perform(%Oban.Job{
        args: %{
          "urls" => urls
        }
      }) do
    case make_async_aws_requests(urls) do
      result ->
        Logger.info("DeleteObjectStorageReplyWorker make_async_aws_resquests")
        Logger.debug(inspect(result))
        Logger.info(result)
    end
  end

  ## Object storage requests

  # urls should already be mapped correctly
  defp make_async_aws_requests(urls) when is_list(urls) do
    memories_bucket = Encrypted.Session.memories_bucket()

    # break the urls into chunks of 1,000
    url_chunks = Enum.chunk_every(urls, 1_000)

    for chunk <- url_chunks do
      ex_aws_delete_multiple_objects_request(memories_bucket, chunk)
    end
  end

  # Supports deleting up to 1,000 objects at a time.
  defp ex_aws_delete_multiple_objects_request(memories_bucket, urls) do
    ExAws.S3.delete_multiple_objects(memories_bucket, urls)
    |> ExAws.request()
  end
end
