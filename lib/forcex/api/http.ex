defmodule Forcex.Api.Http do
  @moduledoc """
  HTTP communication with Salesforce API
  """

  @behaviour Forcex.Api
  require Logger
  use HTTPoison.Base

  @user_agent [{"User-agent", "forcex"}]
  @accept [{"Accept", "application/json"}]
  @accept_encoding [{"Accept-Encoding", "gzip,deflate"}]

  @type method :: :get | :put | :post | :patch | :delete
  @type forcex_response :: map | {number, any} | String.t

  def raw_request(method, url, body, headers, options) do
    response = method |> request!(url, body, headers, extra_options() ++ options) |> process_response
    Logger.debug("#{__ENV__.module}.#{elem(__ENV__.function, 0)} response=" <> inspect(response))
    response
  end

  @spec extra_options :: list
  defp extra_options() do
    Application.get_env(:forcex, :request_options, [])
  end

  @spec process_response(HTTPoison.Response.t) :: forcex_response
  defp process_response(%HTTPoison.Response{body: body, headers: headers, status_code: status} = resp) when is_map(headers) do
    cond do
      Forcex.Util.find_header_value(headers, "content-encoding") == "gzip" ->
        normalized_headers = Forcex.Util.drop_header_case_insensitive(headers, "content-encoding")
        %{resp | body: :zlib.gunzip(body), headers: normalized_headers}
        |> process_response

      Forcex.Util.find_header_value(headers, "content-encoding") == "deflate" ->
        zstream = :zlib.open
        :ok = :zlib.inflateInit(zstream, -15)
        uncompressed_data = zstream |> :zlib.inflate(body) |> Enum.join
        :zlib.inflateEnd(zstream)
        :zlib.close(zstream)
        normalized_headers = Forcex.Util.drop_header_case_insensitive(headers, "content-encoding")
        %{resp | body: uncompressed_data, headers: normalized_headers}
        |> process_response

      String.starts_with?(Forcex.Util.find_header_value(headers, "content-type") || "", "application/json") ->
        normalized_headers = Forcex.Util.drop_header_case_insensitive(headers, "content-type")
        %{resp | body: Poison.decode!(body, keys: :atoms), headers: normalized_headers}
        |> process_response

      status == 200 ->
        body

      true ->
        {status, body}
    end
  end

  def process_request_headers(headers), do: headers ++ @user_agent ++ @accept ++ @accept_encoding

  @spec process_headers(list({String.t, String.t})) :: map
  def process_headers(headers), do: Map.new(headers)
end
