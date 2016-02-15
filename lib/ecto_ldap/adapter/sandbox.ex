defmodule Ecto.Ldap.Adapter.Sandbox do
  @jeffweiss {:eldap_entry, 'uid=jeff.weiss,ou=users,dc=example,dc=com', [
      {'cn', ['Jeff Weiss']},
      {'displayName', ['Jeff Weiss']},
      {'gidNumber', ['5000']},
      {'givenName', ['Jeff']},
      {'homeDirectory', ['/home/jeff.weiss']},
      {'l', ['Portland']},
      {'loginShell', ['/bin/zsh']},
      {'mail', ['jeff.weiss@example.com']},
      {'objectClass', ['posixAccount','shadowAccount', 'inetOrgPerson', 'ldapPublicKey', 'top']},
      {'sn', ['Weiss']},
      {'sshPublicKey', ['ssh-rsa AAAA/TOTALLY+FAKE/KEY jeff.weiss@example.com']},
      {'st', ['OR']},
      {'title', ['Principal Software Engineer']},
      {'uid', ['jeff.weiss']},
      {'uidNumber', ['5001']},
    ]}

  @manny {:eldap_entry, 'uid=manny,ou=users,dc=example,dc=com', [
      {'cn', ['Manny Batule']},
      {'displayName', ['Manny Batule']},
      {'gidNumber', ['5000']},
      {'givenName', ['Manny']},
      {'homeDirectory', ['/home/manny']},
      {'l', ['Portland']},
      {'loginShell', ['/bin/bash']},
      {'mail', ['manny@example.com']},
      {'objectClass', ['posixAccount','shadowAccount', 'inetOrgPerson', 'ldapPublicKey', 'top']},
      {'sn', ['Batule']},
      {'sshPublicKey', ['ssh-rsa AAAA/TOTALLY+FAKE/KEY+2 manny@example.com']},
      {'st', ['OR']},
      {'title', ['Senior Software Engineer']},
      {'uid', ['manny']},
      {'uidNumber', ['5002']},
    ]}


  def search(pid, search_options) when is_list(search_options) do
    search(pid, Map.new(search_options))
  end
  def search(_pid, %{scope: :baseObject, base: 'uid=jeff.weiss,ou=users,dc=example,dc=com'}) do
    {:ok, {:eldap_search_result, [@jeffweiss], []}}
  end
  def search(_pid, %{scope: :baseObject, base: 'uid=manny,ou=users,dc=example,dc=com'}) do
    {:ok, {:eldap_search_result, [@manny], []}}
  end
  def search(_pid, %{base: 'ou=users,dc=example,dc=com'}) do
    {:ok, {:eldap_search_result, [@jeffweiss, @manny], []}}
  end
  def search(_pid, _search_options) do
    {:ok, {:eldap_search_result, [], []}}
  end

  def open(_hosts, _options) do
    {:ok, nil}
  end

  def simple_bind(_pid, 'uid=sample_user,ou=users,dc=example,dc=com', 'password'), do: :ok
  def simple_bind(_, _, _), do: {:error, :invalidCredentials}

  def close(_pid) do
    :ok
  end
end
