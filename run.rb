#!/usr/bin/env ruby
# rubocop:disable all
require_relative 'common'
#todos = ARGV[0..-2]
$home_dir = '/export/home/bbs'
#$home_dir = File.expand_path(ARGV[0] || '/export/home/bbs')
migrate_user
migrate_board
