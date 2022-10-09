defmodule PokerWeb.Plug.NoDuplicateSession do
  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    case get_session(conn, :id) do
      nil ->
        conn
        |> put_session(:id, MnemonicSlugs.generate_slug)
      _ ->
        conn
    end
  end
end
