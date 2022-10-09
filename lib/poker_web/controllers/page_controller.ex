defmodule PokerWeb.PageController do
  use PokerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html", room: "/elc/#{MnemonicSlugs.generate_slug}" )
  end
end
