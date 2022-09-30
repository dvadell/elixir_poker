defmodule PokerWeb.PokerLive do
  use PokerWeb, :live_view

  def mount(_params, _session, socket) do
    socket = assign(socket, vote: 0, name: "Diego", topic: "No topic defined") # Valor inicial
    {:ok, socket}
  end

  def render(assigns) do
    IO.inspect(assigns)
    ~L"""
    <h1>LiveView is awesome <%= @name %>!</h1>

    <form phx-change="update">
      <input name="topic" value="<%= @topic %>">
      <input name="name" value="<%= @name %>">
    </form>

    <%= @vote %>

    <button phx-click="vote"> Vote </button>
    """
  end

  def handle_event("vote", _, socket) do
    vote = socket.assigns.vote + 1;
    socket = assign(socket, :vote, vote)
    # Alternativa
    # socket= update(socket, :vote, fn vote -> vote + 1 end )
    {:noreply, socket}
  end

  def handle_event("update", %{"name" => name, "topic" => topic}, socket) do
    socket = assign(socket, topic: topic, name: name)
    {:noreply, socket}
  end
end
