defmodule MossletWeb.OrgIdentityTest do
  @moduledoc """
  Unit coverage for the shared org-scoped ZK identity helpers (Task #225), and
  specifically the chat display-name directory (Task #283) + display-avatar
  directory (Task #277).
  """
  use ExUnit.Case, async: true

  alias MossletWeb.OrgIdentity

  describe "display_name_directory/1 (Task #283)" do
    test "maps non-self members that have a display name ciphertext, by user id" do
      members = [
        %{self?: true, user: %{id: "viewer"}, encrypted_display_name: "ct-self"},
        %{self?: false, user: %{id: "u2"}, encrypted_display_name: "ct-two"},
        %{self?: false, user: %{id: "u3"}, encrypted_display_name: nil},
        %{self?: false, user: %{id: "u4"}, encrypted_display_name: ""}
      ]

      assert OrgIdentity.display_name_directory(members) == %{"u2" => "ct-two"}
    end

    test "is empty for an empty member list" do
      assert OrgIdentity.display_name_directory([]) == %{}
    end

    test "never includes the viewer's own ciphertext (privacy: self shows 'You')" do
      members = [%{self?: true, user: %{id: "viewer"}, encrypted_display_name: "ct-self"}]
      assert OrgIdentity.display_name_directory(members) == %{}
    end
  end

  describe "org_avatar_directory/1 (Task #277)" do
    test "maps non-self members that have an org avatar ciphertext, by user id" do
      members = [
        %{self?: true, user: %{id: "viewer"}, encrypted_org_avatar: "ct-self-avatar"},
        %{self?: false, user: %{id: "u2"}, encrypted_org_avatar: "ct-two-avatar"},
        %{self?: false, user: %{id: "u3"}, encrypted_org_avatar: nil},
        %{self?: false, user: %{id: "u4"}, encrypted_org_avatar: ""}
      ]

      assert OrgIdentity.org_avatar_directory(members) == %{"u2" => "ct-two-avatar"}
    end

    test "is empty for an empty member list" do
      assert OrgIdentity.org_avatar_directory([]) == %{}
    end

    test "never includes the viewer's own org avatar (persona separation)" do
      members = [%{self?: true, user: %{id: "viewer"}, encrypted_org_avatar: "ct-self-avatar"}]
      assert OrgIdentity.org_avatar_directory(members) == %{}
    end

    test "is independent of the display-name directory (avatar set but no name)" do
      members = [
        %{
          self?: false,
          user: %{id: "u2"},
          encrypted_display_name: nil,
          encrypted_org_avatar: "ct-avatar"
        }
      ]

      assert OrgIdentity.org_avatar_directory(members) == %{"u2" => "ct-avatar"}
      assert OrgIdentity.display_name_directory(members) == %{}
    end
  end
end
