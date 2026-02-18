import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { fn, concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "truth-helpers";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { avatarUrl } from "discourse/lib/utilities";
import replaceEmoji from "discourse/helpers/replace-emoji";

export default class MeetingRoomsSidebar extends Component {
  @service siteSettings;
  @service capabilities;
  @tracked rooms = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.loadRooms();
    this.startPolling();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
    }
  }

  startPolling() {
    this.pollTimer = setInterval(() => {
      this.loadRooms();
    }, 10000);
  }

  @action
  async loadRooms() {
    try {
      const response = await ajax("/plugnmeet/rooms");
      this.rooms = response.rooms || [];
      this.loading = false;
    } catch (error) {
      popupAjaxError(error);
      this.loading = false;
    }
  }

  @action
  async joinRoom(room) {
    try {
      const response = await ajax(`/plugnmeet/rooms/${room.id}/join`);

      if (this.capabilities.isIOS || this.capabilities.isAndroid) {
        window.location.href = response.join_url;
      } else {
        const width = this.siteSettings.plugnmeet_popup_width;
        const height = this.siteSettings.plugnmeet_popup_height;
        const left = (screen.width - width) / 2;
        const top = (screen.height - height) / 2;

        const windowFeatures = `width=${width},height=${height},left=${left},top=${top},toolbar=no,menubar=no,scrollbars=yes,resizable=yes`;

        const popup = window.open(
          response.join_url,
          `plugnmeet_${room.id}`,
          windowFeatures
        );

        if (!popup) {
          window.open(response.join_url, "_blank");
        } else {
          popup.focus();
        }
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get hasRooms() {
    return this.rooms && this.rooms.length > 0;
  }

  <template>
    <div class="meeting-rooms-sidebar">
      {{#if this.loading}}
        <div class="meeting-rooms-loading">
          <div class="spinner small"></div>
          <span>{{i18n "plugnmeet.loading"}}</span>
        </div>
      {{else if this.hasRooms}}
        <div class="meeting-rooms-list">
          {{#each this.rooms as |room|}}
            <div class="meeting-room-item" {{on "click" (fn this.joinRoom room)}}>
              {{#if room.icon}}
                <span class="meeting-room-icon">
                  {{replaceEmoji (concat ":" room.icon ":")}}
                </span>
              {{/if}}
              <div class="meeting-room-info">
                <div class="meeting-room-name">
                  {{room.name}}
                </div>
                {{#if room.participant_count}}
                  <div class="meeting-room-presence">
                    <span class="presence-indicator active"></span>
                    <span class="participant-count">
                      {{room.participant_count}}
                      {{#if (eq room.participant_count 1)}}
                        {{i18n "plugnmeet.person"}}
                      {{else}}
                        {{i18n "plugnmeet.people"}}
                      {{/if}}
                    </span>
                  </div>
                {{else}}
                  <div class="meeting-room-presence">
                    <span class="presence-indicator"></span>
                    <span class="participant-count">
                      {{i18n "plugnmeet.empty"}}
                    </span>
                  </div>
                {{/if}}
              </div>

              {{#if room.participants.length}}
                <div class="meeting-room-avatars">
                  {{#each room.participants as |participant|}}
                    <img
                      src={{avatarUrl participant.avatar_template "small"}}
                      alt={{participant.username}}
                      title={{participant.username}}
                      class="meeting-room-avatar"
                    />
                  {{/each}}
                </div>
              {{/if}}
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="meeting-rooms-empty">
          <p>{{i18n "plugnmeet.no_rooms"}}</p>
        </div>
      {{/if}}
    </div>
  </template>
}
