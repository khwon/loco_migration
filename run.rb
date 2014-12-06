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
    begin
      u = User.new
      if entry[:userid] == 'ya62rdset'
      else
      end
      u.username = e entry[:userid]
      u.nickname = e entry[:username]
      u.realname = e entry[:realname]
      u.sex = e entry[:sex] rescue ''
      u.email = e entry[:email]
      u.old_crypt_password = entry[:passwd]

    #      u.save!
    rescue
      invalid << entry
    end
  end
  invalid.each do |x|
    p e x[:userid]
  end
end

def migrate_board
  boards = ['']
  while boards.size > 0
    cur_board = boards.pop
    file_path = "#{$home_dir}/boards/#{cur_board}/.BOARDS"
    if File.exist? file_path
      LOCO::Record.apply_record(file_path, LOCO::Struct::Fileheader) do |b|
        #    p b
        # p b.filename # board/dir name
        # p b[:owner].encode('utf-8','cp949') # board/dir owner
        if File.symlink? "#{$home_dir}/boards/#{cur_board}/#{b[:filename]}"
        else
        end
        model = Board.new
        model.title = e b[:title]
        model.parent = Board.find_by_path(cur_board)
        model.is_dir = b[:isdirectory] == 1 ? true : false
        model.name = e b[:filename]
        model.save!
        if b[:is_directory] == 1
          boards << cur_board + '/' + b[:filename]
        else
          file_path = "#{$home_dir}/boards/#{cur_board}/#{b[:filename]}/.DIR"
          if File.exist? file_path
            LOCO::Record.apply_record(file_path, LOCO::Struct::Dir_fileheader) do |post|
              #              p post
              p post[:filename]
              p post[:owner].encode('utf-8', 'cp949')
              p post[:title].encode('utf-8', 'cp949')
              p post[:tm_year] + 1900
              p post[:tm_mon] + 1
              p post[:tm_mday]
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
end
#migrate_user
migrate_board
