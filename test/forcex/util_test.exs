defmodule Forcex.UtilTest do
  use ExUnit.Case, async: true

  describe "find_header_value/2" do
    for header_name <- ["Content-Encoding", "content-encoding", "CoNtEnT-EnCoDiNg"] do
      test "finds header regardless of stored header case: #{header_name}" do
        headers = %{
          unquote(header_name) => "gzip",
          "Content-Type" => "application/json"
        }

        assert Forcex.Util.find_header_value(headers, "content-encoding") == "gzip"
        assert Forcex.Util.find_header_value(headers, "Content-Encoding") == "gzip"
      end
    end

    test "returns nil when header does not exist" do
      headers = %{"Content-Type" => "application/json"}

      assert Forcex.Util.find_header_value(headers, "content-encoding") == nil
    end
  end

  describe "drop_header_case_insensitive/2" do
    for header_name <- ["Content-Type", "content-type", "CoNtEnT-TyPe"] do
      test "drops header regardless of stored header case: #{header_name}" do
        headers = %{
          unquote(header_name) => "application/json",
          "X-Trace-Id" => "abc123"
        }

        assert Forcex.Util.drop_header_case_insensitive(headers, "content-type") == %{"X-Trace-Id" => "abc123"}
      end
    end
  end
end
