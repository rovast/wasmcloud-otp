defmodule WasmcloudHostWeb.ProviderController do
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
      display_hosts
      |> Enum.map(fn {host_id, host_map} ->
        Enum.map(Map.get(host_map, :providers, %{}), fn {{provider, link_name}, info_map} ->
          provider_name =
            claims
            |> Enum.find({"", %{}}, fn {k, _v} -> k == provider end)
            |> elem(1)
            |> Map.get(:name, "N/A")

          %{
            id: "#{provider} (#{link_name}) (#{host_id})",
            provider: provider,
            provider_name: provider_name,
            link_name: link_name,
            contract_id: Map.get(info_map, :contract_id),
            status: Map.get(info_map, :status),
            host_id: host_id
          }
        end)
      end)

    json(conn, %{
      code: 1001,
      msg: "ok",
      data: list |> List.flatten
    })
  end
end
