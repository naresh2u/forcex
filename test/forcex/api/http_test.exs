defmodule Forcex.Api.HttpTest do
  use ExUnit.Case, async: true

  alias HTTPoison.Response

  describe "process_response/1 content-encoding casing" do
    for header_name <- ["Content-Encoding", "content-encoding", "CoNtEnT-EnCoDiNg"] do
      test "gunzips 200 response when header casing is #{header_name}" do
        xml = "<env:Envelope><env:Body><ok>true</ok></env:Body></env:Envelope>"

        response = %Response{
          status_code: 200,
          body: :zlib.gzip(xml),
          headers: %{unquote(header_name) => "gzip"}
        }

        assert Forcex.Api.Http.process_response(response) == xml
      end

      test "gunzips 5xx response when header casing is #{header_name}" do
        body = "{\"error\":\"server_error\"}"

        response = %Response{
          status_code: 500,
          body: :zlib.gzip(body),
          headers: %{unquote(header_name) => "gzip"}
        }

        assert Forcex.Api.Http.process_response(response) == {500, body}
      end
    end
  end

  describe "process_response/1 content-type casing" do
    for header_name <- ["Content-Type", "content-type", "CoNtEnT-TyPe"] do
      test "decodes json 200 response when header casing is #{header_name}" do
        response = %Response{
          status_code: 200,
          body: "{\"ok\":true}",
          headers: %{unquote(header_name) => "application/json; charset=utf-8"}
        }

        assert Forcex.Api.Http.process_response(response) == %{ok: true}
      end

      test "decodes json 4xx response then returns status tuple when header casing is #{header_name}" do
        response = %Response{
          status_code: 404,
          body: "{\"error\":\"not_found\"}",
          headers: %{unquote(header_name) => "application/json"}
        }

        assert Forcex.Api.Http.process_response(response) == {404, %{error: "not_found"}}
      end
    end
  end

  test "gunzips then decodes json when both headers are lowercase" do
    json = "{\"id\":123,\"success\":true}"

    response = %Response{
      status_code: 200,
      body: :zlib.gzip(json),
      headers: %{
        "content-encoding" => "gzip",
        "content-type" => "application/json"
      }
    }

    assert Forcex.Api.Http.process_response(response) == %{id: 123, success: true}
  end

  test "returns non-gzipped non-json 200 body as-is" do
    body = "<xml>ok</xml>"
    response = %Response{status_code: 200, body: body, headers: %{"Content-Type" => "text/xml"}}

    assert Forcex.Api.Http.process_response(response) == body
  end

  test "returns non-gzipped non-json errors as status tuple" do
    body = "service unavailable"
    response = %Response{status_code: 503, body: body, headers: %{"Content-Type" => "text/plain"}}

    assert Forcex.Api.Http.process_response(response) == {503, body}
  end
end
