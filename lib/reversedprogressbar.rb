require_relative 'progressbar'

class ReversedProgressBar < ProgressBar

  def do_percentage
    100 - super
  end

end
