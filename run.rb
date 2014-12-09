#!/usr/bin/env ruby
# rubocop:disable all
require_relative 'common'
todos = ARGV[1..-1]
$home_dir = File.expand_path(ARGV[0] || '.')
if todos.include? 'user'
  migrate_user
end
if todos.include? 'board'
  migrate_board
end
