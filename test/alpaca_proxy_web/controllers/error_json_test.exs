defmodule AlpacaProxyWeb.ErrorJSONTest do
  use ExUnit.Case, async: true

  alias AlpacaProxyWeb.ErrorJSON

  for {code, message} <- %{404 => "Not Found", 500 => "Internal Server Error"} do
    test "renders #{code}" do
      expected = %{errors: %{detail: unquote(message)}}
      assert ErrorJSON.render("#{unquote(code)}.json", %{}) == expected
    end
  end
end
