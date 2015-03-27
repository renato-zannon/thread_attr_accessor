# Ruby doesn't provide a standard way to access another fiber's variables

require 'hamster'

class Fiber
  module Storage
    def storage
      @storage ||= Hamster.hash
    end

    def fiber_variable?(key)
      storage.has_key?(key)
    end

    def fiber_variable_set(key, value)
      @storage = storage.put(key, value)
      value
    end

    def fiber_variable_get(key)
      storage.get(key)
    end
  end

  prepend Storage
end
