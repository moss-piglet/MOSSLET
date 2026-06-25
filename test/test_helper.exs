# Provide a deterministic, hermetic server X25519 keypair for the test suite so
# tests that seal data to the server public key (e.g. server-side decrypt of a
# :public profile) do not depend on real `SERVER_PUBLIC_KEY` / `SERVER_PRIVATE_KEY`
# secrets. CI passes unset secrets through as empty strings, which made
# `System.fetch_env!/1` return "" (0 bytes) and crash box_seal. We only fill in a
# value when the var is missing or blank, so local/CI environments that DO set
# real keys keep theirs. This pair is a valid, matching X25519 keypair generated
# via MetamorphicCrypto.generate_keypair/0 (round-trips seal/open).
test_server_keypair = %{
  "SERVER_PUBLIC_KEY" => "dCRyAKMRmCIoHrOKZQTQGzi6HZQMuvZPtmib9y462Fo=",
  "SERVER_PRIVATE_KEY" => "3XX0htxxyh/7mX4iqnV4TwcU/BD3odwfXzfy8jmvIE4="
}

for {key, value} <- test_server_keypair, System.get_env(key) in [nil, ""] do
  System.put_env(key, value)
end

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Mosslet.Repo, :manual)
