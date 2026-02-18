# frozen_string_literal: true

# name: discourse-plugnmeet
# about: Integrates PlugNmeet video conferencing with Discourse
# version: 0.1.0
# authors: Branwyn Tylwyth
# url: https://github.com/Folxlore-Design/discourse-plugnmeet

enabled_site_setting :plugnmeet_enabled

register_asset 'stylesheets/plugnmeet.scss'

register_svg_icon "pencil-alt"
register_svg_icon "trash-alt"

after_initialize do
  module ::DiscoursePlugnmeet
    PLUGIN_NAME = "discourse-plugnmeet"
    
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePlugnmeet
    end
  end

  require_relative 'lib/meeting_room'
  require_relative 'lib/plugnmeet_client'
  require_relative 'app/controllers/plugnmeet_controller'
  require_relative 'app/serializers/meeting_room_serializer'

  # Add meeting rooms to sidebar
  add_to_class(:user, :visible_meeting_rooms) do
    DiscoursePlugnmeet::MeetingRoom.visible_to_user(self)
  end

  # Register routes
  Discourse::Application.routes.append do
    mount ::DiscoursePlugnmeet::Engine, at: "/plugnmeet"
  end

  # Add admin route
  add_admin_route 'plugnmeet.admin.title', 'meeting-rooms'

  DiscoursePlugnmeet::Engine.routes.draw do
    get "/rooms" => "plugnmeet#list_rooms"
    get "/rooms/:id/join" => "plugnmeet#join_room"
    post "/rooms" => "plugnmeet#create_room"
    patch "/rooms/:id" => "plugnmeet#update_room"
    delete "/rooms/:id" => "plugnmeet#delete_room"
    post "/webhook" => "plugnmeet#webhook"
    get "/rooms/:id/presence" => "plugnmeet#room_presence"
  end

  # Webhook handler for presence tracking
  on(:plugnmeet_user_joined) do |room_id, user_id|
    DiscoursePlugnmeet::MeetingRoom.add_participant(room_id, user_id)
  end

  on(:plugnmeet_user_left) do |room_id, user_id|
    DiscoursePlugnmeet::MeetingRoom.remove_participant(room_id, user_id)
  end
end
