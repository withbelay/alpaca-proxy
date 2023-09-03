defmodule AlpacaProxy.Response do
  @moduledoc "Receives chunked data from 3rd-party API and proxy it back to client."

  alias HTTPoison.AsyncChunk
  alias HTTPoison.AsyncEnd
  alias HTTPoison.AsyncHeaders
  alias HTTPoison.AsyncStatus
  alias Plug.Conn

  @typep message ::
           {:plug_conn, :sent}
           | AsyncStatus.t()
           | AsyncHeaders.t()
           | AsyncChunk.t()
           | AsyncEnd.t()

  @spec chunked(Conn.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  def chunked(conn, status_code \\ nil) when is_struct(conn, Conn) do
    receive do
      message -> handle_message(conn, message, status_code)
    end
  end

  @spec handle_message(Conn.t(), message(), nil | non_neg_integer()) :: conn :: Conn.t()
  defp handle_message(conn, {:plug_conn, :sent}, status_code) do
    chunked(conn, status_code)
  end

  defp handle_message(conn, async_status, nil) when is_struct(async_status, AsyncStatus) do
    conn
    |> Conn.delete_resp_header("cache-control")
    |> Conn.delete_resp_header("x-request-id")
    |> chunked(async_status.code)
  end

  defp handle_message(conn, %AsyncHeaders{} = async_headers, status_code) do
    headers =
      async_headers
      |> Map.fetch!(:headers)
      |> Enum.map(fn {name, value} -> {String.downcase(name), value} end)

    conn
    |> Conn.prepend_resp_headers(headers)
    |> Conn.send_chunked(status_code)
    |> chunked(status_code)
  end

  defp handle_message(conn, %AsyncChunk{} = async_chunk, status_code) do
    Conn.chunk(conn, async_chunk.chunk)
    chunked(conn, status_code)
  end

  defp handle_message(conn, %AsyncEnd{}, _status_code) do
    conn
  end
end
