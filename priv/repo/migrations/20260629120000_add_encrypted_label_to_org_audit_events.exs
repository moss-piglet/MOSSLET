defmodule Mosslet.Repo.Migrations.AddEncryptedLabelToOrgAuditEvents do
  use Ecto.Migration

  # Richer ZK audit log (Task #353): attach an OPAQUE, browser-supplied label to
  # each audit event so the activity feed can name WHICH circle was
  # created/updated/deleted (and enrich other actions) while preserving
  # zero-knowledge.
  #
  # The label is the circle name re-encrypted by the ACTOR's browser under the
  # per-org `org_key` (the same key the audit panel already holds to resolve
  # member display names). The server stores only the resulting ciphertext — it
  # can never read it (invariant I6). Only org members/admins (who hold the
  # org_key) can decrypt it client-side.
  #
  # NOT Cloak/Encrypted.Binary: the value is ALREADY org_key-sealed by the
  # browser, so wrapping it again buys nothing. We store the base64 ciphertext
  # opaquely as text. Nullable — most existing/legacy events have no label, and
  # actions whose actor can't compute one (e.g. WASM unavailable) simply fall
  # back to the generic server-side label in the UI.
  def change do
    alter table(:org_audit_events) do
      add :encrypted_label, :text
    end
  end
end
