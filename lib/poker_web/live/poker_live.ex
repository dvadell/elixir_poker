defmodule PokerWeb.PokerLive do
  use PokerWeb, :live_view

  def mount(%{ "id" => id }, _session, socket) do
    initial_name = MnemonicSlugs.generate_slug
    socket = assign(socket, admin: nil)
    socket = 
      if connected?(socket) do
        # Assign myself as the admin. If someone answers with the status, it'll be overwritten.
        socket = assign(socket, admin: socket.id)

        # Tell the world we are here and get the state.
        PokerWeb.Endpoint.subscribe(id)
        PokerWeb.Endpoint.broadcast!(id, "new_user", %{ user_id: socket.id, name: initial_name })

        socket
        |> assign(room_id: id)
      else
        socket
      end

    socket = assign(socket, vote: 0, 
                            reveal: false,
                            me: socket.id,
                            users: [%{ user_id: socket.id, vote: nil, name: initial_name }],
                            name: initial_name, 
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
    <div class="row">
      <%= if Map.get(user, :vote) do %>
        <p><%= icon_from_user(user, @admin) %> <%= user.name %> voted <%= user.vote %></p>
      <% else %>
        <p><%= icon_from_user(user, @admin) %> <%= user.name %> hasn't voted yet</p>
      <% end %>
    </div>
    <% end %>
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

    <%= if @reveal do %>
        <%= for user <- users_in_order(@users) do %>
        <div class="row">
          <%= if Map.get(user, :vote) do %>
            <p><%= icon_from_user(user, @admin) %> <%= user.name %> voted <%= user.vote %></p>
          <% else %>
            <p><%= icon_from_user(user, @admin) %> <%= user.name %> hasn't voted yet</p>
          <% end %>
        </div>
        <% end %>
    <% else %>
        <%= for user <- @users do %>
        <div class="row">
          <%= if Map.get(user, :vote) do %>
            <p><%= icon_from_user(user, @admin) %> <%= user.name %> voted</p>
          <% else %>
            <p><%= icon_from_user(user, @admin) %> <%= user.name %> hasn't voted yet</p>
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

  defp users_in_order(users) do
    Enum.sort(users, fn (u1, u2) -> u1.vote < u2.vote end)
  end

  defp icon_from_user(user, admin \\ false) do
    background = 
      if admin == user.user_id do
        "red"
      else
        "blue"
      end

    name = if user.name != "" do
      user.name
    else
      "?"
    end

    IO.inspect(name, label: "NAME")
    initial = name
      |> String.trim()
      |> String.at(0)
      |> String.upcase
	    ~s(<span style="width: 40px; height: 40px; font-size: 3rem; background-color: #{background}; 
                            border-radius: 20px;margina: 1rem; padding-left:1rem; display: inline-block">
                  #{initial}
               </span>) |> raw()
  end

  # Events
  #########
  def handle_event("vote", %{ "value" => value } = params , socket) do
    PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "vote", %{ value: String.to_integer(value), user_id: socket.id }) # PubSub
    socket = assign(socket, :vote, String.to_integer(value))
    {:noreply, socket}
  end

  def handle_event("update_topic", %{"topic" => topic}, socket) do
    PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "update_topic", %{ topic: topic, user_id: socket.id }) 
    socket = assign(socket, topic: topic)
    {:noreply, socket}
  end

  def handle_event("update_name", %{"name" => name}, socket) do
    PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "update_name", %{ name: name, user_id: socket.id }) 
    socket = assign(socket, name: name)
    {:noreply, socket}
  end

  def handle_event("restart", _params, socket) do
    if socket.id == socket.assigns.admin do
        PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "restart", %{ user_id: socket.id }) 
    end
    {:noreply, socket}
  end

  def handle_event("reveal", _params, socket) do
    if socket.id == socket.assigns.admin do
        PokerWeb.Endpoint.broadcast!(socket.assigns.room_id, "reveal", %{ user_id: socket.id }) 
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

  def handle_info(%{event: "new_user", payload: %{ user_id: user_id, name: name } }, socket) when user_id == socket.id do
    {:noreply, socket}
  end

  def handle_info(%{event: "new_user", payload: %{ user_id: user_id, name: name } }, socket) do
    # Add the user to the list of users.
    users = [ %{ user_id: user_id, vote: nil, name: name } | socket.assigns.users ]
    socket = assign(socket, :users, users)

    # if I'm the admin, broadcast the status.
    if socket.assigns.admin == socket.id do
        PokerWeb.Endpoint.broadcast!(
                                  socket.assigns.room_id, 
                                  "status", 
                                  %{
                                      admin: socket.assigns.admin,
                                      users: socket.assigns.users,
                                      topic: socket.assigns.topic,
                                  }
                                )
    end
    {:noreply, socket}
  end

  def handle_info(%{event: "status", payload: %{ admin: admin, users: users, topic: topic } }, socket) do
    socket = socket
    |> assign(admin: admin)
    |> assign(users: users)
    |> assign(topic: topic)
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
