# Ruby/ProgressBar - a text progress bar library
#
# Copyright (C) 2001-2005 Satoru Takabayashi <satoru@namazu.org>
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms
# of Ruby's license.
# ------------------------------------------------------------------
# Modified 2009-2012 Jose Peleteiro
# Modified 2012 Kenichi Kamiya

class ProgressBar

  class Error < StandardError; end

  VERSION = '0.12.a'.freeze
  DEFAULT_WIDTH = 80
  TITLE_WIDTH = 14
  FORMAT = "%-#{TITLE_WIDTH}s %3d%% %s %s".freeze

  attr_reader   :title
  attr_reader   :current
  attr_reader   :total
  
  attr_accessor :start_time
  
  attr_writer   :bar_mark
  #~ attr_writer   :format
  attr_writer   :format_arguments

  def initialize(title, total, out=STDERR)
    @title = title
    @total = total
    @out = out
    @terminal_width = DEFAULT_WIDTH
    @bar_mark = 'o'.freeze
    @current = 0
    @previous = 0
    @finished_p = false
    @start_time = Time.now
    @previous_time = @start_time
    @eta_previous = nil
    @eta_previous_time = nil
    @eta_throughput = nil
    @format_arguments = [:title, :percentage, :bar, :stat]
    clear
    show
  end

  # @return [void]
  def clear
    @out.print "\r"
    @out.print(' ' * (term_width - 1))
    @out.print "\r"
    
    nil
  end

  # @return [void]
  def finish
    @current = @total
    @finished_p = true
    show
  end

  def finished?
    @finished_p
  end

  # @return [void]
  def file_transfer_mode
    @format_arguments = [:title, :percentage, :bar, :stat_for_file_transfer]
    nil
  end

  # @return [void]
  def long_running
    @format_arguments = [:title, :percentage, :bar, :stat_for_long_run]
    nil
  end

  # @return [void]
  def halt
    @finished_p = true
    show
  end

  # @param [Integer] step
  def inc(step=1)
    @current += step
    @current = @total if @current > @total
    show_if_needed
    @previous = @current
  end

  def set(count)
    if (count < 0) || (count > @total)
      raise Error, "invalid count: #{count} (total: #{@total})"
    end

    @current = count
    show_if_needed
    @previous = @current
  end

  # @return [String]
  def inspect
    "#<ProgressBar:#{@current}/#{@total}>"
  end

  private

  # @return [String]
  def fmt_bar
    "|#{@bar_mark * bar_width}#{' ' *  (@terminal_width - bar_width)}|"
  end

  # @return [Integer]
  def bar_width
    percentage * @terminal_width / 100
  end

  # @return [String]
  def fmt_percentage
    percentage.to_s
  end

  # @return [String]
  def fmt_stat
    finished? ? fmt_elapsed : fmt_eta
  end

  # @return [String]
  def fmt_stat_for_long_run
    finished? ? fmt_elapsed : fmt_eta_running_average
  end

  # @return [String]
  def fmt_stat_for_file_transfer
    [fmt_bytes, fmt_transfer_rate, (finished? ? fmt_elapsed : fmt_eta)].join(' ')
  end

  # @return [String]
  def fmt_title
    "#{@title[0, (TITLE_WIDTH - 1)]}:"
  end

  # @param [Number] bytes
  # @return [String]
  def fmt_bytes_for(bytes)
    case bytes
    when ->n{n < 1024}
      sprintf("%6dB", bytes)
    when ->n{n < 1024 * 1000}                # 1000KB
      sprintf("%5.1fKB", (bytes.to_r / 1024).to_f)
    when ->n{n < 1024 * 1024 * 1000}         # 1000MB
      sprintf("%5.1fMB", (bytes.to_r / 1024 / 1024).to_f)
    else
      sprintf("%5.1fGB", (bytes.to_r / 1024 / 1024 / 1024).to_f)
    end
  end

  # @return [String]
  def fmt_transfer_rate
    sprintf("%s/s", fmt_bytes_for(bytes_per_second))
  end
  
  # @return [Float]
  def bytes_per_second
    (@current.to_r / (Time.now - @start_time)).to_f
  end

  # @return [String]
  def fmt_bytes
    fmt_bytes_for @current
  end

  # @param [Integer, #to_int] interval
  # @return [String]
  def fmt_interval_for(interval)
    interval = interval.to_int
    sec = interval % 60
    min  = (interval / 60) % 60
    hour = interval / 3600
    sprintf("% 3d:%02d:%02d", hour, min, sec)
  end

  # ETA stands for Estimated Time of Arrival.
  # @return [String]
  def fmt_eta
    if @current.zero?
      "ETA:  --:--:--"
    else
      _elapsed = elapsed
      eta = _elapsed * @total / @current - _elapsed;
      "ETA: #{fmt_interval_for eta}"
    end
  end

  # Compute ETA with running average (better suited to long running tasks)
  # @return [String]
  def fmt_eta_running_average
    now = Time.now

    # update throughput running average
    if @total > 0 && @eta_previous && @eta_previous_time
      current_elapsed = @current - @eta_previous
      alpha = 0.9 ** current_elapsed
      current_progress = 1.0 * current_elapsed
      current_throughput = current_progress / (now - @eta_previous_time)
      @eta_throughput = (
        if @eta_throughput
          @eta_throughput * alpha + current_throughput * (1-alpha)
        else
          current_throughput
        end
      )
    end

    @eta_previous = @current
    @eta_previous_time = now

    if @eta_throughput && @eta_throughput > 0
      eta = (@total - @current) / @eta_throughput
      "ETA: #{fmt_interval_for eta}"
    else
      "ETA:  --:--:--"
    end
  end

  # @return [String]
  def fmt_elapsed
    "Time: #{fmt_interval_for elapsed}"
  end
  
  # @return [Float]
  def elapsed
    Time.now - @start_time
  end

  # @return [String]
  def eol
    finished? ? "\n" : "\r"
  end

  # @return [Integer]
  def percentage
    @total.zero? ? 100 : (@current * 100 / @total)
  end

  # @return [Integer]
  def term_width
    case
    when /\A\d+\z/ =~ ENV['COLUMNS']
      ENV.fetch('COLUMNS').to_i
    when (/java/i =~ RUBY_PLATFORM || (!STDIN.tty? && ENV['TERM'])) && shell_command_exists?('tput')
      `tput cols`.to_i
    when STDIN.tty? && shell_command_exists?('stty')
      `stty size`.scan(/\d+/).map(&:to_i)[1]
    else
      DEFAULT_WIDTH
    end
  rescue
    DEFAULT_WIDTH
  end

  def shell_command_exists?(command)
    ENV.fetch('PATH').split(File::PATH_SEPARATOR).any?{|d| File.exists? File.join(d, command) }
  end

  # @return [void]
  def show
    arguments = @format_arguments.map {|method|
      __send__ :"fmt_#{method}"
    }

    line = sprintf(FORMAT, *arguments)

    width = term_width

    if line.length == width - 1
      @out.print(line + eol)
      @out.flush
    elsif line.length >= width
      @terminal_width = [@terminal_width - (line.length - width + 1), 0].max
      if @terminal_width == 0
        @out.print(line + eol)
      else
        show
      end
    else # line.length < width - 1
      @terminal_width += width - line.length + 1
      show
    end

    @previous_time = Time.now
    
    nil
  end

  # @return [void]
  def show_if_needed
    if @total.zero?
      cur_percentage = 100
      prev_percentage = 0
    else
      cur_percentage  = (@current  * 100 / @total).to_i
      prev_percentage = (@previous * 100 / @total).to_i
    end

    # Use "!=" instead of ">" to support negative changes
    if (cur_percentage != prev_percentage) || (Time.now - @previous_time >= 1) || finished?
      show
    end
    
    nil
  end

end