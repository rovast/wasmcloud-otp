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

    json(conn, %{
      code: 1001,
      msg: "ok",
      data: list |> List.flatten()
    })
  end

  def create_actor(conn, %{"actor" => actor, "count" => count} = _params) do
    error_msg =
      case File.read(actor.path) do
        {:ok, bytes} ->
          HostCore.Actors.ActorSupervisor.start_actor(bytes, "", String.to_integer(count))

        {:error, reason} ->
          {:error, "Error #{reason}"}
      end

    case error_msg do
      nil ->
        json(conn, %{code: 1002, msg: "Please select a file", data: nil})

      {:ok, _pids} ->
        json(conn, %{code: 1001, msg: "Success", data: nil})

      {:error, msg} ->
        json(conn, %{code: 1002, msg: msg, data: nil})
    end
  end

  def update_actor(conn, %{"path" => path, "count" => count} = _prams) do
    case WasmcloudHost.ActorWatcher.hotwatch_actor(
           :actor_watcher,
           path,
           String.to_integer(count)
         ) do
      :ok ->
        json(conn, %{code: "1001", msg: nil, data: nil})

      {:error, msg} ->
        json(conn, %{code: "1002", msg: msg, data: nil})

      msg ->
        json(conn, %{code: "1002", msg: msg, data: nil})
    end
  end
end
