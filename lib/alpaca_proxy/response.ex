defmodule AlpacaProxy.Response do
  @moduledoc "Receives chunked data from 3rd-party API and proxy it back to client."

  alias HTTPoison.AsyncChunk
  alias HTTPoison.AsyncEnd
  alias HTTPoison.AsyncHeaders
  alias HTTPoison.AsyncStatus
  alias Plug.Conn

  @spec chunked(Conn.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  def chunked(conn, status_code \\ nil) when is_struct(conn, Conn) do
    receive do
      message -> handle_message(conn, message, status_code)
    end
  end

  @spec handle_message(Conn.t(), {:plug_conn, :sent}, nil | non_neg_integer()) :: conn :: Conn.t()
  defp handle_message(conn, tuple, status_code)
       when is_tuple(tuple) and elem(tuple, 0) == :plug_conn and elem(tuple, 1) == :sent do
    chunked(conn, status_code)
  end

  @spec handle_message(Conn.t(), AsyncStatus.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  defp handle_message(conn, async_status, nil)
       when is_struct(async_status, AsyncStatus) do
    conn
    |> Conn.delete_resp_header("cache-control")
    |> Conn.delete_resp_header("x-request-id")
    |> chunked(async_status.code)
  end

  @spec handle_message(Conn.t(), AsyncHeaders.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  defp handle_message(conn, async_headers, status_code)
       when is_struct(async_headers, AsyncHeaders) do
    headers =
      async_headers
      |> Map.fetch!(:headers)
      |> Enum.map(fn {name, value} -> {String.downcase(name), value} end)

    conn
    |> Conn.prepend_resp_headers(headers)
    |> Conn.send_chunked(status_code)
    |> chunked(status_code)
  end

  @spec handle_message(Conn.t(), AsyncChunk.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  defp handle_message(conn, async_chunk, status_code)
       when is_struct(async_chunk, AsyncChunk) do
    Conn.chunk(conn, async_chunk.chunk)
    chunked(conn, status_code)
  end

  @spec handle_message(Conn.t(), AsyncEnd.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  defp handle_message(conn, async_end, _status_code) when is_struct(async_end, AsyncEnd) do
    conn
  end
end
