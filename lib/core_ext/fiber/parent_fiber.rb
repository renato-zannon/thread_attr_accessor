# Ruby doesn't provide a standard way to look up a fiber's parent

require 'fiber'

class Fiber
  module ParentFiber
    attr_reader :parent_fiber

    def initialize(&block)
      @parent_fiber = Fiber.current
      super(&block)
    end
  end

  prepend ParentFiber
end
