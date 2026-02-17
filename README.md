# Discourse PlugNmeet Integration

Integrates PlugNmeet video conferencing into Discourse with Discord-style "Meeting Rooms" in the sidebar.

## Features

- 🎥 **Meeting Rooms in Sidebar** - Click to join video calls directly from Discourse
- 👥 **Live Presence Indicators** - See who's currently in each room
- 🔒 **Group-based Permissions** - Restrict rooms to specific user groups
- 📱 **Mobile Responsive** - Full-page redirect on mobile, popup window on desktop
- ⚡ **Lightweight** - Rooms spawn on-demand, no always-on overhead
- 🎨 **Avatar Display** - See up to 5 participant avatars per room

## Prerequisites

1. **PlugNmeet Server** - You need a running PlugNmeet instance
   - Get your API Key and API Secret from PlugNmeet
   - Note your server URL (e.g., `https://meet.example.com`)

2. **Discourse** - Version 2.8+ recommended

## Installation

### 1. Add the Plugin

SSH into your Discourse server and add the plugin to your `app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/yourusername/discourse-plugnmeet.git
```

### 2. Rebuild Discourse

```bash
cd /var/discourse
./launcher rebuild app
```

### 3. Configure Settings

After rebuild, go to **Admin > Settings > Plugins** and configure:

- **plugnmeet_enabled**: Enable the plugin ✅
- **plugnmeet_server_url**: Your PlugNmeet URL (e.g., `https://meet.example.com`)
- **plugnmeet_api_key**: Your API Key from PlugNmeet
- **plugnmeet_api_secret**: Your API Secret from PlugNmeet
- **plugnmeet_popup_width**: Desktop popup width (default: 1200px)
- **plugnmeet_popup_height**: Desktop popup height (default: 800px)

## Usage

### Creating Meeting Rooms

1. Go to **Admin > Plugins > Meeting Rooms**
2. Click **"Create Room"**
3. Enter a room name (e.g., "General Hangout")
4. Optionally select groups to restrict access
5. Click **"Create Room"**

### Joining Rooms

**Desktop:**
- Click any room in the "Meeting Rooms" sidebar section
- Opens in a popup window
- Continue browsing Discourse while in the call

**Mobile:**
- Tap any room in the sidebar
- Redirects to full-page PlugNmeet interface

### Presence Tracking

- Green dot = People currently in room
- Gray dot = Empty room
- Shows participant count and avatars (up to 5)
- Updates every 10 seconds

## How It Works

### Room Management

- Rooms are stored in Discourse's PluginStore (no database migrations needed)
- Permissions leverage Discourse's existing group system
- PlugNmeet rooms spawn on first join, reducing resource usage

### Security Flow

1. User clicks room in sidebar
2. Plugin checks Discourse permissions (group membership)
3. If authorized, generates JWT token with user's Discourse username
4. Token allows join to specific PlugNmeet room
5. Presence tracked via Redis for real-time updates

### Mobile vs Desktop

```javascript
// Auto-detects platform
if (mobile) {
  window.location.href = joinUrl;  // Full redirect
} else {
  window.open(joinUrl, 'popup', features);  // Popup window
}
```

## Advanced Configuration

### Webhook Setup (Optional)

For real-time presence updates from PlugNmeet:

1. In PlugNmeet admin, set webhook URL to:
   ```
   https://your-discourse.com/plugnmeet/webhook
   ```

2. Configure events:
   - `user_joined`
   - `user_left`

Without webhooks, presence updates rely on polling (10-second intervals).

### Custom Room Features

Edit `lib/plugnmeet_client.rb` to customize room features:

```ruby
room_features: {
  allow_webcams: true,
  mute_on_start: false,
  allow_screen_share: true,
  allow_recording: false,        # Change to true to enable
  enable_chat: true,
  enable_whiteboard: true,
  enable_breakout_room: false    # Change to true to enable
}
```

### Styling

Customize appearance in `assets/stylesheets/plugnmeet.scss`:

```scss
.meeting-room-item {
  // Your custom styles
  background: var(--tertiary-low);
  border-left: 3px solid var(--tertiary);
}
```

## Troubleshooting

### Rooms not appearing

- Check **Admin > Settings > Plugins** - ensure `plugnmeet_enabled` is checked
- Verify API credentials are correct
- Check browser console for errors

### "Access Denied" errors

- Verify user is logged in
- Check room's allowed_group_ids includes user's groups
- Empty allowed_group_ids = accessible to all users

### Presence not updating

- Webhook not configured: Presence updates every 10 seconds via polling
- Check Redis is running: `redis-cli ping` should return `PONG`
- Verify PlugNmeet webhook points to `/plugnmeet/webhook`

### Popup blocked

- Browser blocked popup window
- Plugin automatically falls back to new tab
- User should allow popups from your domain

## Development

### File Structure

```
discourse-plugnmeet/
├── plugin.rb                          # Main plugin definition
├── config/
│   ├── settings.yml                   # Plugin settings
│   └── locales/
│       ├── server.en.yml             # Server translations
│       └── client.en.yml             # Client translations
├── lib/
│   ├── meeting_room.rb               # Room model & permissions
│   └── plugnmeet_client.rb           # PlugNmeet API wrapper
├── app/
│   ├── controllers/
│   │   └── plugnmeet_controller.rb   # API endpoints
│   └── serializers/
│       └── meeting_room_serializer.rb
└── assets/
    ├── javascripts/
    │   └── discourse/
    │       ├── components/
    │       │   └── meeting-rooms-sidebar.js
    │       ├── initializers/
    │       │   └── plugnmeet-sidebar.js
    │       └── routes/
    │           └── admin-plugins-meeting-rooms.js
    └── stylesheets/
        └── plugnmeet.scss
```

### API Endpoints

```
GET    /plugnmeet/rooms              # List all visible rooms
GET    /plugnmeet/rooms/:id/join     # Generate join token
POST   /plugnmeet/rooms              # Create room (staff only)
DELETE /plugnmeet/rooms/:id          # Delete room (staff only)
POST   /plugnmeet/webhook            # Webhook handler
GET    /plugnmeet/rooms/:id/presence # Get participants
```

### Testing

```ruby
# In Rails console
PlugNmeet::MeetingRoom.create(
  name: "Test Room",
  allowed_group_ids: [],
  created_by_id: User.first.id
)
```

## Roadmap

- [ ] Room scheduling (start/end times)
- [ ] Recording management UI
- [ ] Breakout room support
- [ ] Chat integration (PlugNmeet chat → Discourse topic)
- [ ] Calendar integration
- [ ] Waiting rooms

## License

Mozilla Public License Version 2.0

## Credits

- Built for Discourse
- Powered by PlugNmeet
- Inspired by Discord's voice channels

## Support

- GitHub Issues: [Report bugs](https://github.com/yourusername/discourse-plugnmeet/issues)
- Discourse Meta: [Get help](https://meta.discourse.org)
