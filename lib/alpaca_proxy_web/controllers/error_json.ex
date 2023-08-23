defmodule AlpacaProxyWeb.ErrorJSON do
  alias Phoenix.Controller

  @spec render(String.t(), map()) :: %{errors: %{detail: String.t()}}
  def render(template, _assigns) do
    message = Controller.status_message_from_template(template)
    %{errors: %{detail: message}}
  end
end
