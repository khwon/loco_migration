# rubocop:disable all
require_relative '../config/environment'
require_relative 'loco'
def log str
  File.open('migration_log','a') do |f|
    f.puts str
  end
  puts str
end
def e(str)
  str.encode('utf-8','cp949', :invalid => :replace, :undef => :replace, :replace => '?')
end
def migrate_user
  log 'migrating users..'
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
        log e(entry[:userid]).inspect
        log $!
        log $@
        invalid << entry
      end
    end
  end
  invalid.each do |x|
    #p e x[:userid]
  end
end

def migrate_board
  log 'migrating boards..'
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
        board_model = Board.new
        board_model.parent = Board.find_by_path(cur_board[1..-1]) if cur_board != ''
        board_model.is_dir = b[:is_directory] == 1 ? true : false
        board_model.name = e b[:filename]
        owner = User.find_by_username(e b[:owner])
        if owner.nil?
          if board_model.is_dir
            owner = User.find_by_username('SYSOP')
          else
            u = User.new
            u.username = e b[:owner]
            u.is_active = false
            u.save!
            owner = u
          end
        end
        board_model.owner = owner
        if File.symlink? "#{$home_dir}/boards/#{cur_board}/#{b[:filename]}"
          orig = File.readlink("#{$home_dir}/boards/#{cur_board}/#{b[:filename]}")
          if File.exists?(orig) && orig =~ /^#{$home_dir}\/boards\/(.*)$/
            symlinks[board_model] = $1
          else
            log "cannot find #{orig}, linked from #{board_model.path_name}"
          end
          next
        else
          board_model.title = e b[:title] rescue ''
          board_model.save!
        end
        if b[:is_directory] == 1
          boards << cur_board + '/' + b[:filename]
        end
      end
    else
      # TODO: handle error
      log "no .BOARDS: #{cur_board}"
    end
  end
  symlinks.each do |model, orig_path|
    orig_board = Board.find_by_path(orig_path)
    if orig_board
      model.alias_board = orig_board
      model.save!
    else
      log "cannot find #{orig_path}, linked from #{model.path_name}"
    end
  end
end

def migrate_posts(root: nil)
  boards = root ? Board.where(:is_dir => false) : root.leaves
  boards.each do |board|
    file_path = "#{$home_dir}/boards/#{board.path_name}/.DIR"
    if File.exist? file_path
      num = 1
      LOCO::Record.apply_record(file_path, LOCO::Struct::Dir_fileheader) do |post|
        post_model = Post.new
        post_model.title = e post[:title]
        post_model.board = board
        writer = User.find_by_username(e post[:owner])
        if writer.nil?
          writer = User.new
          writer.username = e post[:owner]
          writer.is_active = false
          writer.save!
        end
        post_model.writer = writer
        post_model.num = num
        num += 1
        post_model.content = ''
        hour = 0
        min = 0
        sec = 0
        post_file_path = "#{$home_dir}/boards/#{board.path_name}/#{post[:filename]}"
        if File.exist? post_file_path
          File.open(post_file_path) do |f|
            str = e(f.gets||'') # writer
            post_model.content << str unless str.start_with? '글쓴이:'
            str = e(f.gets||'') # date
            if str =~ /^날  짜: .* (\d{2}):(\d{2}):(\d{2})( \d{4})?$/
              hour = $1.to_i
              min = $2.to_i
              sec = $3.to_i
            elsif str =~ /^날  짜: .* (\d{2}):(\d{2}):(\d{2}) \d{4}$/
              # old format (날  짜: Fri Jul  5 18:13:24 2002)
              hour = $1.to_i
              min = $2.to_i
              sec = $3.to_i
            elsif str =~ /^날  짜: .* (\d{2})시 (\d{2})분 (\d{2})초$/
              # more old format (날  짜: 1997년 6월 9일 (월) 18시 11분 34초)
              hour = $1.to_i
              min = $2.to_i
              sec = $3.to_i
            else
              post_model.content << str
            end
            str = e (f.gets||'') # title
            post_model.content << str unless str.start_with? '제  목:'
            str = (f.gets||'')
            str = '' if str == "\n"
            str << f.read
            begin
              post_model.content << str.encode('utf-8','cp949')
            rescue
              log "encoding failed: #{board.path_name}:#{num-1} (#{e post[:title]}/#{e post[:owner]})"
              post_model.content << str.encode('utf-8','cp949', :invalid => :replace, :undef => :replace, :replace => '?')
            end
          end
        end
        hour = 0 if hour > 23
        min = 0 if min > 59
        sec = 0 if sec > 59
        post_model.created_at = post_model.updated_at = Time.local(
          post[:tm_year] + 1900, post[:tm_mon] + 1, post[:tm_mday],hour,min,sec)
        post_model.save!
      end
    else
      # TODO: handle error
      log "no .DIR: #{board.path_name}"
    end
  end
end
