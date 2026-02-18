import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { fn, concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { not } from "truth-helpers";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import replaceEmoji from "discourse/helpers/replace-emoji";
import GroupChooser from "select-kit/components/group-chooser";
// NOTE: If EmojiPicker import fails, grep Discourse source for the correct path:
// grep -r "class EmojiPicker" /var/www/discourse/frontend --include="*.gjs" -l
import EmojiPicker from "discourse/components/emoji-picker";

export default class PlugnmeetAdminRooms extends Component {
  @service site;

  @tracked rooms = [];
  @tracked loading = true;

  @tracked showModal = false;
  @tracked editingRoom = null;

  @tracked formName = "";
  @tracked formIcon = "";
  @tracked formGroupIds = [];
  @tracked showEmojiPicker = false;

  constructor() {
    super(...arguments);
    this.loadRooms();
  }

  async loadRooms() {
    try {
      const response = await ajax("/plugnmeet/rooms?all=1");
      this.rooms = response.rooms || [];
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  openCreate() {
    this.editingRoom = null;
    this.formName = "";
    this.formIcon = "";
    this.formGroupIds = [];
    this.showModal = true;
    this.showEmojiPicker = false;
  }

  @action
  openEdit(room) {
    this.editingRoom = room;
    this.formName = room.name;
    this.formIcon = room.icon || "";
    this.formGroupIds = [...(room.allowed_group_ids || [])];
    this.showModal = true;
    this.showEmojiPicker = false;
  }

  @action
  closeModal() {
    this.showModal = false;
    this.editingRoom = null;
    this.showEmojiPicker = false;
  }

  @action
  async saveRoom() {
    try {
      const data = {
        name: this.formName,
        icon: this.formIcon || null,
        allowed_group_ids: this.formGroupIds,
      };

      if (this.editingRoom) {
        const response = await ajax(`/plugnmeet/rooms/${this.editingRoom.id}`, {
          type: "PATCH",
          data,
        });
        this.rooms = this.rooms.map((r) =>
          r.id === this.editingRoom.id ? response : r
        );
      } else {
        const response = await ajax("/plugnmeet/rooms", {
          type: "POST",
          data,
        });
        this.rooms = [...this.rooms, response];
      }

      this.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async deleteRoom(room) {
    if (
      !window.confirm(
        i18n("plugnmeet.admin.confirm_delete", { name: room.name })
      )
    ) {
      return;
    }

    try {
      await ajax(`/plugnmeet/rooms/${room.id}`, { type: "DELETE" });
      this.rooms = this.rooms.filter((r) => r.id !== room.id);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  onEmojiSelected(emoji) {
    this.formIcon = emoji;
    this.showEmojiPicker = false;
  }

  @action
  toggleEmojiPicker() {
    this.showEmojiPicker = !this.showEmojiPicker;
  }

  @action
  updateFormName(event) {
    this.formName = event.target.value;
  }

  @action
  updateGroups(groupIds) {
    this.formGroupIds = groupIds;
  }

  <template>
    <div class="admin-meeting-rooms">
      <div class="admin-meeting-rooms-header">
        <h2>{{i18n "plugnmeet.admin.title"}}</h2>
        <DButton
          @action={{this.openCreate}}
          @label="plugnmeet.admin.create_room"
          @icon="plus"
          class="btn-primary"
        />
      </div>

      {{#if this.loading}}
        <div class="loading-container">
          <div class="spinner large"></div>
        </div>
      {{else if this.rooms.length}}
        <table class="meeting-rooms-table">
          <thead>
            <tr>
              <th>{{i18n "plugnmeet.admin.room_icon"}}</th>
              <th>{{i18n "plugnmeet.admin.room_name"}}</th>
              <th>{{i18n "plugnmeet.admin.allowed_groups"}}</th>
              <th>{{i18n "plugnmeet.admin.participants"}}</th>
              <th>{{i18n "plugnmeet.admin.created"}}</th>
              <th>{{i18n "plugnmeet.admin.actions"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.rooms as |room|}}
              <tr>
                <td class="room-icon-cell">
                  {{#if room.icon}}
                    <span class="room-icon-preview">
                      {{replaceEmoji (concat ":" room.icon ":")}}
                    </span>
                  {{else}}
                    <span class="no-icon">—</span>
                  {{/if}}
                </td>
                <td>
                  <strong>{{room.name}}</strong>
                </td>
                <td>
                  {{#if room.allowed_group_ids.length}}
                    {{#each room.allowed_group_ids as |gid|}}
                      <span class="badge-group">{{gid}}</span>
                    {{/each}}
                  {{else}}
                    <em>{{i18n "plugnmeet.admin.all_users"}}</em>
                  {{/if}}
                </td>
                <td>{{room.participant_count}}</td>
                <td>{{room.created_at}}</td>
                <td class="room-actions">
                  <DButton
                    @action={{fn this.openEdit room}}
                    @icon="pencil-alt"
                    @title="plugnmeet.admin.edit_room"
                    class="btn-default btn-small"
                  />
                  <DButton
                    @action={{fn this.deleteRoom room}}
                    @icon="trash-alt"
                    @title="plugnmeet.admin.delete_room"
                    class="btn-danger btn-small"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <div class="admin-meeting-rooms-empty">
          <p>{{i18n "plugnmeet.admin.no_rooms_yet"}}</p>
          <p>{{i18n "plugnmeet.admin.create_first_room"}}</p>
        </div>
      {{/if}}

      {{#if this.showModal}}
        <DModal
          @closeModal={{this.closeModal}}
          @title={{if
            this.editingRoom
            (i18n "plugnmeet.admin.edit_room_modal_title")
            (i18n "plugnmeet.admin.create_room_modal_title")
          }}
        >
          <:body>
            <div class="create-room-form">
              <div class="control-group">
                <label>{{i18n "plugnmeet.admin.room_name_label"}}</label>
                <input
                  type="text"
                  value={{this.formName}}
                  placeholder={{i18n "plugnmeet.admin.room_name_placeholder"}}
                  class="room-name-input"
                  {{on "input" this.updateFormName}}
                />
              </div>

              <div class="control-group">
                <label>{{i18n "plugnmeet.admin.room_icon_label"}}</label>
                <div class="room-icon-selector">
                  <button
                    type="button"
                    class="btn btn-default emoji-trigger"
                    {{on "click" this.toggleEmojiPicker}}
                  >
                    {{#if this.formIcon}}
                      {{replaceEmoji (concat ":" this.formIcon ":")}}
                      <span class="emoji-name">{{this.formIcon}}</span>
                    {{else}}
                      {{i18n "plugnmeet.admin.choose_icon"}}
                    {{/if}}
                  </button>
                  {{#if this.showEmojiPicker}}
                    <EmojiPicker
                      @isActive={{this.showEmojiPicker}}
                      @emojiSelected={{this.onEmojiSelected}}
                      @onClose={{this.toggleEmojiPicker}}
                    />
                  {{/if}}
                </div>
              </div>

              <div class="control-group">
                <label>{{i18n "plugnmeet.admin.allowed_groups_label"}}</label>
                <p class="help-text">
                  {{i18n "plugnmeet.admin.allowed_groups_help"}}
                </p>
                <GroupChooser
                  @content={{this.site.groups}}
                  @value={{this.formGroupIds}}
                  @onChange={{this.updateGroups}}
                />
              </div>
            </div>
          </:body>
          <:footer>
            <DButton
              @action={{this.saveRoom}}
              @label={{if
                this.editingRoom
                "plugnmeet.admin.save"
                "plugnmeet.admin.create"
              }}
              @icon={{if this.editingRoom "check" "plus"}}
              @disabled={{not this.formName}}
              class="btn-primary"
            />
            <DButton
              @action={{this.closeModal}}
              @label="cancel"
              class="btn-default"
            />
          </:footer>
        </DModal>
      {{/if}}
    </div>
  </template>
}
