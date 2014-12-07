#!/usr/bin/env ruby
# rubocop:disable all
require_relative '../config/environment'
require_relative 'loco'
$home_dir = File.expand_path(ARGV[0] || '.')
def e(str)
  str.encode('utf-8', 'cp949')
rescue
  str[0..-2].encode('utf-8', 'cp949')
end

def migrate_user
  invalid = []
  LOCO::Record.apply_record("#{$home_dir}/.PASSWDS", LOCO::Struct::Userec) do |entry|
    if entry[:userid] != ''
      begin
        u = User.new
        u.username = e entry[:userid]
        u.nickname = e entry[:username] rescue ''
        u.realname = e entry[:realname] rescue ''
        u.sex = e entry[:sex] rescue ''
        u.email = e entry[:email] rescue ''
        u.old_crypt_password = entry[:passwd]
        u.save!
      rescue
        p e entry[:userid]
        puts $!
        puts $@
        invalid << entry
      end
    end
  end
  invalid.each do |x|
    #p e x[:userid]
  end
end

def migrate_board
  missing_owner_cnt = 0
  boards = ['']
  symlinks = {}
  while boards.size > 0
    cur_board = boards.pop
    file_path = "#{$home_dir}/boards/#{cur_board}/.BOARDS"
    if File.exist? file_path
      LOCO::Record.apply_record(file_path, LOCO::Struct::Fileheader) do |b|
        # p b.filename # board/dir name
        # p b[:owner].encode('utf-8','cp949') # board/dir owner
        if File.symlink? "#{$home_dir}/boards/#{cur_board}/#{b[:filename]}"
          if not File.exists? File.readlink("#{$home_dir}/boards/#{cur_board}/#{b[:filename]}")
            next
          end
        end
        model = Board.new
        model.parent = Board.find_by_path(cur_board[1..-1]) if cur_board != ''
        model.is_dir = b[:is_directory] == 1 ? true : false
        model.name = e b[:filename]
        owner = User.find_by_username(e b[:owner])
        if owner.nil?
          if model.is_dir
            owner = User.find_by_username('SYSOP')
          else
            missing_owner_cnt += 1
            puts "cannot find owner: #{e b[:owner]}"
            puts "in #{cur_board}/#{b[:filename]}"
            next
          end
        end
        model.owner = owner
        if File.symlink? "#{$home_dir}/boards/#{cur_board}/#{b[:filename]}"
          orig = File.readlink("#{$home_dir}/boards/#{cur_board}/#{b[:filename]}")
          if File.exists? orig
            if orig =~ /^#{$home_dir}\/boards\/(.*)$/
              symlinks[model] = $1
            end
          end
        else
          model.title = e b[:title] rescue ''
          model.save!
        end
        if b[:is_directory] == 1
          boards << cur_board + '/' + b[:filename]
        else
          file_path = "#{$home_dir}/boards/#{cur_board}/#{b[:filename]}/.DIR"
          if false and File.exist? file_path
            LOCO::Record.apply_record(file_path, LOCO::Struct::Dir_fileheader) do |post|
              #              p post
#              p post[:filename]
#              p post[:owner].encode('utf-8', 'cp949')
#              p post[:title].encode('utf-8', 'cp949')
#              p post[:tm_year] + 1900
#              p post[:tm_mon] + 1
#              p post[:tm_mday]
            end
          else
            # TODO: handle error
          end
        end
      end
    else
      # TODO: handle error
    end
  end
  symlinks.each do |model, orig_path|
    orig_board = Board.find_by_path(orig_path)
    if orig_board
      model.alias_board = orig_board
      model.save!
    else
      puts "cannot find #{orig_path}, linked from #{model.path_name}"
    end
  end
  puts "total missing_owner_count : #{missing_owner_cnt}"
end
migrate_user
migrate_board
