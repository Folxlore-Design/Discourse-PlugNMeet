import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

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
    // Poll for presence updates every 10 seconds
    this.pollTimer = setInterval(() => {
      this.loadRooms();
    }, 10000);
  }

  @action
  async loadRooms() {
    try {
      const response = await ajax("/plugnmeet/rooms");
      this.rooms = response.rooms;
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
        // Mobile: full page redirect
        window.location.href = response.join_url;
      } else {
        // Desktop: popup window
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
          // Popup blocked, fallback to new tab
          window.open(response.join_url, '_blank');
        } else {
          // Focus the popup
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
}
