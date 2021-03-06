defmodule BlueJetWeb.NotificationTriggerControllerTest do
  use BlueJetWeb.ConnCase

  import BlueJet.Identity.TestHelper
  import BlueJet.Notification.TestHelper

  setup do
    conn =
      build_conn()
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("content-type", "application/vnd.api+json")

    %{conn: conn}
  end

  # List notification trigger
  describe "GET /v1/notification_triggers" do
    test "without access token", %{conn: conn} do
      conn = get(conn, "/v1/notification_triggers")

      assert conn.status == 401
    end

    test "with UAT", %{conn: conn} do
      user1 = standard_user_fixture()
      user2 = standard_user_fixture()

      trigger_fixture(user1.default_account)
      trigger_fixture(user1.default_account)
      trigger_fixture(user2.default_account)

      uat = get_uat(user1.default_account, user1)

      conn = put_req_header(conn, "authorization", "Bearer #{uat}")
      conn = get(conn, "/v1/notification_triggers")

      response = json_response(conn, 200)
      assert length(response["data"]) == 2
    end
  end

  # Create a notification trigger
  describe "POST /v1/notification_triggers" do
    test "without access token", %{conn: conn} do
      conn = post(conn, "/v1/notification_triggers", %{
        "data" => %{
          "type" => "NotificationTrigger"
        }
      })

      assert conn.status == 401
    end

    test "with PAT", %{conn: conn} do
      user = standard_user_fixture()
      pat = get_pat(user.default_account)

      conn = put_req_header(conn, "authorization", "Bearer #{pat}")
      conn = post(conn, "/v1/notification_triggers", %{
        "data" => %{
          "type" => "NotificationTrigger"
        }
      })

      assert conn.status == 403
    end

    test "with no attributes", %{conn: conn} do
      user = standard_user_fixture()
      uat = get_uat(user.default_account, user)

      conn = put_req_header(conn, "authorization", "Bearer #{uat}")
      conn = post(conn, "/v1/notification_triggers", %{
        "data" => %{
          "type" => "NotificationTrigger"
        }
      })

      response = json_response(conn, 422)
      assert length(response["errors"]) == 4
    end

    test "with valid attributes", %{conn: conn} do
      user = standard_user_fixture()
      uat = get_uat(user.default_account, user)

      conn = put_req_header(conn, "authorization", "Bearer #{uat}")
      conn = post(conn, "/v1/notification_triggers", %{
        "data" => %{
          "type" => "NotificationTrigger",
          "attributes" => %{
            "name" => Faker.Lorem.sentence(5),
            "event" => Faker.Lorem.sentence(5),
            "action_type" => "send_email",
            "action_target" => UUID.generate()
          }
        }
      })

      assert json_response(conn, 201)
    end
  end

  # Retrieve a notification trigger
  describe "GET /v1/notification_triggers/:id" do
    test "without access token", %{conn: conn} do
      conn = get(conn, "/v1/notification_triggers/#{UUID.generate()}")

      assert conn.status == 401
    end

    test "with PAT", %{conn: conn} do
      user = standard_user_fixture()
      pat = get_pat(user.default_account)

      conn = put_req_header(conn, "authorization", "Bearer #{pat}")
      conn = get(conn, "/v1/notification_triggers/#{UUID.generate()}")

      assert conn.status == 403
    end

    test "with UAT requesting a notification_trigger of a different account", %{conn: conn} do
      user1 = standard_user_fixture()
      user2 = standard_user_fixture()
      notification_trigger = trigger_fixture(user2.default_account)
      uat = get_uat(user1.default_account, user1)

      conn = put_req_header(conn, "authorization", "Bearer #{uat}")
      conn = get(conn, "/v1/notification_triggers/#{notification_trigger.id}")

      assert conn.status == 404
    end

    test "with UAT", %{conn: conn} do
      user = standard_user_fixture()
      notification_trigger = trigger_fixture(user.default_account)
      uat = get_uat(user.default_account, user)

      conn = put_req_header(conn, "authorization", "Bearer #{uat}")
      conn = get(conn, "/v1/notification_triggers/#{notification_trigger.id}")

      assert json_response(conn, 200)
    end
  end

  # Update a notification trigger
  describe "PATCH /v1/notification_triggers/:id" do
    test "without access token", %{conn: conn} do
      conn = patch(conn, "/v1/notification_triggers/#{UUID.generate()}", %{
        "data" => %{
          "type" => "NotificationTrigger",
          "attributes" => %{
            "name" => Faker.Lorem.sentence(5)
          }
        }
      })

      assert conn.status == 401
    end

    test "with PAT", %{conn: conn} do
      user = standard_user_fixture()
      pat = get_pat(user.default_account)

      conn = put_req_header(conn, "authorization", "Bearer #{pat}")
      conn = patch(conn, "/v1/notification_triggers/#{UUID.generate()}", %{
        "data" => %{
          "type" => "NotificationTrigger",
          "attributes" => %{
            "name" => Faker.Lorem.sentence(5)
          }
        }
      })

      assert conn.status == 403
    end

    test "with UAT requesting notification_trigger of a different account", %{conn: conn} do
      user1 = standard_user_fixture()
      user2 = standard_user_fixture()
      notification_trigger = trigger_fixture(user2.default_account)
      uat = get_uat(user1.default_account, user1)

      conn = put_req_header(conn, "authorization", "Bearer #{uat}")
      conn = patch(conn, "/v1/notification_triggers/#{notification_trigger.id}", %{
        "data" => %{
          "type" => "NotificationTrigger",
          "attributes" => %{
            "name" => Faker.Lorem.sentence(5)
          }
        }
      })

      assert conn.status == 404
    end

    test "with UAT", %{conn: conn} do
      user = standard_user_fixture()
      notification_trigger = trigger_fixture(user.default_account)
      uat = get_uat(user.default_account, user)

      conn = put_req_header(conn, "authorization", "Bearer #{uat}")
      conn = patch(conn, "/v1/notification_triggers/#{notification_trigger.id}", %{
        "data" => %{
          "type" => "NotificationTrigger",
          "attributes" => %{
            "name" => Faker.Lorem.sentence(5)
          }
        }
      })

      assert json_response(conn, 200)
    end
  end

  # Delete a notification trigger
  describe "DELETE /v1/notification_triggers/:id" do
    test "without access token", %{conn: conn} do
      conn = delete(conn, "/v1/notification_triggers/#{UUID.generate()}")

      assert conn.status == 401
    end

    test "with PAT", %{conn: conn} do
      user = standard_user_fixture()
      pat = get_pat(user.default_account)

      conn = put_req_header(conn, "authorization", "Bearer #{pat}")
      conn = delete(conn, "/v1/notification_triggers/#{UUID.generate()}")

      assert conn.status == 403
    end

    test "with UAT and requesting notification_trigger of a different account", %{conn: conn} do
      user1 = standard_user_fixture()
      user2 = standard_user_fixture()
      notification_trigger = trigger_fixture(user2.default_account)
      uat = get_uat(user1.default_account, user1)

      conn = put_req_header(conn, "authorization", "Bearer #{uat}")
      conn = delete(conn, "/v1/notification_triggers/#{notification_trigger.id}")

      assert conn.status == 404
    end

    test "with UAT", %{conn: conn} do
      user = standard_user_fixture()
      notification_trigger = trigger_fixture(user.default_account)
      uat = get_uat(user.default_account, user)

      conn = put_req_header(conn, "authorization", "Bearer #{uat}")
      conn = delete(conn, "/v1/notification_triggers/#{notification_trigger.id}")

      assert conn.status == 204
    end
  end
end
