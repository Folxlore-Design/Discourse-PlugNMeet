import { tracked } from "@glimmer/tracking";
import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.plugnmeet_enabled) {
    return;
  }

  const capabilities = api.container.lookup("service:capabilities");

  async function joinRoom(roomId) {
    try {
      const response = await ajax(`/plugnmeet/rooms/${roomId}/join`);
      if (capabilities.isIOS || capabilities.isAndroid) {
        window.location.href = response.join_url;
      } else {
        const w = siteSettings.plugnmeet_popup_width || 1200;
        const h = siteSettings.plugnmeet_popup_height || 800;
        const l = (screen.width - w) / 2;
        const t = (screen.height - h) / 2;
        const features = `width=${w},height=${h},left=${l},top=${t},toolbar=no,menubar=no,scrollbars=yes,resizable=yes`;
        const popup = window.open(
          response.join_url,
          `plugnmeet_${roomId}`,
          features
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

  api.addSidebarSection(
    (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
      const MeetingRoomsSection = class extends BaseCustomSidebarSection {
        @tracked rooms = [];

        constructor() {
          super(...arguments);
          console.log("[PlugNmeet] MeetingRoomsSection constructor called");
          ajax("/plugnmeet/rooms")
            .then((r) => {
              console.log("[PlugNmeet] AJAX success, raw response:", r);
              console.log("[PlugNmeet] rooms array:", r.rooms);
              this.rooms = r.rooms || [];
              console.log("[PlugNmeet] this.rooms set, length:", this.rooms.length);
            })
            .catch((err) => {
              console.error("[PlugNmeet] AJAX failed:", err);
            });
        }

        get name() {
          return "plugnmeet-meeting-rooms";
        }

        get title() {
          return siteSettings.plugnmeet_sidebar_title || "Meeting Rooms";
        }

        get text() {
          return this.title;
        }

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
          console.log("[PlugNmeet] sectionLinks getter called, rooms.length:", this.rooms.length);
          return this.rooms.map((room) => {
            // Each room gets a unique fragment href so we can identify it on click.
            const SectionLink = class extends BaseCustomSidebarSectionLink {
              get name() {
                return `plugnmeet-room-${room.id}`;
              }

              get text() {
                return room.name;
              }

              get title() {
                return room.name;
              }

              // Fragment href — navigation is intercepted below via capture listener.
              get href() {
                return `#plugnmeet-room-${room.id}`;
              }
            };
            return new SectionLink();
          });
        }
      };

      return MeetingRoomsSection;
    },
    "main"
  );

  // Intercept clicks on room links (capture phase, before Discourse's router).
  // We use the literal href attribute value, not the resolved anchor.href property.
  document.addEventListener(
    "click",
    (e) => {
      const anchor = e.target.closest("a[href^='#plugnmeet-room-']");
      if (!anchor) {
        return;
      }
      e.preventDefault();
      const roomId = anchor
        .getAttribute("href")
        .replace("#plugnmeet-room-", "");
      joinRoom(roomId);
    },
    true // capture
  );
});
