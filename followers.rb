#!/usr/bin/env ruby
require 'rexml/document'
require 'net/http'

# Vars
@keepers  = []
@page     = 1
@done     = false
@num      = 0
@count    = 0
@type     = nil

@string_fields = ["name", "screen_name", "location", "description", "profile_image_url", "url", "created_at", "time_zone", "profile_background_color", "profile_text_color", "profile_link_color", "profile_sidebar_fill_color", "profile_sidebar_border_color", "profile_background_image_url"]
@boolean_fields = ["protected", "profile_background_tile", "notifications", "verified", "following"]
@integer_fields = ["id", "followers_count", "favourites_count", "friends_count", "statuses_count"]

def collect_user_input
  collect_user_login
  collect_user_search_field
  collect_user_search_terms
  puts "- Connecting to Twitter..."
end

def collect_user_login
  # User twitter name/password
  print "What is your Twitter Screen Name? "; @tweeter = gets.chomp
  print "What is your Twitter Password? "; @password = gets.chomp
end

def collect_user_search_field
  # User defined field to search on
  print "What field do you want to search on? (type ? for list) "; @field = gets.chomp.downcase
  if @field == "?"
    puts "Searchable fields are: "; display_fields
    print "What field do you want to search on? "; @field = gets.chomp.downcase
  end
end

def collect_user_search_terms
  # User defined search terms
  if @string_fields.index(@field)
    print "Filter terms (comma delimited)? "; @search = gets.chomp.strip.downcase.gsub(", ", ",").split(",")
    @type = "string"
  elsif @boolean_fields.index(@field)
    print "Enter TRUE or FALSE: "; @search = gets.chomp.strip.downcase
    @type = "boolean"
  elsif @integer_fields.index(@field)
    print "Enter comparison operator and value, example '> 100, < 1000': "; @search = gets.chomp.strip.gsub(", ", ",").split(",")
    @type = "integer"
  else
    puts "You entered an unknown field. Please try again with one of the following:"; display_fields
    exit
  end
end

def display_fields
  # help for fields
  puts "- strings: #{@string_fields.join(', ')}"
  puts "- booleans: #{@boolean_fields.join(', ')}"
  puts "- integers: #{@integer_fields.join(', ')}"
end

def get_follower_xml
  # Pull in the followers xml from Twitter. 100 (or less) records 
  # returned at a time, so need to call until we get a page with 
  # no records
  Net::HTTP.start('twitter.com') {|http|
    req = Net::HTTP::Get.new('/statuses/followers.xml?page=' + @page.to_s)
    req.basic_auth @tweeter, @password
    res = http.request(req)
    return REXML::Document.new(res.body)
  }
end

def parse_xml(doc)
  # Now that we have a page, loop through the users and push them
  # into the @keeper array if they match our search criteria.
  doc.elements.each('users/user') do |user|
    is_match = (user.elements[@field].text) ? match(user.elements[@field].text) : false
    @keepers.push([
      user.elements["screen_name"].text, 
      user.elements["name"].text, 
      user.elements[@field].text
    ]) if is_match
    @count += 1
  end
  puts "- Page #{@page} completed..."
end

def match(value)
  # Search wanted field against specified search terms based on 
  # field type
  return false if !value or value == ""
  return match_string(value) if @type == "string"
  return match_boolean(value) if @type == "boolean"
  return match_integer(value) if @type == "integer"
  return false
end

def match_string(value)
  # Searches on strings
  value = value.downcase.gsub(",", "").split(" ")
  @search.each { |term| return true if value.index(term) }
  return false
end

def match_boolean(value)
  # Searches on booleans
  return (@search == value.downcase)
end

def match_integer(value)
  # Searches on integers WITH mutliple comparison :)
  string = ""
  @search.each do |s|
    search = s.split(" ")
    string += " and " if string != ""
    string += "(#{value} #{search[0]} #{search[1]})"
  end
  return eval(string)
end

def next_xml
  # Set up next page of users, if any...
  @page += 1
  @num += @count
  @done = true if @count == 0
end

def display_output
  puts "- #{@num} found, returning: #{@keepers.size}"
  if @keepers.size > 0
    puts "-------------------------------------------------- "
    @keepers.each { |k| puts "@#{k[0]} - #{k[1]} - #{k[2]}" }
    puts "-------------------------------------------------- "
  end
end

collect_user_input
while !@done # Loop until we have all followers.
  @count = 0
  parse_xml(get_follower_xml)
  next_xml
end
display_output