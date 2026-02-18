# frozen_string_literal: true

module DiscoursePlugnmeet
  class MeetingRoom
    include ActiveModel::Serialization

    attr_accessor :id, :name, :icon, :allowed_group_ids, :created_at, :created_by_id

    def self.plugin_store
      @plugin_store ||= PluginStore.new('discourse-plugnmeet')
    end

    def self.all
      rooms = plugin_store.get('meeting_rooms') || []
      rooms.map { |data| from_hash(data) }
    end

    def self.find(id)
      rooms = all
      rooms.find { |room| room.id == id }
    end

    def self.visible_to_user(user)
      return [] unless user
      user_group_ids = user.groups.pluck(:id)
      
      all.select do |room|
        # If no groups specified, visible to all
        room.allowed_group_ids.empty? || (room.allowed_group_ids & user_group_ids).any?
      end
    end

    def self.create(name:, icon: nil, allowed_group_ids:, created_by_id:)
      room = new(
        id: SecureRandom.uuid,
        name: name,
        icon: icon,
        allowed_group_ids: allowed_group_ids || [],
        created_at: Time.now,
        created_by_id: created_by_id
      )
      room.save
      room
    end

    def self.from_hash(data)
      room = new
      room.id = data['id']
      room.name = data['name']
      room.icon = data['icon']
      room.allowed_group_ids = data['allowed_group_ids'] || []
      room.created_at = data['created_at'] ? Time.parse(data['created_at']) : nil
      room.created_by_id = data['created_by_id']
      room
    end

    def initialize(id: nil, name: nil, icon: nil, allowed_group_ids: [], created_at: nil, created_by_id: nil)
      @id = id
      @name = name
      @icon = icon
      @allowed_group_ids = allowed_group_ids
      @created_at = created_at
      @created_by_id = created_by_id
    end

    def save
      rooms = self.class.all
      existing_index = rooms.find_index { |r| r.id == id }
      
      if existing_index
        rooms[existing_index] = self
      else
        rooms << self
      end

      self.class.plugin_store.set('meeting_rooms', rooms.map(&:to_hash))
    end

    def destroy
      rooms = self.class.all.reject { |r| r.id == id }
      self.class.plugin_store.set('meeting_rooms', rooms.map(&:to_hash))
      
      # Clear presence cache
      Discourse.redis.del("plugnmeet:presence:#{id}")
    end

    def to_hash
      {
        'id' => id,
        'name' => name,
        'icon' => icon,
        'allowed_group_ids' => allowed_group_ids,
        'created_at' => created_at&.iso8601,
        'created_by_id' => created_by_id
      }
    end

    def user_can_access?(user)
      return false unless user
      user_group_ids = user.groups.pluck(:id)
      allowed_group_ids.empty? || (allowed_group_ids & user_group_ids).any?
    end

    # Presence tracking
    def self.add_participant(room_id, user_id)
      key = "plugnmeet:presence:#{room_id}"
      Discourse.redis.sadd(key, user_id)
      Discourse.redis.expire(key, 1.hour.to_i)
    end

    def self.remove_participant(room_id, user_id)
      key = "plugnmeet:presence:#{room_id}"
      Discourse.redis.srem(key, user_id)
    end

    def self.participants(room_id)
      key = "plugnmeet:presence:#{room_id}"
      user_ids = Discourse.redis.smembers(key).map(&:to_i)
      User.where(id: user_ids)
    end

    def participants
      self.class.participants(id)
    end

    def participant_count
      key = "plugnmeet:presence:#{id}"
      Discourse.redis.scard(key)
    end
  end
end
