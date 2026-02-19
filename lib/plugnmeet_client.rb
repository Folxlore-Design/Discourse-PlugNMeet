# frozen_string_literal: true

require 'net/http'
require 'json'
require 'openssl'

module DiscoursePlugnmeet
  class PlugnmeetClient
    class << self
      def create_room(room_id, room_name)
        payload = {
          room_id: room_id,
          metadata: {
            room_title: room_name,
            welcome_message: "Welcome to #{room_name}",
            max_participants: 0, # 0 = unlimited
            enable_analytics: false,
            room_features: {
              allow_webcams: true,
              mute_on_start: false,
              allow_screen_share: true,
              allow_recording: false,
              allow_rtmp: false,
              admin_only_webcams: false,
              allow_view_other_webcams: true,
              allow_view_other_users_list: true,
              enable_chat: true,
              enable_shared_note_pad: true,
              enable_whiteboard: true,
              enable_breakout_room: false
            }
          }
        }

        response = make_request('/auth/room/create', payload)
        
        if response['status']
          { success: true, room_id: room_id }
        else
          { success: false, error: response['msg'] || 'Unknown error' }
        end
      end

      def generate_join_token(room_id, user_name, user_id, is_admin: false)
        payload = {
          room_id: room_id,
          user_info: {
            name: user_name,
            user_id: user_id.to_s,
            is_admin: is_admin,
            is_hidden: false
          }
        }

        response = make_request('/auth/room/getJoinToken', payload)

        if response['status']
          token = response['token']
          join_url = "#{server_url}/?access_token=#{token}"
          { success: true, token: token, join_url: join_url }
        else
          { success: false, error: response['msg'] || 'Unknown error' }
        end
      rescue => e
        { success: false, error: e.message }
      end

      def end_room(room_id)
        payload = { room_id: room_id }
        response = make_request('/auth/room/end', payload)
        
        { success: response['status'] == true }
      end

      def is_room_active?(room_id)
        payload = { room_ids: [room_id] }
        response = make_request('/auth/room/getActiveRoomInfo', payload)
        
        response['status'] && response['result']&.any?
      end

      private

      def make_request(endpoint, payload)
        uri = URI("#{server_url}#{endpoint}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'

        body = payload.to_json
        signature = OpenSSL::HMAC.hexdigest('SHA256', api_secret, body)

        request = Net::HTTP::Post.new(uri.path)
        request['Content-Type'] = 'application/json'
        request['API-KEY'] = api_key
        request['HASH-SIGNATURE'] = signature
        request.body = body

        response = http.request(request)
        JSON.parse(response.body)
      rescue => e
        Rails.logger.error("PlugNmeet API error: #{e.message}")
        { 'status' => false, 'msg' => e.message }
      end

      def server_url
        SiteSetting.plugnmeet_server_url
      end

      def api_key
        SiteSetting.plugnmeet_api_key
      end

      def api_secret
        SiteSetting.plugnmeet_api_secret
      end
    end
  end
end
