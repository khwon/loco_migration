# rubocop:disable all
class File
  def safewrite(data)
    size = data.length
    idx = 0
    idx += write data[idx..-1] while idx < size
  end
end
module LOCO
  module Struct
    class BaseStruct
      def [](arg)
        var_name = "@#{arg}".to_sym
        if self.instance_variable_defined? var_name
          instance_variable_get(var_name)
        else
          fail 'undefined variable'
        end
      end
      def self.size
        fail 'size not defined'
      end
      def serialize
        fail 'serialize not defined'
      end
    end
    class Dir_fileheader < BaseStruct
      @@size = 2460
      attr_reader :filename, :tm_mday, :owner, :level
      def self.size
        @@size
      end
      def initialize(rawdata = nil)
        rawdata = "\x00" * @@size if rawdata.nil?
        @filename, @owner, @title, @level, @tm_year, @tm_mon, @tm_mday,
          @padding, @readcnt, @makred, @highlight, @read, @visit,
          @dummy, @accessed = rawdata.unpack(
            'Z80Z80Z80ICCCCSSSSSa196a2006')
      end

      def serialize
        [@filename, @owner, @title, @level, @tm_year, @tm_mon, @tm_mday,
         @padding, @readcnt, @makred, @highlight, @read, @visit,
         @dummy, @accessed].pack(
            'a80a80a80ICCCCSSSSSa196a2006')
      end

      def set_read(usernum)
        @accessed[(usernum - 1) / 4] |= 0x40 >> ((usernum - 1) % 4) * 2
        nil
      end

      def get_read(usernum)
        @accessed[(usernum - 1) / 4] & (0x40 >> ((usernum - 1) % 4 * 2))
      end

      def set_time(time = Time.now)
        @tm_year = time.year - 1900
        @tm_mon = time.mon - 1
        @tm_mday = time.day
      end

      def set_owner(name)
        @owner = name[0..78]
      end

      def set_filename(fname)
        @filename = fname[0..78]
      end

      def set_title(title)
        @title = title[0..78]
      end
    end
    class Fileheader < BaseStruct
      @@size =  8492
      attr_reader :level, :filename
      def self.size
        @@size
      end
      def initialize(rawdata = nil)
        rawdata = "\x00" * @@size if rawdata.nil?
        @filename, @owner, @second_owner, @dummy1, @title,
          @level, @tm_year, @tm_mon, @tm_mday,
          @is_directory, @readcnt, @directory_zapped,
          @padding, @title_color, @dummy2, @accessed =
          rawdata.unpack(
            'Z80Z20Z20a40Z80ICCCCSCCSa214a8024')
      end

      def serialize
        [@filename, @owner, @second_owner, @dummy1, @title,
         @level, @tm_year, @tm_mon, @tm_mday,
         @is_directory, @readcnt, @directory_zapped,
         @padding, @title_color, @dummy2, @accessed].pack(
            'a80a20a20a40a80ICCCCSCCSa214a8024')
      end
    end

    class Cachefile < BaseStruct
      @@size = 214
      def self.size
        @@size
      end
      attr_reader :filename
      def initialize(rawdata = nil)
        rawdata = "\x00" * @@size if rawdata.nil?
        @filename, @owner, @second_owner, @title,
          @level, @tm_year, @tm_mon, @tm_mday,
          @is_directory, @readcnt, @directory_zapped,
          @accessed, @title_color = rawdata.unpack(
            'Z80Z20Z20Z80ICCCCSCCS')
      end

      def serialize
        [@filename, @owner, @second_owner, @title,
         @level, @tm_year, @tm_mon, @tm_mday,
         @is_directory, @readcnt, @directory_zapped,
         @accessed, @title_color].pack(
            'a80a20a20a80ICCCCSCCS')
      end
    end
    class Cache < BaseStruct
      @@size = 330
      def self.size
        @@size
      end
      attr_reader :board, :board_hash_val
      def initialize(rawdata = nil)
        rawdata = "\x00" * @@size if rawdata.nil?
        @board_id_num, @real_board_name =
          rawdata[0..83].unpack('iZ80')
        @board = Cachefile.new rawdata[84..297]
        @parent, @child, @newread_timestamp, @board_hash_val, @dir_level, @dir_zap, @board_type =
          rawdata[298..-1].unpack('iiqiIii')
      end

      def serialize
        [@board_id_num, @real_board_name].pack('ia80') +
          @board.serialize +
          [@parent, @child, @newread_timestamp, @board_hash_val, @dir_level, @dir_zap, @board_type].pack(
            'iiqiIii')
      end
    end
    class Userec < BaseStruct
      @@size = 464
      def self.size
        @@size
      end
      attr_reader :userid, :username, :termtype, :userlevel,
                  :numlogins, :numposts
      def set_level(l)
        @userlevel = l
      end

      def initialize(rawdata = nil)
        rawdata = "\x00" * @@size if rawdata.nil?
        @userid, @notused, @editor_kind, @lasthost,
          @numlogins, @numposts, @flags, @passwd, @username,
          @termtype, @userlevel, @lastlogin, @protocol,
          @realname, @sex, @address, @email = rawdata.unpack(
            'Z14Z33CZ16IIa2Z14Z80Z80IqiZ37Z3Z80Z80')
      end

      def serialize
        [@userid, @notused, @editor_kind, @lasthost,
         @numlogins, @numposts, @flags, @passwd, @username,
         @termtype, @userlevel, @lastlogin, @protocol,
         @realname, @sex, @address, @email].pack(
            'a14a33Ca16IIa2a14a80a80Iqia37a3a80a80')
      end
    end
  end
  module Record
    def self.get_records(filename, object_type)
      apply_record(filename, object_type)
    end
    def self.apply_record(filename, object_type)
      begin
        f = File.open(filename)
      rescue
        return nil
      end
      arr = nil
      arr = [] unless block_given?
      begin
        f.flock(File::LOCK_SH)
        loop do
          str = f.read(object_type.size)
          if str.nil?
            return arr
          end
          object = object_type.new(str)
          if block_given?
            yield object
          else
            arr << object
          end
        end
      ensure
        f.flock(File::LOCK_UN)
        f.close
      end
      arr
    end
    def self.append_record(filename, object)
      File.open(filename, File::CREAT | File::WRONLY) do |f|
        f.flock(File::LOCK_EX)
        f.seek(0, IO::SEEK_END)
        f.safewrite(object.serialize)
        f.flock(File::LOCK_UN)
      end
    end
    def self.substitute_record(filename, object, offset)
      File.open(filename, File::CREAT | File::WRONLY) do |f|
        f.flock(File::LOCK_EX)
        f.seek(offset * object.class.size, IO::SEEK_SET)
        f.safewrite(object.serialize)
        f.flock(File::LOCK_UN)
      end
    end
    def self.search_record(filename, object_type)
      id = 0
      begin
        f = File.open(filename)
      rescue
        return nil, nil
      end
      begin
        f.flock(File::LOCK_SH)
        loop do
          id += 1
          str = f.read(object_type.size)
          if str.nil?
            return nil, nil
          end
          object = object_type.new(str)
          if yield object
            return object, id
          end
        end
      ensure
        f.flock(File::LOCK_UN)
        f.close
      end
    end
  end
  module BoardHash
    def self.get_alphanum(char)
      if char.chr =~ /[A-Z]/
        char - 'A'[0]
      elsif char.chr =~ /[a-z]/
        char - 'a'[0] + 26
      end
    end
    def self.filter_table(num)
      table = %w(K a e n s o A p m c g w)
      table.map! { |x| get_alphanum x[0] }
      idx = table.index(num)
      if idx.nil?
        0
      else
        idx + 1
      end
    end
    def self.board_hash(boardname)
      retval = 0
      arr = boardname.split('/')
      return nil if arr.size > 3
      arr.each do |x|
        retval *= 52
        retval += BoardHash.get_alphanum x[0]
      end
      retval *= 52**(3 - arr.size)
      n = retval % (2**31)
      # int board_hash_filter(int n)
      retval = n / (52 * 52)
      retval = filter_table retval
      retval *= 52 * 52
      retval += (n % (52 * 52))
      retval
    end
  end
  class Bcache
    def bcache_rebuild
      nil
    end

    def initialize(homepath)
      @bcache_arr = Record.get_records(homepath + '/.BCACHE', Struct::Cache)
      @homepath = homepath
    end

    def update_board_timestamp(boardpath)
      ori_path = @homepath + '/boards/' + boardpath
      ori_path = File.readlink(ori_path) if File.symlink? ori_path
      Dir.chdir(@homepath + '/boards/') do
        @bcache_arr.each do |bcache|
          dir = bcache.board.filename
          if File.identical? dir, ori_path
            hash_val = BoardHash.board_hash dir
            File.open(@homepath + '/.BOARD_TIMESTAMP', File::CREAT | File::WRONLY) do |f|
              f.flock(File::LOCK_EX)
              (1..3).each do |i|
                f.seek(hash_val * 8, IO::SEEK_SET)
                f.safewrite([Time.now.to_i].pack('q'))
                hash_val = (hash_val / 52**i) * 52**i
              end
              f.flock(File::LOCK_UN)
            end
          end
        end
      end
    end
  end
end
