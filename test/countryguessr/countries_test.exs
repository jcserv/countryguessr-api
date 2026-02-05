defmodule Countryguessr.CountriesTest do
  use ExUnit.Case, async: true

  alias Countryguessr.Countries

  describe "valid?/1" do
    test "accepts standard ISO_A2 country codes" do
      assert Countries.valid?("US")
      assert Countries.valid?("FR")
      assert Countries.valid?("GB")
      assert Countries.valid?("JP")
    end

    test "accepts special codes for disputed territories" do
      assert Countries.valid?("SYN_NORTHERN_CYPRUS")
      assert Countries.valid?("SYN_SOMALILAND")
    end

    test "rejects invalid codes" do
      refute Countries.valid?("USA")
      refute Countries.valid?("us")
      refute Countries.valid?("12")
      refute Countries.valid?("")
      refute Countries.valid?("INVALID")
    end

    test "rejects non-string input" do
      refute Countries.valid?(nil)
      refute Countries.valid?(123)
      refute Countries.valid?(:US)
    end
  end

  describe "count/0" do
    test "returns 178 countries" do
      assert Countries.count() == 178
    end
  end

  describe "all/0" do
    test "returns a MapSet" do
      assert %MapSet{} = Countries.all()
    end

    test "contains expected codes" do
      codes = Countries.all()
      assert MapSet.member?(codes, "US")
      assert MapSet.member?(codes, "SYN_NORTHERN_CYPRUS")
      assert MapSet.member?(codes, "SYN_SOMALILAND")
    end
  end
end
