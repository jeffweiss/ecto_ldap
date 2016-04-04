defmodule EctoLdapTest do
  alias Ecto.Ldap.TestRepo
  alias Ecto.Ldap.TestUser
  require Ecto.Query
  use ExUnit.Case
  doctest Ecto.Ldap.Adapter

  test "retrieve model by id/dn" do
    dn = "uid=jeff.weiss,ou=users,dc=example,dc=com"
    user = TestRepo.get TestUser, dn
    assert user != nil
    assert user.dn == dn
  end

  test "retrieve by unknown dn returns nil" do
    dn = "uid=unknown,ou=users,dc=example,dc=com"
    assert(TestRepo.get(TestUser, dn) == nil)
  end

  test "model fields not in ldap attributes are nil" do
    user = TestRepo.get TestUser, "uid=jeff.weiss,ou=users,dc=example,dc=com"
    assert user.mobile == nil
  end

  test "model fields with multiple ldap values return the first one" do
    user = TestRepo.get(TestUser, "uid=jeff.weiss,ou=users,dc=example,dc=com")
    assert user.mail == "jeff.weiss@example.com"
  end

  test "model fields which are arrays return all ldap values" do
    user = TestRepo.get(TestUser, "uid=jeff.weiss,ou=users,dc=example,dc=com")
    assert Enum.count(user.objectClass) > 1
  end

  test "get_by with criteria" do
    user = TestRepo.get_by TestUser, uid: "jeff.weiss"
    assert user != nil
  end

  test "all returns both users from our sandbox" do
    users = TestRepo.all TestUser
    assert Enum.count(users) == 2
  end

  test "all with criteria" do
    users = TestRepo.all TestUser, uid: "jeff.weiss"
    assert Enum.count(users) == 1
  end

  @update_examples [
    %{"loginShell" => nil},
    %{"loginShell" => "/bin/zsh"},
    %{"skills" => nil},
    %{"skills" => ["nunchucks", "bow staff", "katanas", "sais"]},
  ]

  for params <- @update_examples do
    quote do
      test "update #{unquote(inspect params)}" do
        attr  = unquote(params |> Map.keys   |> List.first)
        value = unquote(params |> Map.values |> List.first)
        TestUser
        |> TestRepo.get("uid=manny,ou=users,dc=example,dc=com")
        |> TestUser.changeset(unquote(params))
        |> TestRepo.update

        updated_user = TestRepo.get(TestUser, "uid=manny,ou=users,dc=example,dc=com")

        assert Map.get(updated_user, attr |> String.to_atom) == value
      end
    end
  end

  test "update with empty list comes back nil" do
    TestUser
    |> TestRepo.get("uid=manny,ou=users,dc=example,dc=com")
    |> TestUser.changeset(%{"skills" => []})
    |> TestRepo.update

    updated_user = TestRepo.get(TestUser, "uid=manny,ou=users,dc=example,dc=com")
    assert updated_user.skills == nil
  end

  test "update multiple attributes at once" do
    surname = "Batulo"
    mail = "manny@example.co.uk"

    TestUser
    |> TestRepo.get("uid=manny,ou=users,dc=example,dc=com")
    |> TestUser.changeset(%{"sn" => surname, "mail" => mail})
    |> TestRepo.update

    updated_user = TestRepo.get(TestUser, "uid=manny,ou=users,dc=example,dc=com")
    assert updated_user.sn  == surname
    assert updated_user.mail == mail
  end

  test "updating a field not present on the model has no effect on the entry" do
    user = TestRepo.get(TestUser, "uid=manny,ou=users,dc=example,dc=com")

    user
    |> TestUser.changeset(%{"nickname" => "Rockman"})
    |> TestRepo.update

    updated_user = TestRepo.get(TestUser, "uid=manny,ou=users,dc=example,dc=com")
    assert updated_user == user
  end

  test "fields returned are limited by select" do
    values = TestRepo.all(Ecto.Query.from(u in TestUser, select: u.uid))
    assert values == ["jeff.weiss", "manny"]
  end

  test "multiple fields ordered correctly by select" do
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: u.uid == "jeff.weiss", select: [u.sn, u.mail]))
    assert values == [["Weiss", "jeff.weiss@example.com"]]
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: u.uid == "jeff.weiss", select: [u.mail, u.sn]))
    assert values == [["jeff.weiss@example.com", "Weiss"]]
  end

  test "like without explicit %" do
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: like(u.sn, "Weis")))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
    query = "Weis"
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: like(u.sn, ^query)))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
  end

  test "like with trailing %" do
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: like(u.uid, "jeff%")))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
    query = "jeff%"
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: like(u.uid, ^query)))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
  end

  test "like with leading %" do
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: like(u.sn, "%eiss")))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
    query = "%eiss"
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: like(u.sn, ^query)))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
  end

  test "like with leading and trailing %" do
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: like(u.sn, "%Weis%")))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
    query = "%Weis%"
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: like(u.sn, ^query)))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
  end

  test "in keyword with a list" do
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: u.uid in ["jeff.weiss", "jeff"]))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
    list = ["jeff.weiss", "jeff"]
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: u.uid in ^list))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
  end

  test "multiple criteria with `and`" do
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: u.st == "OR" and "elixir" in u.skills))
    assert Enum.count(values) == 1
    assert hd(values).uid == "jeff.weiss"
  end

  test "multiple criteria with `or`" do
    values = TestRepo.all(Ecto.Query.from(u in TestUser, where: u.st == "OR" or not is_nil(u.skills)))
    assert Enum.count(values) == 2
  end

  test "delete_all unsupported" do
    assert_raise RuntimeError, fn ->
      TestRepo.delete_all(TestUser, dn: "uid=manny,ou=users,dc=example,dc=com")
    end
  end

end
