import { apiInitializer } from "discourse/lib/api";
import MeetingRoomsSidebar from "../components/meeting-rooms-sidebar";

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  
  if (!siteSettings.plugnmeet_enabled) {
    return;
  }

  // Add meeting rooms section to sidebar
  api.addCommunitySectionLink((baseSectionLink) => {
    return class extends baseSectionLink {
      get name() {
        return "meeting-rooms";
      }

      get route() {
        return "discovery.latest";
      }

      get title() {
        return "Meeting Rooms";
      }

      get text() {
        return "Meeting Rooms";
      }

      get prefixType() {
        return "icon";
      }

      get prefixValue() {
        return "video";
      }

      get contentComponent() {
        return MeetingRoomsSidebar;
      }

      get displaySection() {
        return true;
      }
    };
  });
});
