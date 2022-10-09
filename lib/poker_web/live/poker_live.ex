defmodule PokerWeb.PokerLive do
  use PokerWeb, :live_view

  def mount(%{ "id" => id }, session, socket) do
    IO.inspect(session)
    my_id = Map.get(session, "id")
    socket = assign(socket, admin: nil)
    socket = 
      if connected?(socket) do
        # Assign myself as the admin. If someone answers with the status, it'll be overwritten.
        socket = assign(socket, admin: my_id)

        # Tell the world we are here and get the state.
        PokerWeb.Endpoint.subscribe(id)
        PokerWeb.Endpoint.broadcast!(id, "new_user", %{ user_id: my_id, name: my_id })

        socket
        |> assign(room_id: id)
      else
        socket
      end

    socket = assign(socket, vote: 0, 
                            reveal: false,
                            me: my_id,
                            users: [%{ user_id: my_id, vote: nil, name: my_id }],
                            name: my_id, 
                            topic: "No topic defined", 
                            )
    {:ok, socket}
  end

  def render(assigns) when assigns.admin == assigns.me do
    IO.inspect(assigns)
    ~L"""
    <div class="row" style="justify-content: space-between; column-gap: 1rem;">
      <button phx-click="restart" class="button button-outline" style="flex-grow: 1; color: red"> 🗘 Restart / New </button>
      <button phx-click="reveal"  class="button button-outline" style="flex-grow: 1; color: red"> 👀 Reveal votes </button>
    </div>
    <form phx-change="update_topic">
      Topic: <input name="topic" value="<%= @topic %>">
    </form>
    <form phx-change="update_name">
      <label>Your name: </label><input name="name" value="<%= @name %>"> 
    </form>

    <div style="display: flex; justify-content: space-between">
        <span>You voted: <%= @vote %></span>
        <span>Average: <%= calc_average_votes(@users) %></span>
    </div>

    <div class="row" style="justify-content: space-between;column-gap: 1rem;">
        <button phx-click="vote" value=1 style="flex-grow: 1"> 1 </button>
        <button phx-click="vote" value=2 style="flex-grow: 1"> 2 </button>
        <button phx-click="vote" value=3 style="flex-grow: 1"> 3 </button>
        <button phx-click="vote" value=5 style="flex-grow: 1"> 5 </button>
        <button phx-click="vote" value=8 style="flex-grow: 1"> 8 </button>
        <button phx-click="vote" value=13 style="flex-grow: 1"> 13 </button>
    </div>

    <hr>
    <h2> Users </h2>

    <%= for user <- users_in_order(@users) do %>
    <div class="users-row">
      <%= if Map.get(user, :vote) do %>
        <div class="users-column"> 👤 <strong><%= user.name %></strong> voted </div>
        <div class="users-column result"><%= user.vote %></div>
      <% else %>
        <div class="users-column"> 👤 <strong><%= user.name %></strong> hasn't voted yet</div>
      <% end %>
    </div>
    <% end %>
    <div class="users-row" style="border-bottom: solid 1px black"></div>
    <div class="users-row">
      <div class="users-column"> 🗠  <strong>Average</strong> </div>
      <div class="users-column result"><%= average_votes(@users) %></div>
    </div>
    """
  end

  def render(assigns) do
    ~L"""
    <h3><%= @topic %></h3>
      <input name="topic" value="<%= @topic %>" type="hidden">
    <form phx-change="update_name">
      <label>Your name: </label><input name="name" value="<%= @name %>"> 
    </form>

    You voted: <%= @vote %>

    <%= if @reveal do %>
    <% else %>
    <div class="row" style="justify-content: space-between;column-gap: 1rem;">
        <button phx-click="vote" value=1 style="flex-grow: 1"> 1 </button>
        <button phx-click="vote" value=2 style="flex-grow: 1"> 2 </button>
        <button phx-click="vote" value=3 style="flex-grow: 1"> 3 </button>
        <button phx-click="vote" value=5 style="flex-grow: 1"> 5 </button>
        <button phx-click="vote" value=8 style="flex-grow: 1"> 8 </button>
        <button phx-click="vote" value=13 style="flex-grow: 1"> 13 </button>
    </div>
    <% end %>

    <hr>
    <h2> Users </h2>

    <%= if @reveal do %>
        <%= for user <- users_in_order(@users) do %>
        <div class="users-row">
          <%= if Map.get(user, :vote) do %>
            <div class="users-column"> 👤 <strong><%= user.name %></strong> voted </div>
            <div class="users-column result"><%= user.vote %></div>
          <% else %>
            <div class="users-column"> 👤 <strong><%= user.name %></strong> hasn't voted yet</div>
          <% end %>
        </div>
        <% end %>
        <div class="users-row" style="border-bottom: solid 1px black"></div>
        <div class="users-row">
          <div class="users-column"> 🗠  <strong>Average</strong> </div>
          <div class="users-column result"><%= average_votes(@users) %></div>
        </div>
    <% else %>
        <%= for user <- @users do %>
        <div class="users-row">
          <%= if Map.get(user, :vote) do %>
            <div class="users-column"> 👤 <strong><%= user.name %></strong> voted </div>
            <div class="users-column result"> ✅ </div>
          <% else %>
            <div class="users-column"> 👤 <strong><%= user.name %></strong> hasn't voted yet</div>
          <% end %>
        </div>
        <% end %>
    <% end %>

    """
  end


  # View Helper functions
  #######################
  defp calc_average_votes(users) do
    average = Enum.filter(users, fn user -> user.vote end )
      |> Enum.reduce(%{sum: 0, votes: 0},  
                     fn item, %{ sum: sum, votes: votes } -> %{sum: item.vote + sum, votes: votes + 1 } end 
                    )
    if average[:votes] == 0 do
      "0/0"
    else
      "#{ Kernel.trunc( average[:sum] / average[:votes] ) }/#{ average[:votes] }"
    end
  end

  defp average_votes(users) do
    average = Enum.filter(users, fn user -> user.vote end )
      |> Enum.reduce(%{sum: 0, votes: 0},
                     fn item, %{ sum: sum, votes: votes } -> %{sum: item.vote + sum, votes: votes + 1 } end
                    )
    if average[:votes] == 0 do
      "0"
    else
      "#{ Kernel.trunc( average[:sum] / average[:votes] ) }"
    end
  end


  defp users_in_order(users) do
    Enum.sort(users, fn (u1, u2) -> u1.vote < u2.vote end)
  end

  # Events
  #########
  def handle_event("vote", %{ "value" => value } = params , socket) do
    PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "vote", %{ value: String.to_integer(value), user_id: socket.assigns.me }) # PubSub
    socket = assign(socket, :vote, String.to_integer(value))
    {:noreply, socket}
  end

  def handle_event("update_topic", %{"topic" => topic}, socket) do
    PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "update_topic", %{ topic: topic, user_id: socket.assigns.me }) 
    socket = assign(socket, topic: topic)
    {:noreply, socket}
  end

  def handle_event("update_name", %{"name" => name}, socket) do
    PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "update_name", %{ name: name, user_id: socket.assigns.me }) 
    socket = assign(socket, name: name)
    {:noreply, socket}
  end

  def handle_event("restart", _params, socket) do
    if socket.assigns.me == socket.assigns.admin do
        PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "restart", %{ user_id: socket.assigns.me }) 
    end
    {:noreply, socket}
  end

  def handle_event("reveal", _params, socket) do
    if socket.assigns.me == socket.assigns.admin do
        PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "reveal", %{ user_id: socket.assigns.me }) 
    end
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

  def handle_info(%{event: "update_topic", payload: %{ topic: topic, user_id: user_id } }, socket) do
    socket = assign(socket, topic: topic)
    {:noreply, socket}
  end

  def handle_info(%{event: "update_name", payload: %{ name: name, user_id: user_id } }, socket) do
    # Update the user's name
    users = Enum.map(socket.assigns.users, fn
      %{ :user_id => ^user_id } = map ->
        map
        |> Map.put(:name, name)
      other -> other
    end)
    socket = assign(socket, users: users)
    {:noreply, socket}
  end

  def handle_info(%{event: "new_user", payload: %{ user_id: user_id, name: name } }, socket) when user_id == socket.assigns.me do
    {:noreply, socket}
  end

  def handle_info(%{event: "new_user", payload: %{ user_id: user_id, name: name } }, socket) when socket.assigns.admin == socket.assigns.me do
    # Add the user only if it doesn't exist yet.
    users = 
      if Enum.any?(socket.assigns.users, fn map -> map.user_id === user_id end ) do
        socket.assigns.users
      else
        # Add the user to the list of users.
        [ %{ user_id: user_id, vote: nil, name: name } | socket.assigns.users ]
      end
    socket = assign(socket, users: users)

    PokerWeb.Endpoint.broadcast!(
                              socket.assigns.room_id, 
                              "status", 
                              %{
                                  admin: socket.assigns.admin,
                                  users: socket.assigns.users,
                                  topic: socket.assigns.topic,
                              }
                            )
    {:noreply, socket}
  end

  def handle_info(%{event: "new_user", payload: %{ user_id: _user_id, name: _name } }, socket) do
    {:noreply, socket}
  end

  def handle_info(%{event: "status", payload: %{ admin: admin, users: users, topic: topic } }, socket) do
    [my_user] = Enum.filter(users, fn user -> user.user_id == socket.assigns.me end)

    socket = socket
    |> assign(admin: admin)
    |> assign(users: users)
    |> assign(topic: topic)
    |> assign(name: my_user.name)
    
    {:noreply, socket}
  end

  def handle_info(%{event: "restart", payload: %{ user_id: user_id } }, socket) do
    # Remove all votes and topic
    users = Enum.map(socket.assigns.users, fn user -> Map.put(user, :vote, nil) end)
    socket = socket
      |> assign(:topic, "No topic defined")
      |> assign(:users, users)
      |> assign(:vote, nil)
      |> assign(:reveal, false)
    {:noreply, socket}
  end

  def handle_info(%{event: "reveal", payload: %{ user_id: user_id } }, socket) do
    {:noreply, assign(socket, :reveal, true)}
  end

end
