import { tracked } from "@glimmer/tracking";
import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import MeetingRoomsSidebar from "../components/meeting-rooms-sidebar";

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.plugnmeet_enabled) {
    return;
  }

  api.addSidebarSection(
    (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
      // A single link item whose contentComponent renders the full rooms panel.
      // This gives us the proper collapsible section header while keeping
      // MeetingRoomsSidebar in charge of display and click-to-join behaviour.
      const MeetingRoomsContent = class extends BaseCustomSidebarSectionLink {
        get name() {
          return "plugnmeet-rooms-content";
        }

        get text() {
          return "";
        }

        get title() {
          return "";
        }

        get contentComponent() {
          return MeetingRoomsSidebar;
        }
      };

      const MeetingRoomsSection = class extends BaseCustomSidebarSection {
        @tracked hasRooms = false;
        @tracked loaded = false;

        constructor() {
          super(...arguments);
          // One lightweight visibility check — MeetingRoomsSidebar handles
          // its own full data loading and polling separately.
          ajax("/plugnmeet/rooms")
            .then((response) => {
              this.hasRooms = (response.rooms || []).length > 0;
              this.loaded = true;
            })
            .catch(() => {
              this.loaded = true;
            });
        }

        get name() {
          return "plugnmeet-meeting-rooms";
        }

        get title() {
          // Use the outer closure variable — @service injection is unreliable
          // inside addSidebarSection classes.
          return siteSettings.plugnmeet_sidebar_title || "Meeting Rooms";
        }

        get text() {
          return this.title;
        }

        // Show while the check is in-flight; hide only if loaded with zero rooms.
        get displaySection() {
          return !this.loaded || this.hasRooms;
        }

        get hideSectionHeader() {
          return false;
        }

        get allowEmpty() {
          return true;
        }

        get sectionLinks() {
          return [new MeetingRoomsContent()];
        }
      };

      return MeetingRoomsSection;
    },
    "main"
  );
});
