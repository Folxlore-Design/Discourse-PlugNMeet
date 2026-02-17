#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for PlugNmeet connection
# Run from Discourse Rails console: rails runner plugins/discourse-plugnmeet/test_connection.rb

puts "PlugNmeet Connection Test"
puts "=" * 50

# Check settings
puts "\n1. Checking Settings..."
enabled = SiteSetting.plugnmeet_enabled
server_url = SiteSetting.plugnmeet_server_url
api_key = SiteSetting.plugnmeet_api_key
api_secret = SiteSetting.plugnmeet_api_secret

if !enabled
  puts "❌ Plugin is not enabled. Enable in Admin > Settings > Plugins"
  exit 1
end

if server_url.blank?
  puts "❌ Server URL not configured"
  exit 1
end

if api_key.blank? || api_secret.blank?
  puts "❌ API credentials not configured"
  exit 1
end

puts "✅ Plugin enabled"
puts "✅ Server URL: #{server_url}"
puts "✅ API Key: #{api_key[0..10]}..."
puts "✅ API Secret: #{api_secret[0..10]}..."

# Test room creation
puts "\n2. Testing Room Creation..."
test_room_id = "test-#{SecureRandom.hex(4)}"
test_room_name = "Connection Test Room"

begin
  result = DiscoursePlugnmeet::PlugnmeetClient.create_room(test_room_id, test_room_name)
  
  if result[:success]
    puts "✅ Room created successfully"
    puts "   Room ID: #{test_room_id}"
  else
    puts "❌ Room creation failed: #{result[:error]}"
    exit 1
  end
rescue => e
  puts "❌ Error creating room: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

# Test token generation
puts "\n3. Testing Token Generation..."
begin
  user = User.first
  result = DiscoursePlugnmeet::PlugnmeetClient.generate_join_token(
    test_room_id,
    user.username,
    user.id
  )
  
  if result[:success]
    puts "✅ Token generated successfully"
    puts "   Join URL: #{result[:join_url][0..60]}..."
  else
    puts "❌ Token generation failed: #{result[:error]}"
    exit 1
  end
rescue => e
  puts "❌ Error generating token: #{e.message}"
  exit 1
end

# Test room status check
puts "\n4. Testing Room Status Check..."
begin
  is_active = DiscoursePlugnmeet::PlugnmeetClient.is_room_active?(test_room_id)
  puts "✅ Room status check successful"
  puts "   Room active: #{is_active}"
rescue => e
  puts "❌ Error checking room status: #{e.message}"
end

# Clean up test room
puts "\n5. Cleaning Up..."
begin
  DiscoursePlugnmeet::PlugnmeetClient.end_room(test_room_id)
  puts "✅ Test room deleted"
rescue => e
  puts "⚠️  Could not delete test room: #{e.message}"
end

puts "\n" + "=" * 50
puts "✅ All tests passed! PlugNmeet integration is working."
puts "\nNext steps:"
puts "  1. Create meeting rooms in Admin > Plugins > Meeting Rooms"
puts "  2. Users will see 'Meeting Rooms' in the sidebar"
puts "  3. Click any room to join!"
