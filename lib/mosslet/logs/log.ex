defmodule Mosslet.Logs.Log do
  @moduledoc false
  use Mosslet.Schema

  @user_type_options ["user", "admin"]
  @action_options [
    # Essential security logging only
    "sign_in",
    "totp.enable",
    "totp.disable",
    "totp.invalid_code_used",
    "impersonate_user",
    "restore_impersonator",

    # Org actions (if needed for security)
    "orgs.create",
    "orgs.delete_member",
    "orgs.update_member",
    "orgs.create_invitation",
    "orgs.delete_invitation",
    "orgs.accept_invitation",
    "orgs.reject_invitation",

    # User management (admin actions)
    "delete_user"
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "logs" do
    field :action, :string
    field :user_type, :string, default: "user"
    field :metadata, :map, default: %{}

    belongs_to :user, Mosslet.Accounts.User
    belongs_to :target_user, Mosslet.Accounts.User
    belongs_to :org, Mosslet.Orgs.Org

    belongs_to :customer, Mosslet.Billing.Customers.Customer,
      foreign_key: :billing_customer_id,
      type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [
      :action,
      :user_type,
      :user_id,
      :org_id,
      :billing_customer_id,
      :target_user_id,
      :inserted_at,
      :metadata
    ])
    |> validate_required([
      :action,
      :user_type,
      :user_id
    ])
    |> validate_inclusion(:action, @action_options)
    |> validate_inclusion(:user_type, @user_type_options)
  end

  def action_options, do: @action_options
end
