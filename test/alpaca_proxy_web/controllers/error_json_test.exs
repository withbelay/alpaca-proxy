defmodule AlpacaProxyWeb.ErrorJSONTest do
  use ExUnit.Case, async: true

  alias AlpacaProxyWeb.ErrorJSON

  for {code, message} <- %{404 => "Not Found", 500 => "Internal Server Error"} do
    test "renders " <> Integer.to_string(code) do
      expected = %{errors: %{detail: unquote(message)}}
      code = Integer.to_string(unquote(code))
      assert ErrorJSON.render(code <> ".json", %{}) == expected
    end
  end
end
