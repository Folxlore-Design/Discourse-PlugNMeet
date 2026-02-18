# discourse-discordify — Project Context for Claude

This is a Discourse theme component that transforms Discourse into a Discord-like experience for small, invite-only communities. The live instance is at `coven.folxlore.net`.

## Purpose & Design Philosophy

The component does two main things:

1. **Category → Topic Redirect** — When a user navigates to a category page, they are redirected to the pinned topic whose title matches the category name (case-insensitive). This makes categories feel like "spaces" or "channels" rather than topic lists. Works for all users including admins.

2. **Admin Toolbar** — A compact toolbar rendered above the post stream on topic pages, right-aligned. Visible to all logged-in users (category switcher + notification button). The settings wrench is admin/mod only.

### Design Decisions Made

- Categories are "spaces" — each has exactly one pinned topic with the same name. Users never see the category list page.
- All categories use emoji (not uploaded icons). The emoji field on the category model is a plain string like `"hammer_and_wrench"` (no colons).
- `site.categories` is already filtered to categories the current user can access — no additional filtering needed.
- CSS is in `common/common.scss` (applies to desktop + mobile). Do NOT use `stylesheets/` — Discourse ignores that path.
- Console logs are included by default during development. Strip before production release.
- The component CSS field in the Discourse admin dashboard overrides the file — use the file, not the field, for maintainability.

---

## File Structure

```
discourse-discordify/
├── about.json                          # Must include "component": true
├── CLAUDE.md                           # This file
├── common/
│   └── common.scss                     # All styles (desktop + mobile)
└── javascripts/
    └── discourse/
        ├── api-initializers/
        │   └── category-topic-links.js # Route modification + outlet registration
        └── components/
            └── category-admin-toolbar.gjs  # Glimmer component for toolbar
```

---

## Confirmed Working Import Paths

These were verified against the actual Discourse source on the live server. Do not guess alternatives — import paths are a frequent source of compile errors.

```javascript
// Ember / Glimmer core
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { on } from "@ember/modifier";          // modifier — NOT @ember/helper
import { fn, concat } from "@ember/helper";    // helpers — NOT @ember/modifier
import { eq } from "truth-helpers";            // also: and, or, not, gt, lt etc.

// Discourse
import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/components/d-button";
import DMenu from "discourse/float-kit/components/d-menu";
import replaceEmoji from "discourse/helpers/replace-emoji";
import TopicNotificationsTracking from "discourse/components/topic-notifications-tracking";
```

### Import Paths That Do NOT Exist (do not use)
- `discourse/components/category-badge` — doesn't exist, it's a helper
- `discourse-common/components/d-icon` — wrong path
- `discourse/components/d-icon` — also wrong; use DButton with @icon instead

### Rendering an Icon
Always use `DButton` with `@icon`:
```hbs
<DButton @icon="wrench" @action={{this.someAction}} class="btn-flat" />
```

---

## Glimmer / .gjs Strict Mode Rules

Discourse uses strict mode `.gjs` files. Every helper, modifier, and component used in the template **must be explicitly imported** at the top of the file. There are no ambient globals.

Common mistakes:
- Using `{{on}}` without `import { on } from "@ember/modifier"` → compile error
- Using `{{fn}}` without `import { fn } from "@ember/helper"` → compile error
- Using `{{eq}}` without `import { eq } from "truth-helpers"` → compile error

---

## Outlet Names

| Outlet | Location | outletArgs |
|--------|----------|------------|
| `topic-above-post-stream` | Above the post stream, below topic title | `model` = topic |
| `topic-above-posts` | **Wrong** — renders once per post, do not use for topic-level UI |
| `topic-title` | Inside the title area | — |

Use `api.renderInOutlet("topic-above-post-stream", MyComponent)` in the initializer.

Access the topic in the component via:
```javascript
get topic() {
  return this.args.outletArgs?.model;
}
```

---

## Category Model Fields

Useful fields on a Discourse category object:

```javascript
cat.id
cat.name           // e.g. "The Workshop"
cat.slug           // e.g. "the-workshop"
cat.emoji          // e.g. "hammer_and_wrench" (plain string, no colons)
cat.parentCategory // parent category object, or undefined if top-level
cat.parent_category_id // numeric ID of parent, or null
```

### Rendering Emoji
```hbs
{{replaceEmoji (concat ":" cat.emoji ":")}}
```

### Building Category Settings URL (handles subcategories)
```javascript
get settingsUrl() {
  const cat = this.currentCategory;
  if (!cat) return null;
  const parent = cat.parentCategory;
  const slug = parent
    ? `${parent.slug}/${cat.slug}`
    : cat.slug;
  return `/c/${slug}/edit/general`;
}
```
Note: subcategory settings URLs are structured as `/c/parent-slug/child-slug/edit/general`. Forgetting the parent slug silently navigates to the wrong page.

---

## Topic Model Fields

```javascript
topic.title
topic.category
topic.details.notification_level        // integer: 0=muted, 1=normal, 2=tracking, 3=watching
topic.details.updateNotifications(id)   // async method to change notification level (NOT topic.setNotificationLevel — that doesn't exist)
```

---

## Notification Tracking Component

The `TopicNotificationsTracking` component renders the full notification level picker (Watching / Tracking / Normal / Muted) as a DMenu dropdown.

```hbs
<TopicNotificationsTracking
  @topic={{this.topic}}
  @levelId={{this.notificationLevel}}
  @onChange={{this.onNotificationChange}}
  @showFullTitle={{false}}
  @showCaret={{false}}
/>
```

`@showFullTitle={{false}}` = icon only in the trigger button (no text label).

---

## DMenu Usage Pattern

```hbs
<DMenu
  @identifier="unique-identifier"
  @modalForMobile={{true}}
  @triggerClass="btn-default btn-icon my-trigger-btn"
>
  <:trigger>
    {{! trigger button content }}
  </:trigger>
  <:content as |content|>
    <div class="fk-d-menu__inner-content">
      <ul class="dropdown-menu">
        <li class="dropdown-menu__item">
          <button
            class="btn no-text"
            type="button"
            {{on "click" (fn this.myAction item content.close)}}
          >
            ...
          </button>
        </li>
      </ul>
    </div>
  </:content>
</DMenu>
```

`content.close` is passed as a function to item actions so the menu closes on selection.

---

## CSS Selectors for Hidden Elements

These elements are hidden via `common/common.scss`:

```scss
// Pin/unpin button in topic footer
#topic-footer-buttons .pinned-button { display: none; }

// Notification button in topic footer
#topic-footer-buttons .topic-notifications-button { display: none; }

// Notification button in timeline sidebar
.timeline-footer-controls .topic-notifications-button { display: none; }
```

---

## Category Landing Page Detection

In `api-initializers/category-topic-links.js`, `api.onPageChange` adds the class `is-category-landing` to `#topic-title` when the topic title matches the category name:

```javascript
api.onPageChange(() => {
  const topicTitle = document.querySelector("#topic-title");
  if (!topicTitle) return;
  const fancyTitle = document.querySelector(".fancy-title")?.textContent?.trim().toLowerCase();
  const categoryName = document.querySelector(".badge-category__name")?.textContent?.trim().toLowerCase();
  if (fancyTitle && categoryName && fancyTitle === categoryName) {
    topicTitle.classList.add("is-category-landing");
  } else {
    topicTitle.classList.remove("is-category-landing");
  }
});
```

This is used in CSS to promote the category badge to h1 and hide the redundant topic title.

---

## Packaging

The component is distributed as a `.zip` file uploaded via Admin → Customize → Themes → Install → From your device.

The zip must contain the folder itself (not just its contents):
```
category-topic-links.zip
└── category-topic-links/
    ├── about.json
    ├── common/common.scss
    └── javascripts/...
```

`about.json` minimum required content:
```json
{
  "name": "Category > Topic Links",
  "about_url": null,
  "license_url": null,
  "component": true
}
```

Each upload creates a new theme version number in Discourse (increments with each install). Keep this in mind when reading console errors — the theme number in error messages will change.

---

## Server Info

- **Platform**: DigitalOcean droplet, Docker Compose, Nginx reverse proxy
- **Discourse container**: standard `app` container via `./launcher`
- **Enter container**: `sudo ./launcher enter app` from `/var/discourse`
- **Discourse source inside container**: `/var/www/discourse/` (does not exist — source is on host)
- **Discourse source on host**: `/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/75/fs/var/www/discourse/frontend/discourse/app/`
- **Useful grep**: `grep -r "thing-to-find" [above path] --include="*.gjs" --include="*.hbs" -l`

---

## Known Gotchas

1. **`topic-above-posts` vs `topic-above-post-stream`** — the former renders inside the post loop (once per post). Always use the latter for topic-level UI.
2. **Stylesheet path** — must be `common/common.scss`, not `stylesheets/anything.scss`.
3. **Subcategory settings URLs** — must include parent slug: `/c/parent/child/edit/general`.
4. **`parentCategory` availability** — `cat.parentCategory` returns the full parent object. If it ever returns undefined, fall back to looking up `cat.parent_category_id` in `this.site.categories`.
5. **`on` and `fn` import confusion** — `on` is from `@ember/modifier`, `fn` is from `@ember/helper`. Easy to mix up.
6. **Each zip upload increments the theme ID** — error messages reference the theme by number, so the number in console errors will change with each reinstall.
7. **`component: true` in about.json** — without this, Discourse treats it as a full theme, not a component.

---

## Plugin Development (discourse-plugnmeet)

This section covers learnings from building `discourse-plugnmeet`, a full Discourse plugin (not a theme component). Plugins differ significantly from theme components in structure, deployment, and capabilities.

### Plugin vs Theme Component

| | Theme Component | Plugin |
|---|---|---|
| Installed via | Admin → Customize → Themes | Server filesystem or app.yml |
| Backend (Ruby) | ❌ No | ✅ Yes |
| Custom DB/storage | ❌ No | ✅ Yes (PluginStore) |
| Custom routes | ❌ No | ✅ Yes |
| Rebuild required | ❌ No | ✅ Yes |
| Settings in Admin UI | Limited | ✅ Full settings.yml |

### Plugin File Structure

```
discourse-plugnmeet/
├── plugin.rb                          # Required — main entry point
├── config/
│   ├── settings.yml                   # Plugin settings (appear in Admin > Settings)
│   └── locales/
│       ├── server.en.yml             # Server-side i18n strings
│       └── client.en.yml             # Client-side i18n strings
├── lib/                               # Ruby library files (require_relative'd in plugin.rb)
├── app/
│   ├── controllers/                   # Rails controllers
│   └── serializers/                   # ActiveModel serializers
└── assets/
    ├── javascripts/
    │   └── discourse/
    │       ├── plugnmeet-route-map.js # Admin route registration (required for add_admin_route)
    │       ├── components/            # .js + .hbs pairs (or self-contained .gjs)
    │       ├── initializers/          # api initializers
    │       ├── routes/                # Ember routes (minimal — components own their data)
    │       └── templates/             # .hbs templates (thin shells that mount .gjs components)
    └── stylesheets/                   # .scss files (register in plugin.rb)
```

Note: Unlike theme components, plugins CAN use `assets/stylesheets/` — register with `register_asset 'stylesheets/plugnmeet.scss'` in plugin.rb.

**No `controllers/` directory** — admin page state is managed inside the `.gjs` Glimmer component, not a separate Ember controller.

### plugin.rb Structure

```ruby
# frozen_string_literal: true

# name: discourse-plugnmeet
# about: Plugin description
# version: 0.1.0
# authors: Your Name
# url: https://github.com/yourrepo

enabled_site_setting :plugnmeet_enabled

register_asset 'stylesheets/plugnmeet.scss'

after_initialize do
  module ::DiscoursePlugnmeet
    PLUGIN_NAME = "discourse-plugnmeet"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePlugnmeet
    end
  end

  require_relative 'lib/my_library'
  require_relative 'app/controllers/my_controller'

  Discourse::Application.routes.append do
    mount ::DiscoursePlugnmeet::Engine, at: "/plugnmeet"
  end

  DiscoursePlugnmeet::Engine.routes.draw do
    get "/rooms" => "plugnmeet#list_rooms"
    # etc.
  end

  add_admin_route 'plugnmeet.admin.title', 'meeting-rooms'
end
```

### settings.yml

Settings automatically appear in Admin → Settings → Plugins. Key field types:

```yaml
plugins:
  my_setting_enabled:
    default: false
    client: true          # true = also available in browser JS
  my_secret_key:
    default: ''
    client: false         # NEVER true for secrets
    secret: true          # Hides value in UI after saving, encrypts at rest
    description: 'Shown in admin UI'
  my_number:
    default: 1200
    client: true
    min: 800
    max: 1920
```

`secret: true` means:
- Value displayed as `••••••••` after saving
- Encrypted at rest in the database
- Never sent to the client
- Admin can clear and re-enter but cannot view the original value

This is the correct approach for API keys/secrets — do NOT hash them, as they need to be retrieved in plaintext to sign requests (e.g. JWT signing, API auth headers).

### PluginStore — Lightweight Data Storage

For simple data that doesn't need a full DB migration, use `PluginStore`:

```ruby
# Store data
PluginStore.set('discourse-plugnmeet', 'meeting_rooms', rooms.map(&:to_hash))

# Retrieve data
PluginStore.get('discourse-plugnmeet', 'meeting_rooms') || []
```

Good for: plugin config, room lists, small records.
Not good for: high-volume data, complex queries, relational data.

### Redis for Ephemeral State

Use `Discourse.redis` for presence/ephemeral data:

```ruby
# Add to a set
Discourse.redis.sadd("plugnmeet:presence:#{room_id}", user_id)
Discourse.redis.expire("plugnmeet:presence:#{room_id}", 1.hour.to_i)

# Remove from set
Discourse.redis.srem("plugnmeet:presence:#{room_id}", user_id)

# Count members
Discourse.redis.scard("plugnmeet:presence:#{room_id}")

# Get all members
Discourse.redis.smembers("plugnmeet:presence:#{room_id}")
```

### Admin Route Registration

`add_admin_route` in plugin.rb requires **three pieces** to work together:

1. `add_admin_route 'plugnmeet.admin.title', 'meeting-rooms'` in plugin.rb
2. A **route map file** at `assets/javascripts/discourse/plugnmeet-route-map.js` — this is what tells Ember's router about the route. Without it you get "Unable to configure link to 'Meeting Rooms'".
3. A route file at `routes/admin-plugins-meeting-rooms.js`

The route map file format:
```javascript
export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("meeting-rooms");
  },
};
```

The admin page itself is implemented as a self-contained Glimmer component (`components/plugnmeet-admin-rooms.gjs`). The route file is minimal (no model hook); the template just renders `<PlugnmeetAdminRooms />`.

### Emoji Picker in Admin Forms

The emoji picker import path needs to be verified against the live Discourse source:
```bash
grep -r "export default class EmojiPicker" /var/www/discourse/frontend --include="*.gjs" -l
```

Current best-guess import:
```javascript
import EmojiPicker from "discourse/components/emoji-picker";
```

Usage in template (strict-mode .gjs):
```hbs
<EmojiPicker
  @isActive={{this.showEmojiPicker}}
  @emojiSelected={{this.onEmojiSelected}}
  @onClose={{this.toggleEmojiPicker}}
/>
```

### Sidebar Sections — Implemented

The sidebar uses `api.addSidebarSection` to create a proper standalone collapsible section. The section:
- Has a configurable title from `plugnmeet_sidebar_title` site setting
- Only renders if the user has access to at least one room (visibility-gated via API call)
- Contains a single link item whose `contentComponent` is `MeetingRoomsSidebar`

`MeetingRoomsSidebar` handles the actual room list display, presence polling (10s), and click-to-join.

Key pattern in `plugnmeet-sidebar.js`:
```javascript
api.addSidebarSection(
  (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
    // ...
    return MeetingRoomsSection;
  },
  "main"
);
```

### Plugin Deployment — Critical Notes

Plugins are deployed via the server filesystem, NOT through the Discourse admin UI.

**Correct deployment path (host machine):**
```
/var/discourse/shared/standalone/plugins/discourse-plugnmeet/
```

**Common mistakes:**
- Dumping plugin contents directly into `plugins/` (not inside a subfolder) — Discourse won't find `plugin.rb`
- Copying files into the Docker container directly — they get wiped on rebuild
- Forgetting that the shared folder maps into the container; files must be on the HOST at the above path

**Preferred method — declare in app.yml:**
```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/yourorg/discourse-plugnmeet.git
```

Each entry in `cmd` is a separate command — don't omit `git clone` from any line. The error `exit 127` means a command wasn't found (i.e. you accidentally put just a URL with no command).

**Repo naming:** Linux is case-sensitive. If the GitHub repo is named `Discourse-PlugNMeet`, git clones it as `Discourse-PlugNMeet/`. Discourse plugin loading expects the folder name to match the plugin name in `plugin.rb`. Avoid capital letters in repo names. If needed, force the folder name during clone:
```yaml
- git clone https://github.com/yourorg/Discourse-PlugNMeet.git discourse-plugnmeet
```

**Rebuilds take the site down** for 5–15 minutes. Plan accordingly. A `./launcher restart app` is faster but only picks up container-level changes, not new plugin code.

### Mobile Detection

In the frontend JS, use Discourse's `capabilities` service:

```javascript
@service capabilities;

// Then:
if (this.capabilities.isIOS || this.capabilities.isAndroid) {
  window.location.href = joinUrl;  // Full page redirect on mobile
} else {
  window.open(joinUrl, 'popup_name', windowFeatures);  // Popup on desktop
}
```

### Popup Window Pattern

```javascript
const width = this.siteSettings.plugnmeet_popup_width;
const height = this.siteSettings.plugnmeet_popup_height;
const left = (screen.width - width) / 2;
const top = (screen.height - height) / 2;
const features = `width=${width},height=${height},left=${left},top=${top},toolbar=no,menubar=no,scrollbars=yes,resizable=yes`;

const popup = window.open(url, `room_${roomId}`, features);
if (!popup) {
  // Popup was blocked by browser — fall back to new tab
  window.open(url, '_blank');
} else {
  popup.focus();
}
```

### JWT Token Generation (Ruby)

PlugNmeet uses JWT for join tokens. Requires the `jwt` gem:

```ruby
require 'jwt'

token = JWT.encode(
  {
    room_id: room_id,
    user_info: { name: username, user_id: user_id.to_s, is_admin: is_admin },
    iss: api_key,
    nbf: Time.now.to_i,
    exp: (Time.now + 24.hours).to_i
  },
  api_secret,
  'HS256'
)

join_url = "#{server_url}/?access_token=#{token}"
```

The API key/secret come from `SiteSetting.plugnmeet_api_key` / `SiteSetting.plugnmeet_api_secret` — never hardcoded, never sent to client.
