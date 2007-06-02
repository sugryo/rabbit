require 'nkf'

module Rabbit
  module Utils
    module_function
    def to_class_name(name)
      name.gsub(/(?:\A|_|\-)([a-z])/) do |x|
        $1.upcase
      end
    end

    def require_safe(path)
      require path
    rescue LoadError
      $".reject! {|x| /\A#{Regexp.escape(path)}/ =~ x}
      raise
    end

    def require_files_under_directory_in_load_path(dir, silent=true)
      normalize = Proc.new do |base_path, path|
        path.sub(/\A#{Regexp.escape(base_path)}\/?/, '').sub(/\.[^.]+$/, '')
      end

      $LOAD_PATH.each do |path|
        source_glob = ::File.join(path, dir, '*')
        Dir.glob(source_glob) do |source|
          next if File.directory?(source)
          begin
            before = Time.now
            normalized_path = normalize[path, source]
            require_safe normalized_path
            unless silent
              STDERR.puts([Time.now - before, normalized_path].inspect)
            end
          rescue LoadError
            unless silent
              STDERR.puts(path)
              STDERR.puts($!.message)
              STDERR.puts($@)
            end
          end
        end
      end
    end

    def collect_under_module(mod, klass)
      mod.constants.collect do |x|
        mod.const_get(x)
      end.find_all do |x|
        x.is_a?(klass)
      end
    end

    def collect_classes_under_module(mod)
      collect_under_module(mod, Class)
    end

    def collect_modules_under_module(mod)
      collect_under_module(mod, Module)
    end

    def corresponding_objects(objects)
      objects.find_all do |object|
        object.respond_to?(:priority)
      end.sort_by do |object|
        object.priority
      end.last
    end

    def corresponding_class_under_module(mod)
      corresponding_objects(collect_classes_under_module(mod))
    end

    def corresponding_module_under_module(mod)
      corresponding_objects(collect_modules_under_module(mod))
    end

    def arg_list(arity)
      args = []
      if arity == -1
        args << "*args"
      else
        arity.times do |i|
          args << "arg#{i}"
        end
      end
      args
    end

    def find_path_in_load_path(*name)
      found_path = $LOAD_PATH.find do |path|
        File.readable?(File.join(path, *name))
      end
      if found_path
        File.join(found_path, *name)
      else
        nil
      end
    end

    def unescape_title(title)
      REXML::Text.unnormalize(title).gsub(/\r|\n/, ' ')
    end

    def drawable_to_pixbuf(drawable)
      args = [drawable.colormap, drawable, 0, 0, *drawable.size]
      Gdk::Pixbuf.from_drawable(*args)
    end

    def process_pending_events
      if events_pending_available?
        while Gtk.events_pending?
          Gtk.main_iteration
        end
      end
    end

    def events_pending_available?
      !windows? #or (Gtk::BINDING_VERSION <=> [0, 14, 1]) > 0
    end

    def process_pending_events_proc
      Proc.new do
        process_pending_events
      end
    end

    def init_by_constants_as_default_value(obj)
      klass = obj.class
      klass.constants.each do |name|
        const = klass.const_get(name)
        unless const.kind_of?(Class)
          var_name = name.downcase
          obj.instance_variable_set("@#{var_name}", const.dup)
          klass.module_eval {attr_accessor var_name}
        end
      end
    end

    def windows?
      # Gdk.windowing_win32? # what about this?
      /cygwin|mingw|mswin32|bccwin32/.match(RUBY_PLATFORM) ? true : false
    end

    def quartz?
      if Gdk.respond_to?(:windowing_quartz?)
        Gdk.windowing_quartz?
      else
        !windows? and !Gdk.windowing_x11?
      end
    end

    def move_to(base, target)
      window = base.window
      screen = window.screen
      num = screen.get_monitor(window)
      monitor = screen.monitor_geometry(num)
      window_x, window_y = window.origin
      window_width, window_height = window.size
      target_width, target_height = target.size_request

      args = [window_x, window_y, window_width, window_height]
      args.concat([target_width, target_height])
      args.concat([screen.width, screen.height])
      x, y = yield(*args)

      target.move(x, y)
    end

    def compute_left_x(base_x)
      [base_x, 0].max
    end

    def compute_right_x(base_x, base_width, target_width, max_x)
      right = base_x + base_width - target_width
      [[right, max_x - target_width].min, 0].max
    end

    def compute_top_y(base_y)
      [base_y, 0].max
    end

    def compute_bottom_y(base_y, base_height, target_height, max_y)
      bottom = base_y + base_height - target_height
      [[bottom, max_y - target_height].min, 0].max
    end

    def move_to_top_left(base, target)
      move_to(base, target) do |bx, by, bw, bh, tw, th, sw, sh|
        [compute_left_x(bx), compute_top_y(by)]
      end
    end

    def move_to_top_right(base, target)
      move_to(base, target) do |bx, by, bw, bh, tw, th, sw, sh|
        [compute_right_x(bx, bw, tw, sw), compute_top_y(by)]
      end
    end

    def move_to_bottom_left(base, target)
      move_to(base, target) do |bx, by, bw, bh, tw, th, sw, sh|
        [compute_left_x(bx), compute_bottom_y(by, bh, th, sh)]
      end
    end

    def move_to_bottom_right(base, target)
      move_to(base, target) do |bx, by, bw, bh, tw, th, sw, sh|
        [compute_right_x(bx, bw, tw, sw),
         compute_bottom_y(by, bh, th, sh)]
      end
    end

    def combination(elements)
      return [] if elements.empty?
      first, *rest = elements
      results = combination(rest)
      if results.empty?
        [[], [first]]
      else
        results + results.collect {|result| [first, *result]}
      end
    end

    def extract_four_dimensions(params)
      [params[:top], params[:right], params[:bottom], params[:left]]
    end

    def parse_four_dimensions(*values)
      if values.is_a?(Array) and values.size == 1 and
          (values.first.is_a?(Array) or values.first.is_a?(Hash))
        values = values.first
      end
      if values.is_a?(Hash)
        extract_four_dimensions(values)
      else
        case values.size
        when 1
          left = right = top = bottom = Integer(values.first)
        when 2
          top, left = values.collect{|x| Integer(x)}
          bottom = top
          right = left
        when 3
          top, left, bottom = values.collect{|x| Integer(x)}
          right = left
        when 4
          top, right, bottom, left = values.collect{|x| Integer(x)}
        else
          raise ArgumentError
        end
        [top, right, bottom, left]
      end
    end

    def split_number_to_minute_and_second(number)
      if number >= 0
        sign = " "
      else
        sign = "-"
      end
      [sign, *number.abs.divmod(60)]
    end

    def time(message=nil)
      before = Time.now
      yield
    ensure
      output = Time.now - before
      output = [message, output] if message
      p output
    end
  end

  module SystemRunner
    module_function
    def run(cmd, *args)
      begin
        system(cmd, *args)
      rescue SystemCallError
        yield($!) if block_given?
        false
      end
    end
  end
  
  module ScreenInfo
    module_function
    def default_screen
      Gdk::Screen.default
    end
    
    def screen_width
      default_screen.width
    end

    def screen_width_mm
      default_screen.width_mm
    end

    def screen_height
      default_screen.height
    end

    def screen_height_mm
      default_screen.height_mm
    end

    def screen_x_resolution
      screen_width / mm_to_inch(screen_width_mm)
    end

    def screen_y_resolution
      screen_height / mm_to_inch(screen_height_mm)
    end

    def screen_depth
      default_screen.root_window.depth
    end

    def mm_to_inch(mm)
      mm / 25.4
    end
  end

  module HTML
    module_function
    def a_link(start_a, label, label_only)
      result = "["
      result << start_a unless label_only
      result << label
      result << "</a>" unless label_only
      result << "]"
      result
    end
  end

  module DirtyCount
    TOO_DIRTY = 5

    def dirty?
      @dirty_count >= TOO_DIRTY
    end
    
    def dirty(factor=0.1)
      @dirty_count += TOO_DIRTY * factor
      dirtied if dirty?
    end
    
    def very_dirty
      dirty(1)
    end
    
    def bit_dirty
      dirty(0.01)
    end

    def dirty_count_clean
      @dirty_count = 0
    end

    private
    def dirtied
      dirty_count_clean
    end
    
    def check_dirty
      if dirty?
        dirtied
      else
        yield
      end
    end
  end

  module Converter
    module_function
    def keep_kcode(new_kcode)
      kcode = $KCODE
      $KCODE = new_kcode
      yield
    ensure
      $KCODE = kcode
    end

    def to_utf8(str)
      NKF.nkf("-w", str)
    end

    def to_eucjp(str)
      NKF.nkf("-e", str)
    end

    def to_utf8_from_eucjp(str)
      NKF.nkf("-wE", str)
    end

    def to_eucjp_from_utf8(str)
      NKF.nkf("-eW", str)
    end
  end

  module ModuleLoader
    LOADERS = {}

    class << self
      def extend_object(object)
        super
        LOADERS[object] = []
      end
    end

    def loaders
      LOADERS.find do |loader, value|
        self.ancestors.find {|ancestor| ancestor == loader}
      end[1]
    end

    def unshift_loader(loader)
      loaders.unshift(loader)
    end

    def push_loader(loader)
      loaders.push(loader)
    end

    def find_loader(*args)
      loaders.find do |loader|
        loader.match?(*args)
      end
    end
  end
end
