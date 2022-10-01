defmodule PokerWeb.PokerLive do
  use PokerWeb, :live_view

  def mount(_params, _session, socket) do
    socket = 
      if connected?(socket) do
        {:ok, tref} = :timer.send_interval(1000, self(), :tick)
        socket
        |> assign(tref: tref)
        |> assign(user_id: Enum.random(0..10000))
      else
        socket
      end


    expiration_timex = Timex.shift(Timex.now(), seconds: 3)
    IO.inspect(expiration_timex)

    socket = assign(socket, vote: 0, 
                            name: "<pick a name>", 
                            topic: "No topic defined", 
                            expiration_timex: expiration_timex,
                            time_remaining: time_remaining(expiration_timex) ) # Valor inicial
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

    <button phx-click="vote" value=1> 1 </button>
    <button phx-click="vote" value=2> 2 </button>
    <button phx-click="vote" value=3> 3 </button>
    <button phx-click="vote" value=5> 5 </button>
    <button phx-click="vote" value=8> 8 </button>
    <button phx-click="vote" value=13> 13 </button>

    <p class="m-4 font-semibold text-indigo-800">
      <%= if @time_remaining > 0 do %>
        <%= format_time(@time_remaining) %> 
      <% else %>
        Expired!
      <% end %>
    </p>
    """
  end

  def handle_event("vote", %{ "value" => value } = params , socket) do
    socket = assign(socket, :vote, String.to_integer(value))
    # Alternativa
    # socket= update(socket, :vote, fn vote -> vote + 1 end )
    {:noreply, socket}
  end

  def handle_event("update", %{"name" => name, "topic" => topic}, socket) do
    socket = assign(socket, topic: topic, name: name)
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    expiration_timex = socket.assigns.expiration_timex
    IO.inspect(expiration_timex, label: "Expiration_time")
    socket = 
      if time_remaining(expiration_timex) < 1 do
        :timer.cancel(socket.assigns.tref)
        assign(socket, tref: nil)
      else
        socket
      end
    socket = assign(socket, time_remaining: time_remaining(expiration_timex))
    {:noreply, socket}
  end

  # Helper functions
  ##################
  defp time_remaining(expiration_timex) do
    DateTime.diff(expiration_timex, Timex.now())
  end

  defp format_time(time) do
    time
    |> Timex.Duration.from_seconds()
    |> Timex.format_duration(:humanized)
  end
end
