defmodule MossletWeb.WellKnownController do
  use MossletWeb, :controller

  @apple_app_id "TEAM_ID.com.mosslet.app"
  @android_package "com.mosslet.app"
  @android_sha256_fingerprint "SHA256_FINGERPRINT"

  def apple_app_site_association(conn, _params) do
    association = %{
      applinks: %{
        apps: [],
        details: [
          %{
            appID: @apple_app_id,
            paths: [
              "/app/*",
              "/profile/*",
              "/invite/*",
              "/group/*",
              "/post/*",
              "/users/settings/confirm-email/*"
            ]
          }
        ]
      },
      webcredentials: %{
        apps: [@apple_app_id]
      }
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(association))
  end

  def assetlinks(conn, _params) do
    links = [
      %{
        relation: ["delegate_permission/common.handle_all_urls"],
        target: %{
          namespace: "android_app",
          package_name: @android_package,
          sha256_cert_fingerprints: [@android_sha256_fingerprint]
        }
      }
    ]

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(links))
  end
end
