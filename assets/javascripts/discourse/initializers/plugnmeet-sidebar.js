import { apiInitializer } from "discourse/lib/api";
import MeetingRoomsSidebar from "../components/meeting-rooms-sidebar";

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.plugnmeet_enabled) {
    return;
  }

  api.addSidebarSection(
    (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
      // A single link item whose contentComponent renders the full rooms panel.
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
        get name() {
          return "plugnmeet-meeting-rooms";
        }

        get title() {
          return siteSettings.plugnmeet_sidebar_title || "Meeting Rooms";
        }

        get text() {
          return this.title;
        }

        // Always show — MeetingRoomsSidebar handles its own loading/empty state.
        get displaySection() {
          return true;
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
