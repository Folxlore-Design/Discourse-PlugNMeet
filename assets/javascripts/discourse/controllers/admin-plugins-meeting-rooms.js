import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsMeetingRoomsController extends Controller {
  @tracked showCreateModal = false;
  @tracked newRoomName = "";
  @tracked selectedGroupIds = [];

  @action
  openCreateModal() {
    this.showCreateModal = true;
    this.newRoomName = "";
    this.selectedGroupIds = [];
  }

  @action
  closeCreateModal() {
    this.showCreateModal = false;
  }

  @action
  async createRoom() {
    try {
      const response = await ajax("/plugnmeet/rooms", {
        type: "POST",
        data: {
          name: this.newRoomName,
          allowed_group_ids: this.selectedGroupIds,
        },
      });

      this.model.rooms.pushObject(response);
      this.closeCreateModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async deleteRoom(room) {
    if (!confirm(`Are you sure you want to delete "${room.name}"?`)) {
      return;
    }

    try {
      await ajax(`/plugnmeet/rooms/${room.id}`, {
        type: "DELETE",
      });

      this.model.rooms.removeObject(room);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  updateSelectedGroups(groupIds) {
    this.selectedGroupIds = groupIds;
  }
}
