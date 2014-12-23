#!/usr/bin/env ruby
# rubocop:disable all
require_relative 'common'
$home_dir = File.expand_path(ARGV[0] || '/export/home/bbs')
#migrate_posts(root: Board.find_by_path('asia/singapore/lovely'))
#ActiveRecord::Base.connection.execute("TRUNCATE posts;")
#ActiveRecord::Base.connection.execute("TRUNCATE board_reads;")
#migrate_posts(root: Board.find_by_path('asia/turkey/Forest'))
#path = 'asia/gon/dew'
path = 'asia'
migrate_posts(root: Board.find_by_path(path))
