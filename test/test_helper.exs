Code.require_file "support/test_repo.ex", __DIR__
Code.require_file "support/test_user.ex", __DIR__

Ecto.Ldap.TestRepo.start_link

ExUnit.start()
