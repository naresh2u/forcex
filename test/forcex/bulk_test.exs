defmodule Forcex.BulkTest do
  use ExUnit.Case, async: true

  alias HTTPoison.Response

  describe "process_response/1 content-encoding casing" do
    for header_name <- ["Content-Encoding", "content-encoding", "CoNtEnT-EnCoDiNg"] do
      test "gunzips body for 2xx responses when header casing is #{header_name}" do
        original_body = "<root><ok>true</ok></root>"

        response = %Response{
          status_code: 200,
          body: :zlib.gzip(original_body),
          headers: %{unquote(header_name) => "gzip"}
        }

        assert Forcex.Bulk.process_response(response) == original_body
      end

      test "gunzips body for 5xx responses when header casing is #{header_name}" do
        original_body = "{\"error\":\"bad_gateway\"}"

        response = %Response{
          status_code: 502,
          body: :zlib.gzip(original_body),
          headers: %{unquote(header_name) => "gzip"}
        }

        assert Forcex.Bulk.process_response(response) == {502, original_body}
      end
    end
  end

  describe "process_response/1 content-type casing" do
    for header_name <- ["Content-Type", "content-type", "CoNtEnT-TyPe"] do
      test "decodes json for 2xx responses when header casing is #{header_name}" do
        response = %Response{
          status_code: 200,
          body: "{\"ok\":true}",
          headers: %{unquote(header_name) => "application/json; charset=utf-8"}
        }

        assert Forcex.Bulk.process_response(response) == %{ok: true}
      end

      test "decodes json for 4xx responses before returning status tuple when header casing is #{header_name}" do
        response = %Response{
          status_code: 404,
          body: "{\"error\":\"not_found\"}",
          headers: %{unquote(header_name) => "application/json"}
        }

        assert Forcex.Bulk.process_response(response) == {404, %{error: "not_found"}}
      end
    end
  end

  test "gunzips then json-decodes when both headers are present in lowercase" do
    json = "{\"id\":123,\"success\":true}"

    response = %Response{
      status_code: 201,
      body: :zlib.gzip(json),
      headers: %{
        "content-encoding" => "gzip",
        "content-type" => "application/json"
      }
    }

    assert Forcex.Bulk.process_response(response) == %{id: 123, success: true}
  end

  test "gunzips then json-decodes when both headers are mixed-case on error responses" do
    json = "{\"error\":\"server_error\"}"

    response = %Response{
      status_code: 500,
      body: :zlib.gzip(json),
      headers: %{
        "CoNtEnT-EnCoDiNg" => "gzip",
        "CoNtEnT-TyPe" => "application/json"
      }
    }

    assert Forcex.Bulk.process_response(response) == {500, %{error: "server_error"}}
  end

  test "non-gzipped non-json 2xx responses are returned as-is" do
    body = "<xml>ok</xml>"

    response = %Response{status_code: 200, body: body, headers: %{"Content-Type" => "text/xml"}}

    assert Forcex.Bulk.process_response(response) == body
  end

  test "non-gzipped non-json error responses return status tuple" do
    body = "service unavailable"

    response = %Response{status_code: 503, body: body, headers: %{"Content-Type" => "text/plain"}}

    assert Forcex.Bulk.process_response(response) == {503, body}
  end
end
