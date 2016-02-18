defmodule Ecto.Ldap.Adapter.Sandbox do
  use GenServer

  @jeffweiss {:eldap_entry, 'uid=jeff.weiss,ou=users,dc=example,dc=com', [
      {'cn', ['Jeff Weiss']},
      {'displayName', ['Jeff Weiss']},
      {'gidNumber', ['5000']},
      {'givenName', ['Jeff']},
      {'homeDirectory', ['/home/jeff.weiss']},
      {'l', ['Portland']},
      {'loginShell', ['/bin/zsh']},
      {'mail', ['jeff.weiss@example.com', 'jeff.weiss@example.org']},
      {'objectClass', ['posixAccount','shadowAccount', 'inetOrgPerson', 'ldapPublicKey', 'top']},
      {'skills', ['dad jokes', 'being awesome', 'elixir']},
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
      {'skills', ['nunchuck', 'computer hacking', 'bowhunting']},
      {'sn', ['Batule']},
      {'sshPublicKey', ['ssh-rsa AAAA/TOTALLY+FAKE/KEY+2 manny@example.com']},
      {'st', ['OR']},
      {'title', ['Senior Software Engineer']},
      {'uid', ['manny']},
      {'uidNumber', ['5002']},
    ]}

  def init(_) do
    {:ok, [@jeffweiss, @manny]}
  end

  def search(pid, search_options) when is_list(search_options) do
    GenServer.call(pid, {:search, Map.new(search_options)})
  end
  def modify(pid, dn, modify_operations) do
    GenServer.call(pid, {:update, dn, modify_operations})
  end
  def handle_call({:search, %{scope: :baseObject, base: 'uid=jeff.weiss,ou=users,dc=example,dc=com'}}, _from, state) do
    ldap_response = {:ok, {:eldap_search_result, [List.first(state)], []}}
    {:reply, ldap_response, state}
  end
  def handle_call({:search, %{scope: :baseObject, base: 'uid=manny,ou=users,dc=example,dc=com'}}, _from, state) do
    ldap_response = {:ok, {:eldap_search_result, [List.last(state)], []}}
    {:reply, ldap_response, state}
  end
  def handle_call({:search, %{scope: :baseObject}}, _from, state) do
    ldap_response = {:ok, {:eldap_search_result, [], []}}
    {:reply, ldap_response, state}
  end
  def handle_call({:search, %{base: 'ou=users,dc=example,dc=com', filter: {:and, [and: [equalityMatch: {:AttributeValueAssertion, 'uid', 'jeff.weiss'}], and: []]}}}, _from, state) do
    ldap_response = {:ok, {:eldap_search_result, [List.first(state)], []}}
    {:reply, ldap_response, state}
  end
  def handle_call({:search, %{base: 'ou=users,dc=example,dc=com', filter: {:and, [and: [], and: [equalityMatch: {:AttributeValueAssertion, 'uid', 'jeff.weiss'}]]}}}, _from, state) do
    ldap_response = {:ok, {:eldap_search_result, [List.first(state)], []}}
    {:reply, ldap_response, state}
  end
  def handle_call({:search, %{base: 'ou=users,dc=example,dc=com'}}, _from, state) do
    ldap_response = {:ok, {:eldap_search_result, state, []}}
    {:reply, ldap_response, state}
  end
  def handle_call({:search, _search_options}, _from, state) do
    ldap_response = {:ok, {:eldap_search_result, [], []}}
    {:reply, ldap_response, state}
  end
  def handle_call({:update, 'uid=manny,ou=users,dc=example,dc=com', modify_operations}, _from, state) do
    {:eldap_entry, dn, attributes} = List.last(state)

    attribute_map       = Enum.into(attributes, %{})
    updated_attributes  = Enum.reduce(
      modify_operations,
      attribute_map,
      fn ({:ModifyRequest_changes_SEQOF, :replace, {:PartialAttribute, attribute, []}}, attribute_map) ->
          Map.update!(attribute_map, attribute, fn _ -> nil end)
         ({:ModifyRequest_changes_SEQOF, :replace, {:PartialAttribute, attribute, new_value}}, attribute_map) ->
          Map.update!(attribute_map, attribute, fn _ -> new_value end) end)
    |> Enum.to_list

    updated_eldap_entry = {:eldap_entry, dn, updated_attributes}
    updated_state       = [List.first(state), updated_eldap_entry]

    {:reply, :ok, updated_state}
  end

  def open(_hosts, _options) do
    __MODULE__
    |> Process.whereis
    |> case do
      nil -> GenServer.start_link(__MODULE__, [], name: __MODULE__)
      pid -> {:ok, pid}
    end
  end

  def simple_bind(_pid, 'uid=sample_user,ou=users,dc=example,dc=com', 'password'), do: :ok
  def simple_bind(_, _, _), do: {:error, :invalidCredentials}

  def close(_pid) do
    :ok
  end
end
