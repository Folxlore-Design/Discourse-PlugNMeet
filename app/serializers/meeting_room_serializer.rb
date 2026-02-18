# frozen_string_literal: true

module DiscoursePlugnmeet
  class MeetingRoomSerializer < ApplicationSerializer
    attributes :id, :name, :icon, :allowed_group_ids, :allowed_groups, :created_at, :participant_count, :participants

    def allowed_groups
      Group.where(id: object.allowed_group_ids).map { |g| { id: g.id, name: g.name } }
    end

    def participant_count
      object.participant_count
    end

    def participants
      object.participants.limit(5).map do |user|
        {
          id: user.id,
          username: user.username,
          avatar_template: user.avatar_template
        }
      end
    end
  end
end
