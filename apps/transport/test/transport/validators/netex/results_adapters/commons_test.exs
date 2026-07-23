defmodule Transport.Validators.NeTEx.ResultsAdapters.CommonsTest do
  use ExUnit.Case, async: true
  alias Transport.Validators.NeTEx.ResultsAdapters.Commons
  require Explorer.DataFrame, as: DF
  import TransportWeb.PaginationHelpers, only: [make_pagination_config: 1]

  test "count_and_slice handles empty dataframe (no rows)" do
    # Create an empty dataframe by filtering to a category that doesn't exist
    errors = [
      %{
        "code" => "xsd-1",
        "criticity" => "error",
        "message" => "Error A",
        "resource.filename" => "a.xml",
        "resource.line" => 1
      }
    ]

    df =
      errors
      |> Commons.to_dataframe(fn _ -> %{} end)
      |> DF.filter(category == "nonexistent-category")

    # Filtered dataframe has columns but zero rows
    assert Explorer.DataFrame.names(df) != []
    assert Explorer.Series.count(df["code"]) == 0

    pagination_config = make_pagination_config(%{})
    assert {0, []} == Commons.count_and_slice(df, pagination_config)
  end

  test "count_and_slice works normally with data" do
    errors = [
      %{
        "code" => "xsd-1",
        "criticity" => "error",
        "message" => "Error A",
        "resource.filename" => "a.xml",
        "resource.line" => 1
      },
      %{
        "code" => "xsd-2",
        "criticity" => "warning",
        "message" => "Warning B",
        "resource.filename" => "b.xml",
        "resource.line" => 2
      }
    ]

    df =
      errors
      |> Commons.to_dataframe(fn _ -> %{} end)

    pagination_config = make_pagination_config(%{})
    {total, issues} = Commons.count_and_slice(df, pagination_config)
    assert total == 2
    assert length(issues) == 2
  end

  @xsd %{
    "code" => "xsd-123",
    "message" => "Resource 23504000009 hasn't expected class but Netex::OperatingPeriod",
    "criticity" => "error",
    "resource" => %{
      "line" => 1,
      "filename" => "stops.xml"
    }
  }

  @rule %{
    "code" => "valid-day-bits",
    "message" => "Mandatory attribute valid_day_bits not found",
    "criticity" => "error"
  }

  @errors [@xsd, @rule]

  test "dataframe building" do
    assert [
             %{
               "code" => "xsd-123",
               "message" => "Resource 23504000009 hasn't expected class but Netex::OperatingPeriod",
               "criticity" => "error",
               "category" => nil,
               "resource.class" => nil,
               "resource.column" => nil,
               "resource.filename" => "stops.xml",
               "resource.id" => nil,
               "resource.line" => 1
             },
             %{
               "code" => "valid-day-bits",
               "message" => "Mandatory attribute valid_day_bits not found",
               "criticity" => "error",
               "category" => nil,
               "resource.class" => nil,
               "resource.column" => nil,
               "resource.filename" => nil,
               "resource.id" => nil,
               "resource.line" => nil
             }
           ] == example() |> DF.to_rows()
  end

  test "serialisation roundtrip" do
    df = example()
    assert df |> DF.to_rows() == df |> Commons.to_binary() |> Commons.from_binary() |> DF.to_rows()
  end

  def example do
    Commons.to_dataframe(@errors, fn _ -> %{} end)
  end

  describe "summary_from_binary/2" do
    test "returns per-category stats with worst criticity and count" do
      errors = [
        %{"code" => "xsd-1", "criticity" => "error", "category" => "xsd-schema"},
        %{"code" => "xsd-2", "criticity" => "error", "category" => "xsd-schema"},
        %{"code" => "rule-1", "criticity" => "warning", "category" => "base-rules"},
        %{"code" => "rule-2", "criticity" => "information", "category" => "base-rules"}
      ]

      df = Commons.to_dataframe(errors, fn _ -> %{} end)
      binary = Commons.to_binary(df)

      result = Commons.summary_from_binary(binary, ["xsd-schema", "base-rules"])

      assert length(result) == 2

      xsd = Enum.find(result, &(&1["category"] == "xsd-schema"))
      assert xsd["stats"] == %{"count" => 2, "criticity" => "error"}

      base = Enum.find(result, &(&1["category"] == "base-rules"))
      assert base["stats"] == %{"count" => 1, "criticity" => "warning"}
    end

    test "returns all categories with count 0 and NoError when empty" do
      df = Commons.to_dataframe([], fn _ -> %{} end)
      binary = Commons.to_binary(df)

      result = Commons.summary_from_binary(binary, ["xsd-schema", "base-rules"])

      assert length(result) == 2
      xsd = Enum.find(result, &(&1["category"] == "xsd-schema"))
      assert xsd["stats"] == %{"count" => 0, "criticity" => "NoError"}
    end
  end

  describe "count_by_category_and_severity/1" do
    test "returns per-category, per-severity counts" do
      errors = [
        %{"code" => "xsd-1", "criticity" => "error", "category" => "xsd-schema"},
        %{"code" => "xsd-2", "criticity" => "warning", "category" => "xsd-schema"},
        %{"code" => "rule-1", "criticity" => "error", "category" => "base-rules"},
        %{"code" => "rule-2", "criticity" => "information", "category" => "base-rules"}
      ]

      df = Commons.to_dataframe(errors, fn _ -> %{} end)
      binary = Commons.to_binary(df)

      result = Commons.count_by_category_and_severity(binary)

      assert result == %{
               "xsd-schema" => %{"error" => 1, "warning" => 1},
               "base-rules" => %{"error" => 1, "information" => 1}
             }
    end

    test "returns empty map when no rows" do
      df = Commons.to_dataframe([], fn _ -> %{} end)
      binary = Commons.to_binary(df)

      assert Commons.count_by_category_and_severity(binary) == %{}
    end
  end
end
