defmodule PokerWeb.PokerLive do
  use PokerWeb, :live_view

  def mount(%{ "id" => id }, _session, socket) do
    socket = 
      if connected?(socket) do

        # Assign myself as the admin. If someone answers with the status, it'll be overwritten.
        socket = assign(socket, admin: socket.id)

        # Tell the world we are here and get the state.
        PokerWeb.Endpoint.subscribe(id)
        PokerWeb.Endpoint.broadcast!(id, "new_user", %{ user_id: socket.id })

        {:ok, tref} = :timer.send_interval(1000, self(), :tick)

        socket
        |> assign(room_id: id)
        |> assign(tref: tref)
      else
        socket
      end


    expiration_timex = Timex.shift(Timex.now(), seconds: 3)
    IO.inspect(expiration_timex)

    socket = assign(socket, vote: 0, 
                            users: [%{ user_id: socket.id }],
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

    Your vote: <%= @vote %>

    <div class="row" style="justify-content: space-between;column-gap: 1rem;">
        <button phx-click="vote" value=1 style="flex-grow: 1"> 1 </button>
        <button phx-click="vote" value=2 style="flex-grow: 1"> 2 </button>
        <button phx-click="vote" value=3 style="flex-grow: 1"> 3 </button>
        <button phx-click="vote" value=5 style="flex-grow: 1"> 5 </button>
        <button phx-click="vote" value=8 style="flex-grow: 1"> 8 </button>
        <button phx-click="vote" value=13 style="flex-grow: 1"> 13 </button>
    </div>

    <p class="m-4 font-semibold text-indigo-800">
      <%= if @time_remaining > 0 do %>
        <%= format_time(@time_remaining) %> 
      <% else %>
        Expired!
      <% end %>
    </p>

    <h2> Users: </h2>

    <%= for user <- @users do %>
    <div class="row">
      <%= if Map.get(user, :vote) do %>
        <p>User <%= user.user_id %> voted <%= user.vote %></p>
      <% else %>
        <p>User <%= user.user_id %> hasn't voted yet</p>
      <% end %>
    </div>
    <% end %>
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
    {:noreply, socket}
  end

  def handle_info(%{event: "vote", payload: %{ value: value, user_id: user_id } }, socket) do
    IO.puts("Got a vote from #{user_id}: #{value}")
    # Find the entry for the user user_id and update the vote
    users = Enum.map(socket.assigns.users, fn
      %{ :user_id => ^user_id } = map ->
        map 
        |> Map.put(:vote, value)
      other -> other
    end)

    socket = assign(socket, :users, users)
    {:noreply, socket}
  end

  def handle_info(%{event: "update", payload: %{ topic: topic, name: name, user_id: user_id } }, socket) do
    socket = assign(socket, topic: topic)
    {:noreply, socket}
  end

  def handle_info(%{event: "new_user", payload: %{ user_id: user_id } }, socket) when user_id == socket.id do
    {:noreply, socket}
  end

  def handle_info(%{event: "new_user", payload: %{ user_id: user_id } }, socket) do
    # Add the user to the list of users.
    users = [ %{ user_id: user_id, vote: 0 } | socket.assigns.users ]
    socket = assign(socket, :users, users)

    # if I'm the admin, broadcast the status.
    if socket.assigns.admin == socket.id do
        PokerWeb.Endpoint.broadcast!(
                                  socket.assigns.room_id, 
                                  "status", 
                                  %{
                                      admin: socket.assigns.admin,
                                      users: socket.assigns.users,
                                      time_remaining: socket.assigns.time_remaining,
                                      topic: socket.assigns.topic,
                                  }
                                )
    end
    {:noreply, socket}
  end

  def handle_info(%{event: "status", payload: %{ admin: admin, users: users, time_remaining: time_remaining, topic: topic } }, socket) do
    socket = socket
    |> assign(admin: admin)
    |> assign(users: users)
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
