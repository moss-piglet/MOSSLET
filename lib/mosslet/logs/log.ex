defmodule Mosslet.Logs.Log do
  @moduledoc false
  use Mosslet.Schema

  @user_type_options ["user", "admin"]
  @action_options [
    "update_profile",
    "register",
    "sign_in",
    "passwordless_pin_sent",
    "passwordless_pin_too_many_incorrect_attempts",
    "passwordless_pin_expired",
    "sign_out",
    "confirm_email",
    "request_new_email",
    "confirm_new_email",
    "delete_user",
    "impersonate_user",
    "restore_impersonator",
    "orgs.create",
    "orgs.delete_member",
    "orgs.update_member",
    "orgs.create_invitation",
    "orgs.delete_invitation",
    "orgs.accept_invitation",
    "orgs.reject_invitation",
    "billing.click_subscribe_button",
    "billing.subscribe_subscription",
    "billing.over_charge",
    "billing.renew_subscription",
    "billing.cancel_subscription",
    "billing.update_subscription",
    "billing.more_than_one_active_subscription_warning",
    "totp.enable",
    "totp.update",
    "totp.disable",
    "totp.regenerate_backup_codes",
    "totp.validate",
    "totp.validate_with_backup_code",
    "totp.invalid_code_used"
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
