# frozen_string_literal: true

module DiscoursePlugnmeet
  class PlugnmeetController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in, except: [:webhook]
    skip_before_action :verify_authenticity_token, only: [:webhook]

    def list_rooms
      rooms = if params[:all] && current_user.staff?
                MeetingRoom.all
              else
                MeetingRoom.visible_to_user(current_user)
              end

      group_names = Group.where(id: rooms.flat_map(&:allowed_group_ids).uniq).each_with_object({}) do |g, h|
        h[g.id] = g.name
      end

      rooms_with_presence = rooms.map do |room|
        {
          id: room.id,
          name: room.name,
          icon: room.icon,
          allowed_group_ids: room.allowed_group_ids,
          allowed_groups: room.allowed_group_ids.map { |gid| { id: gid, name: group_names[gid] } },
          created_at: room.created_at,
          participant_count: room.participant_count,
          participants: room.participants.limit(5).map { |u| { id: u.id, username: u.username, avatar_template: u.avatar_template } }
        }
      end

      render json: { rooms: rooms_with_presence }
    end

    def join_room
      room = MeetingRoom.find(params[:id])
      
      unless room
        return render_json_error("Room not found", status: 404)
      end

      unless room.user_can_access?(current_user)
        return render_json_error("Access denied", status: 403)
      end

      # Create room in PlugNmeet if it doesn't exist
      unless PlugnmeetClient.is_room_active?(room.id)
        result = PlugnmeetClient.create_room(room.id, room.name)
        unless result[:success]
          return render_json_error("Failed to create room: #{result[:error]}", status: 500)
        end
      end

      # Generate join token
      is_admin = current_user.staff?
      result = PlugnmeetClient.generate_join_token(
        room.id,
        current_user.username,
        current_user.id,
        is_admin: is_admin
      )

      if result[:success]
        # Mark user as present
        MeetingRoom.add_participant(room.id, current_user.id)
        
        render json: {
          join_url: result[:join_url],
          token: result[:token],
          room_name: room.name
        }
      else
        render_json_error("Failed to generate token: #{result[:error]}", status: 500)
      end
    end

    def create_room
      params.require(:name)

      unless current_user.staff?
        return render_json_error("Only staff can create rooms", status: 403)
      end

      room = MeetingRoom.create(
        name: params[:name],
        icon: params[:icon].presence,
        allowed_group_ids: (params[:allowed_group_ids] || []).map(&:to_i),
        created_by_id: current_user.id
      )

      render json: MeetingRoomSerializer.new(room, root: false)
    end

    def update_room
      unless current_user.staff?
        return render_json_error("Only staff can edit rooms", status: 403)
      end

      room = MeetingRoom.find(params[:id])
      return render_json_error("Room not found", status: 404) unless room

      room.name = params[:name] if params[:name].present?
      room.icon = params[:icon].presence
      room.allowed_group_ids = (params[:allowed_group_ids] || []).map(&:to_i)
      room.save

      render json: MeetingRoomSerializer.new(room, root: false)
    end

    def delete_room
      unless current_user.staff?
        return render_json_error("Only staff can delete rooms", status: 403)
      end

      room = MeetingRoom.find(params[:id])
      unless room
        return render_json_error("Room not found", status: 404)
      end

      # End the room in PlugNmeet
      PlugnmeetClient.end_room(room.id)
      
      # Delete from our store
      room.destroy

      render json: { success: true }
    end

    def webhook
      # Webhook from PlugNmeet for presence tracking
      event_type = params[:event]
      room_id = params[:room_id]
      user_id = params[:user_id]

      case event_type
      when 'user_joined'
        PluginStoreRow.create!(
          plugin_name: PLUGIN_NAME,
          key: "last_webhook",
          value: Time.now.to_s
        )
        MeetingRoom.add_participant(room_id, user_id)
        DiscourseEvent.trigger(:plugnmeet_user_joined, room_id, user_id)
      when 'user_left'
        MeetingRoom.remove_participant(room_id, user_id)
        DiscourseEvent.trigger(:plugnmeet_user_left, room_id, user_id)
      end

      render json: { success: true }
    end

    def room_presence
      room = MeetingRoom.find(params[:id])
      
      unless room
        return render_json_error("Room not found", status: 404)
      end

      unless room.user_can_access?(current_user)
        return render_json_error("Access denied", status: 403)
      end

      participants = room.participants.map do |user|
        {
          id: user.id,
          username: user.username,
          name: user.name,
          avatar_template: user.avatar_template
        }
      end

      render json: {
        room_id: room.id,
        participant_count: participants.count,
        participants: participants
      }
    end
  end
end
