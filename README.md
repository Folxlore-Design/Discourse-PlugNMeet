# Discourse PlugNmeet Integration

Integrates PlugNmeet video conferencing into Discourse with Discord-style "Meeting Rooms" in the sidebar.

## Features

- **Meeting Rooms in Sidebar** — Standalone collapsible section, separate from the Community links
- **Click to Join** — Opens video call in a popup on desktop, full redirect on mobile
- **Room Icons** — Each room gets a custom emoji icon via Discourse's emoji picker
- **Live Presence Indicators** — See participant count and who's currently in each room
- **Group-based Permissions** — Restrict rooms to specific user groups; section is hidden entirely if you have no accessible rooms
- **Full Room Management** — Create, edit (rename, change icon, change groups), and delete rooms from Admin → Plugins
- **Configurable Sidebar Title** — Rename the sidebar section from Admin → Settings
- **Lightweight** — Rooms spawn on-demand in PlugNmeet, no always-on overhead
- **Avatar Display** — See up to 5 participant avatars per room

## Prerequisites

1. **PlugNmeet Server** — A running PlugNmeet instance with an API Key and API Secret
2. **Discourse 3.3+** — Required for the sidebar section API

## Installation

### 1. Add the Plugin

The recommended approach is to declare the plugin in `app.yml` so it survives rebuilds:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/Folxlore-Design/discourse-plugnmeet.git
```

Each line under `cmd` is a separate shell command — do not omit `git clone`.

Alternatively, copy the plugin directory to the host machine at:
```
/var/discourse/shared/standalone/plugins/discourse-plugnmeet/
```

### 2. Rebuild Discourse

```bash
cd /var/discourse
./launcher rebuild app
```

Rebuilds take 5–15 minutes and bring the site down temporarily.

### 3. Configure Settings

After rebuild, go to **Admin > Settings > Plugins** and configure:

| Setting | Description |
|---|---|
| `plugnmeet_enabled` | Enable the plugin |
| `plugnmeet_server_url` | Your PlugNmeet URL (e.g., `https://meet.example.com`) |
| `plugnmeet_api_key` | API Key from PlugNmeet (stored encrypted) |
| `plugnmeet_api_secret` | API Secret from PlugNmeet (stored encrypted) |
| `plugnmeet_livekit_url` | LiveKit server URL (usually same host, port 7880) |
| `plugnmeet_sidebar_title` | Label shown on the sidebar section (default: "Meeting Rooms") |
| `plugnmeet_popup_width` | Desktop popup width in pixels (default: 1200) |
| `plugnmeet_popup_height` | Desktop popup height in pixels (default: 800) |

## Usage

### Managing Rooms

Go to **Admin > Plugins > Meeting Rooms**.

**Create a room:**
1. Click **"Create Room"**
2. Enter a room name (e.g., "General Hangout")
3. Click the emoji button to pick an icon
4. Optionally select groups to restrict access (leave empty for all users)
5. Click **"Create Room"**

**Edit a room:**
1. Click the pencil icon on any room row
2. Change name, icon, or group access
3. Click **"Save Changes"**

**Delete a room:**
- Click the trash icon on any room row and confirm

### Joining Rooms

The sidebar section only appears if you have access to at least one room.

**Desktop:** Click a room to open the video call in a popup window. You can continue browsing Discourse while in the call.

**Mobile:** Tap a room to redirect to the full-page PlugNmeet interface.

### Presence Tracking

- Green pulsing dot = people currently in the room
- Gray dot = empty room
- Shows participant count and up to 5 avatars
- Updates every 10 seconds (or in real-time with webhooks configured)

## Advanced Configuration

### Webhook Setup (Optional)

For real-time presence updates, configure PlugNmeet to send webhooks to:

```
https://your-discourse.com/plugnmeet/webhook
```

Enable events: `user_joined`, `user_left`

Without webhooks, presence falls back to 10-second polling.

### Custom Room Features

Edit `lib/plugnmeet_client.rb` to enable/disable PlugNmeet room features:

```ruby
room_features: {
  allow_webcams: true,
  mute_on_start: false,
  allow_screen_share: true,
  allow_recording: false,      # Change to true to enable
  enable_chat: true,
  enable_whiteboard: true,
  enable_breakout_room: false  # Change to true to enable
}
```

### Styling

Customise appearance in `assets/stylesheets/plugnmeet.scss`. The main classes are:

- `.meeting-rooms-sidebar` — the sidebar panel
- `.meeting-room-item` — individual room rows
- `.admin-meeting-rooms` — the admin management page

## How It Works

### Security Flow

1. User clicks room in sidebar
2. Plugin checks Discourse group membership
3. If authorised, generates a JWT token (HS256, 24-hour expiry) signed with your API secret
4. Token is passed to PlugNmeet to join the specific room
5. Presence tracked in Redis; expires after 1 hour of inactivity

### Storage

- Rooms stored in Discourse's `PluginStore` (no database migrations needed)
- Presence stored in Redis (ephemeral)
- API credentials stored encrypted via Discourse's `secret: true` setting mechanism

## Troubleshooting

### Sidebar section not appearing

- Ensure `plugnmeet_enabled` is checked in Admin → Settings
- The section is intentionally hidden if the user has no accessible rooms
- Check browser console for errors from `plugnmeet-sidebar.js`

### "Unable to configure link to 'Meeting Rooms'"

This error means the admin route isn't registered. Ensure the file `assets/javascripts/discourse/plugnmeet-route-map.js` exists in the plugin. Without it, Ember's router won't know about the admin page route.

### Rooms not appearing in sidebar

- Verify API credentials are correct (test with `rails runner plugins/discourse-plugnmeet/test_connection.rb`)
- Check that at least one room exists and the user has group access to it
- If group access was just changed, the user may need to reload

### "Access Denied" errors

- Verify the user is logged in
- Check that the room's allowed groups include at least one of the user's groups
- An empty allowed_group_ids list means accessible to all logged-in users

### Presence not updating

- Webhook not configured: presence updates every 10 seconds via polling (normal)
- Check Redis: `redis-cli ping` should return `PONG`
- Redis keys expire after 1 hour — users who close the tab without leaving may appear present until expiry

### Popup blocked

- Browser blocked the popup window
- Plugin automatically falls back to opening in a new tab
- Ask users to allow popups from your domain

### Emoji picker import error

If you see a compile error referencing `discourse/components/emoji-picker`, grep the live Discourse source to find the correct path:

```bash
sudo ./launcher enter app
grep -r "export default class EmojiPicker" /var/www/discourse/frontend --include="*.gjs" -l
```

Then update the import in `assets/javascripts/discourse/components/plugnmeet-admin-rooms.gjs`.

## Development

### File Structure

```
discourse-plugnmeet/
├── plugin.rb
├── config/
│   ├── settings.yml
│   └── locales/
│       ├── server.en.yml
│       └── client.en.yml
├── lib/
│   ├── meeting_room.rb               # Room model, PluginStore persistence, Redis presence
│   └── plugnmeet_client.rb           # PlugNmeet API client (JWT, HTTP)
├── app/
│   ├── controllers/
│   │   └── plugnmeet_controller.rb   # API endpoints
│   └── serializers/
│       └── meeting_room_serializer.rb
└── assets/
    ├── javascripts/
    │   └── discourse/
    │       ├── plugnmeet-route-map.js             # Registers admin route with Ember router
    │       ├── routes/
    │       │   └── admin-plugins-meeting-rooms.js  # Minimal route (no model hook)
    │       ├── templates/
    │       │   └── admin-plugins-meeting-rooms.hbs # Mounts the Glimmer admin component
    │       ├── components/
    │       │   ├── plugnmeet-admin-rooms.gjs       # Admin CRUD page with emoji picker
    │       │   ├── meeting-rooms-sidebar.js        # Sidebar rooms list + join logic
    │       │   └── meeting-rooms-sidebar.hbs
    │       └── initializers/
    │           └── plugnmeet-sidebar.js            # Registers sidebar section
    └── stylesheets/
        └── plugnmeet.scss
```

### API Endpoints

```
GET    /plugnmeet/rooms              List visible rooms (add ?all=1 as staff to see all)
GET    /plugnmeet/rooms/:id/join     Generate join token + mark presence
POST   /plugnmeet/rooms              Create room (staff only)
PATCH  /plugnmeet/rooms/:id          Update room name/icon/groups (staff only)
DELETE /plugnmeet/rooms/:id          Delete room and end PlugNmeet session (staff only)
POST   /plugnmeet/webhook            Presence webhook from PlugNmeet
GET    /plugnmeet/rooms/:id/presence Get participant list for a room
```

### Testing the Connection

```bash
# From the Discourse container
rails runner plugins/discourse-plugnmeet/test_connection.rb
```

### Creating Rooms via Console

```ruby
# From rails console
DiscoursePlugnmeet::MeetingRoom.create(
  name: "General Hangout",
  icon: "video",
  allowed_group_ids: [],
  created_by_id: User.first.id
)
```

## Roadmap

- [ ] Room scheduling (start/end times)
- [ ] Recording management UI
- [ ] Breakout room support
- [ ] Chat integration (PlugNmeet chat → Discourse topic)
- [ ] Waiting rooms

## License

Mozilla Public License Version 2.0

## Credits

- Powered by [PlugNmeet](https://www.plugnmeet.org/)
- Inspired by Discord's voice channels

## Support

- GitHub Issues: [Report bugs](https://github.com/Folxlore-Design/discourse-plugnmeet/issues)
- Discourse Meta: [Get help](https://meta.discourse.org)
