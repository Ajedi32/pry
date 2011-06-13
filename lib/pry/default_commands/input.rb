class Pry
  module DefaultCommands

    Input = Pry::CommandSet.new do

      command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop." do
        output.puts "Input buffer cleared!"
        eval_string.replace("")
      end

      command "show-input", "Show the current eval_string" do
        render_output(false, 0, Pry.color ? CodeRay.scan(eval_string, :ruby).term : eval_string)
      end

      command(/amend-line.?(-?\d+)?(?:\.\.(-?\d+))?/, "Amend a line of input in multi-line mode. Type `amend-line --help` for more information. Aliases %",
              :interpolate => false, :listing => "amend-line")  do |*args|
        start_line_number, end_line_number, replacement_line = *args

        opts = Slop.parse!(args.compact) do |opt|
          opt.banner "Amend a line of input in multi-line mode. `amend-line N`, where the N in `amend-line N` represents line to replace.\n\nCan also specify a range of lines using `amend-line N..M` syntax. Passing '!' as replacement content deletes the line(s) instead. Aliases: %N\ne.g amend-line 1 puts 'hello world!'\ne.g amend-line 1..4 !\n"
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        next if opts.h?
        next output.puts "No input to amend." if eval_string.empty?

        replacement_line = "" if !replacement_line
        input_array = eval_string.each_line.to_a

        end_line_number = start_line_number.to_i if !end_line_number
        line_range = start_line_number ? (start_line_number.to_i..end_line_number.to_i)  : input_array.size - 1

        # delete selected lines if replacement line is '!'
        if arg_string == "!"
          input_array.slice!(line_range)
        else
          input_array[line_range] = arg_string + "\n"
        end
        eval_string.replace input_array.join
      end

      alias_command(/%.?(\d+)?(?:\.\.(-?\d+))?/, /amend-line.?(-?\d+)?(?:\.\.(-?\d+))?/, "")

      command "play", "Play back a string or a method or a file as input. Type `play --help` for more information." do |*args|
        opts = Slop.parse!(args) do |opt|
          opt.banner "Usage: play [OPTIONS] [--help]\nDefault action (no options) is to play the provided string\ne.g `play puts 'hello world'` #=> \"hello world\"\ne.g `play -m Pry#repl --lines 1..-1`\ne.g `play -f Rakefile --lines 5`\n"

          opt.on :l, :lines, 'The line (or range of lines) to replay.', true, :as => Range
          opt.on :m, :method, 'Play a method.', true
          opt.on :f, "file", 'The line (or range of lines) to replay.', true
          opt.on :h, :help, "This message." do
            output.puts opt
          end

          opt.on_noopts { Pry.active_instance.input = StringIO.new(arg_string)  }
        end

        if opts.m?
          meth_name = opts[:m]
          if (meth = get_method_object(meth_name, target, {})).nil?
            output.puts "Invalid method name: #{meth_name}."
            next
          end
          code, code_type = code_and_code_type_for(meth)
          next if !code

          range = opts.l? ? opts[:l] : (0..-1)

          Pry.active_instance.input = StringIO.new(Array(code.each_line.to_a[range]).join)
        end

        if opts.f?
          text_array = File.readlines File.expand_path(opts[:f])
          range = opts.l? ? opts[:l] : (0..-1)

          Pry.active_instance.input = StringIO.new(Array(text_array[range]).join)
        end
      end

      command "hist", "Show and replay Readline history. Type `hist --help` for more info." do |*args|
        Slop.parse(args) do |opt|
          history = Readline::HISTORY.to_a
          opt.banner "Usage: hist [--replay START..END] [--clear] [--grep PATTERN] [--head N] [--tail N] [--help]\n"

          opt.on :g, :grep, 'A pattern to match against the history.', true do |pattern|
            pattern = Regexp.new arg_string.split(/ /)[1]
            history.pop

            history.map!.with_index do |element, index|
              if element =~ pattern
                "#{text.blue index}: #{element}"
              end
            end

            stagger_output history.compact.join "\n"
          end

          opt.on :head, 'Display the first N items of history', 
                 :optional => true, 
                 :as       => Integer, 
                 :unless   => :grep do |limit|
            
            limit ||= 10
            list  = history.first limit
            lines = text.with_line_numbers list.join("\n"), 0
            stagger_output lines
          end

          opt.on :t, :tail, 'Display the last N items of history', 
                     :optional => true, 
                     :as       => Integer,
                     :unless   => :grep do |limit|

            limit ||= 10
            offset = history.size-limit
            offset = offset < 0 ? 0 : offset

            list  = history.last limit
            lines = text.with_line_numbers list.join("\n"), offset
            stagger_output lines
          end

          opt.on :s, :show, 'Show the history corresponding to the history line (or range of lines).', 
                 true, 
                 :as     => Range,
                 :unless => :grep do |range|
            
            start_line = range.is_a?(Range) ? range.first : range
            lines = text.with_line_numbers Array(history[range]).join("\n"), start_line
            stagger_output lines
          end

          opt.on :e, :exclude, 'Exclude pry commands from the history.', :unless => :grep do
            history.map!.with_index do |element, index|
              unless command_processor.valid_command? element
                "#{text.blue index}: #{element}"
              end
            end
            stagger_output history.compact.join "\n"
          end

          opt.on :r, :replay, 'The line (or range of lines) to replay.', 
                 true, 
                 :as     => Range,
                 :unless => :grep do |range|
            actions = Array(history[range]).join("\n") + "\n"
            Pry.active_instance.input = StringIO.new(actions)
          end

          opt.on :c, :clear, 'Clear the history', :unless => :grep do
            Readline::HISTORY.shift until Readline::HISTORY.empty?
            output.puts 'History cleared.'
          end

          opt.on :h, :help, 'Show this message.', :tail => true, :unless => :grep do
            output.puts opt.help
          end

          opt.on_empty do
            lines = text.with_line_numbers history.join("\n"), 0
            stagger_output lines
          end
        end
      end
    end

  end
end
