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
      data: list
      |> List.flatten
    })
  end
end
