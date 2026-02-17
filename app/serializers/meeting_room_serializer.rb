# frozen_string_literal: true

module DiscoursePlugnmeet
  class MeetingRoomSerializer < ApplicationSerializer
    attributes :id, :name, :allowed_group_ids, :created_at, :participant_count, :participants

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
