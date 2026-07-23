defmodule Transport.Validators.NeTEx.ResultsAdapters.V0_1_0Test do
  use ExUnit.Case, async: true
  doctest Transport.Validators.NeTEx.ResultsAdapters.V0_1_0, import: true
  alias Transport.Validators.NeTEx.ResultsAdapters.Commons
  alias Transport.Validators.NeTEx.ResultsAdapters.V0_1_0
  import TransportWeb.PaginationHelpers, only: [make_pagination_config: 1]

  @xsd %{
    "code" => "xsd-123",
    "message" => "Resource 23504000009 hasn't expected class but Netex::OperatingPeriod",
    "criticity" => "error"
  }
  @rule %{
    "code" => "valid-day-bits",
    "message" => "Mandatory attribute valid_day_bits not found",
    "criticity" => "error"
  }

  test "get_issues from binary, with errors" do
    pagination_config = make_pagination_config(%{})

    binary_result =
      result_factory("valid-day-bits": 41, "xsd-123": 41)
      |> V0_1_0.to_binary_result()

    assert {%{"issue_type" => "valid-day-bits"}, {41, repeated(@rule, 20)}} ==
             V0_1_0.get_issues(binary_result, %{}, pagination_config)

    assert {%{"issue_type" => "xsd-123"}, {41, repeated(@xsd, 20)}} ==
             V0_1_0.get_issues(binary_result, %{"issue_type" => "xsd-123"}, pagination_config)

    assert {%{"issue_type" => "valid-day-bits"}, {41, repeated(@rule, 20)}} ==
             V0_1_0.get_issues(binary_result, %{"issue_type" => "valid-day-bits"}, pagination_config)

    pagination_config = make_pagination_config(%{"page" => "3"})

    assert {%{"issue_type" => "valid-day-bits"}, {41, repeated(@rule, 1)}} ==
             V0_1_0.get_issues(binary_result, %{}, pagination_config)

    assert {%{"issue_type" => "xsd-123"}, {41, repeated(@xsd, 1)}} ==
             V0_1_0.get_issues(binary_result, %{"issue_type" => "xsd-123"}, pagination_config)

    assert {%{"issue_type" => "valid-day-bits"}, {41, repeated(@rule, 1)}} ==
             V0_1_0.get_issues(binary_result, %{"issue_type" => "valid-day-bits"}, pagination_config)
  end

  test "order_issues_by_location sorts by severity first, then by location" do
    require Explorer.DataFrame, as: DF

    # Create issues with mixed severities - intentionally out of order
    errors = [
      %{
        "code" => "rule-a",
        "criticity" => "error",
        "message" => "Error B",
        "resource.filename" => "a.xml",
        "resource.line" => 10
      },
      %{
        "code" => "rule-b",
        "criticity" => "error",
        "message" => "Error A",
        "resource.filename" => "b.xml",
        "resource.line" => 5
      }
    ]

    warnings = [
      %{
        "code" => "rule-c",
        "criticity" => "warning",
        "message" => "Warning B",
        "resource.filename" => "a.xml",
        "resource.line" => 20
      },
      %{
        "code" => "rule-d",
        "criticity" => "warning",
        "message" => "Warning A",
        "resource.filename" => "b.xml",
        "resource.line" => 15
      }
    ]

    informations = [
      %{
        "code" => "rule-e",
        "criticity" => "information",
        "message" => "Info B",
        "resource.filename" => "a.xml",
        "resource.line" => 30
      },
      %{
        "code" => "rule-f",
        "criticity" => "information",
        "message" => "Info A",
        "resource.filename" => "b.xml",
        "resource.line" => 25
      }
    ]

    all_issues = errors ++ warnings ++ informations

    df =
      all_issues
      |> Enum.map(fn issue ->
        resource =
          issue
          |> Map.take(["resource.filename", "resource.line"])
          |> Map.new(fn {k, v} -> {String.replace_prefix(k, "resource.", ""), v} end)

        %{
          "code" => issue["code"],
          "criticity" => issue["criticity"],
          "message" => issue["message"],
          "resource" => resource
        }
      end)
      |> Commons.to_dataframe(fn _ -> %{} end)

    sorted_df = V0_1_0.order_issues_by_location(df)
    sorted_rows = DF.to_rows(sorted_df)

    # Verify: all errors come first, then warnings, then info
    criticity_order = Enum.map(sorted_rows, & &1["criticity"])
    assert criticity_order == ["error", "error", "warning", "warning", "information", "information"]

    # Verify within each severity, sorted by filename, line, message
    errors = Enum.filter(sorted_rows, &(&1["criticity"] == "error"))
    assert Enum.map(errors, & &1["resource.filename"]) == ["a.xml", "b.xml"]

    warnings = Enum.filter(sorted_rows, &(&1["criticity"] == "warning"))
    assert Enum.map(warnings, & &1["resource.filename"]) == ["a.xml", "b.xml"]

    infos = Enum.filter(sorted_rows, &(&1["criticity"] == "information"))
    assert Enum.map(infos, & &1["resource.filename"]) == ["a.xml", "b.xml"]
  end

  test "get_issues from binary, no error" do
    pagination_config = make_pagination_config(%{})

    binary_result =
      result_factory("xsd-123": 0, "valid-day-bits": 0)
      |> V0_1_0.to_binary_result()

    assert {%{"issue_type" => ""}, {0, repeated(@rule, 0)}} ==
             V0_1_0.get_issues(binary_result, %{}, pagination_config)

    assert {%{"issue_type" => "xsd-123"}, {0, repeated(@xsd, 0)}} ==
             V0_1_0.get_issues(binary_result, %{"issue_type" => "xsd-123"}, pagination_config)

    assert {%{"issue_type" => "valid-day-bits"}, {0, repeated(@rule, 0)}} ==
             V0_1_0.get_issues(binary_result, %{"issue_type" => "valid-day-bits"}, pagination_config)

    pagination_config = make_pagination_config(%{"page" => "3"})

    assert {%{"issue_type" => ""}, {0, repeated(@rule, 0)}} ==
             V0_1_0.get_issues(binary_result, %{}, pagination_config)

    assert {%{"issue_type" => "xsd-123"}, {0, repeated(@xsd, 0)}} ==
             V0_1_0.get_issues(binary_result, %{"issue_type" => "xsd-123"}, pagination_config)

    assert {%{"issue_type" => "valid-day-bits"}, {0, repeated(@rule, 0)}} ==
             V0_1_0.get_issues(binary_result, %{"issue_type" => "valid-day-bits"}, pagination_config)
  end

  defp result_factory(counts) do
    counts
    |> Enum.flat_map(fn {category, count} ->
      error_factory(category, count)
    end)
  end

  defp error_factory(:"xsd-123", count), do: repeated(@xsd, count)
  defp error_factory(:"valid-day-bits", count), do: repeated(@rule, count)
  defp error_factory(_, _), do: []

  test "count_by_category_and_severity returns correct counts per category and severity" do
    # V0_1.0 synthesizes categories from code prefixes:
    # - "xsd-*" codes → "xsd-schema" category
    # - other codes → "base-rules" category
    xsd_errors = [
      %{
        "code" => "xsd-1",
        "criticity" => "error",
        "message" => "XSD Error A",
        "resource.filename" => "a.xml",
        "resource.line" => 10
      },
      %{
        "code" => "xsd-2",
        "criticity" => "warning",
        "message" => "XSD Warning A",
        "resource.filename" => "a.xml",
        "resource.line" => 20
      }
    ]

    base_errors = [
      %{
        "code" => "rule-a",
        "criticity" => "error",
        "message" => "Error A",
        "resource.filename" => "b.xml",
        "resource.line" => 5
      },
      %{
        "code" => "rule-b",
        "criticity" => "information",
        "message" => "Info A",
        "resource.filename" => "c.xml",
        "resource.line" => 30
      }
    ]

    # Build result map like the validator would produce
    result = %{
      "xsd-schema" => xsd_errors,
      "base-rules" => base_errors
    }

    binary_result = V0_1_0.to_binary_result(result)

    # Call count_by_category_and_severity with the parquet file path (binary)
    counts = V0_1_0.count_by_category_and_severity(binary_result)

    # Verify structure: %{"xsd-schema" => %{...}, "base-rules" => %{...}}
    assert Map.has_key?(counts, "xsd-schema")
    assert Map.has_key?(counts, "base-rules")

    xsd = counts["xsd-schema"]
    assert is_map(xsd)
    # 1 error, 1 warning in xsd-schema
    assert xsd["error"] == 1
    assert xsd["warning"] == 1

    base = counts["base-rules"]
    assert is_map(base)
    # 1 error, 1 information in base-rules
    assert base["error"] == 1
    assert base["information"] == 1
  end

  defp repeated(item, times) do
    [item]
    |> Stream.cycle()
    |> Enum.take(times)
  end
end
