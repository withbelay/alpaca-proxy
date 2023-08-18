defmodule AlpacaProxyWeb.ErrorJSON do
  alias Phoenix.Controller

  @spec render(String.t(), map()) :: %{errors: %{detail: String.t()}}
  def render(template, _assigns) do
    template
    |> Controller.status_message_from_template()
    |> then(&%{errors: %{detail: &1}})
  end
end
