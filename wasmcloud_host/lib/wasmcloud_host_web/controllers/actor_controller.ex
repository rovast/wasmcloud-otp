defmodule WasmcloudHostWeb.ActorController do
  use WasmcloudHostWeb, :controller

  def list(conn, _params) do
    hosts = WasmcloudHost.Lattice.StateMonitor.get_hosts()
    ocirefs = WasmcloudHost.Lattice.StateMonitor.get_ocirefs()
    claims = WasmcloudHost.Lattice.StateMonitor.get_claims()
    selected_host = HostCore.Host.host_key()

    display_hosts =
      if selected_host == nil do
        hosts
      else
        %{selected_host => hosts |> Map.get(selected_host, %{})}
      end

    list =
      Enum.map(display_hosts, fn {host_id, host_map} ->
        Enum.map(Map.get(host_map, :actors, %{}), fn {actor, info_map} ->
          actor_name =
            claims
            |> Enum.find({"", %{}}, fn {k, _v} -> k == actor end)
            |> elem(1)
            |> Map.get(:name, "N/A")

          oci_ref = ocirefs |> Enum.find({"", actor}, fn {_oci, id} -> id == actor end) |> elem(0)
          count = Map.get(info_map, :count)
          is_hotwatched = WasmcloudHost.ActorWatcher.is_hotwatched?(:actor_watcher, actor)

          %{
            id: "#{actor} (#{host_id})",
            actor: actor,
            host_id: host_id,
            count: count,
            name: actor_name,
            oci_ref: oci_ref,
            is_hotwatched: is_hotwatched
          }
        end)
      end)

    resp_success(conn, list |> List.flatten)
  end

  def create_actor_from_file(conn, %{"actor" => actor, "count" => count} = _params) do
    error_msg =
      case File.read(actor.path) do
        {:ok, bytes} ->
          HostCore.Actors.ActorSupervisor.start_actor(bytes, "", String.to_integer(count))

        {:error, reason} ->
          {:error, "Error #{reason}"}
      end

    case error_msg do
      nil ->
        resp_error(conn, "Please select a file")

      {:ok, _pids} ->
        resp_success(conn)

      {:error, msg} ->
        resp_error(conn, msg)
    end
  end

  def update_actor_from_file(conn, %{"path" => path, "count" => count} = _prams) do
    case WasmcloudHost.ActorWatcher.hotwatch_actor(
           :actor_watcher,
           path,
           String.to_integer(count)
         ) do
      :ok ->
        resp_success(conn)

      {:error, msg} ->
        resp_error(conn, msg)

      msg ->
        resp_error(conn, msg)
    end
  end

  def create_actor_from_oci(
        conn,
        %{"count" => count, "actor_ociref" => actor_ociref, "host_id" => host_id} = _params
      ) do
    case host_id do
      "" ->
        case WasmcloudHost.Lattice.ControlInterface.auction_actor(actor_ociref, %{}) do
          {:ok, auction_host_id} ->
            start_actor(actor_ociref, count, auction_host_id, conn)

          {:error, error} ->
            resp_error(conn, error)
        end

      host_id ->
        start_actor(actor_ociref, count, host_id, conn)
    end
  end

  defp start_actor(actor_ociref, count, host_id, conn) do
    actor_id =
      WasmcloudHost.Lattice.StateMonitor.get_ocirefs()
      |> Enum.find({actor_ociref, ""}, fn {oci, _id} -> oci == actor_ociref end)
      |> elem(1)

    case WasmcloudHost.Lattice.ControlInterface.scale_actor(
           actor_id,
           actor_ociref,
           String.to_integer(count),
           host_id
         ) do
      :ok ->
        resp_success(conn)

      {:error, error} ->
        resp_error(conn, error)
    end
  end

  defp resp_success(conn) do
    json(conn, %{code: "1001", msg: "ok", data: nil})
  end

  defp resp_success(conn, data) do
    json(conn, %{code: "1001", msg: "ok", data: data})
  end

  defp resp_error(conn, msg) do
    json(conn, %{code: "1002", msg: msg, data: nil})
  end
end
