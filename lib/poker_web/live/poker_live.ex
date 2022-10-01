defmodule PokerWeb.PokerLive do
  use PokerWeb, :live_view

  def mount(%{ "id" => id }, _session, socket) do
    socket = 
      if connected?(socket) do
        {:ok, tref} = :timer.send_interval(1000, self(), :tick)

        IO.puts "Subscribing to #{id}"
        PokerWeb.Endpoint.subscribe(id)
        IO.puts "Subscribed"

        socket
        |> assign(users: %{})
        |> assign(room_id: id)
        |> assign(tref: tref)
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

  # Events
  #########
  def handle_event("vote", %{ "value" => value } = params , socket) do
    PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "vote", %{ value: String.to_integer(value), user_id: socket.id }) # PubSub
    socket = assign(socket, :vote, String.to_integer(value))
    # Alternativa
    # socket= update(socket, :vote, fn vote -> vote + 1 end )
    {:noreply, socket}
  end

  def handle_event("update", %{"name" => name, "topic" => topic}, socket) do
    PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "update", %{ topic: topic, name: name, user_id: socket.id }) # PubSub
    socket = assign(socket, topic: topic, name: name)
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do

    IO.puts "Broadcasting to test"
    PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "new_message", "TICK") # PubSub

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

  ##################
  # PubSub handlers
  ##################
  def handle_info(%{event: "new_message", payload: new_message}, socket) do
    IO.puts("Got a pubsub message")
    IO.inspect(new_message)
    {:noreply, socket}
  end

  def handle_info(%{event: "vote", payload: %{ value: value, user_id: user_id } }, socket) do
    IO.puts("Got a vote from #{user_id}: #{value}")
    users = Map.put(socket.assigns.users, user_id, value)
    socket = assign(socket, :users, users)
    {:noreply, socket}
  end

  def handle_info(%{event: "update", payload: %{ topic: topic, name: name, user_id: user_id } }, socket) do
    socket = assign(socket, topic: topic)
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
