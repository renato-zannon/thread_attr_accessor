require 'fiber'

require_relative "thread_attr_accessor/version"
require_relative 'core_ext/thread/parent_thread'
require_relative 'core_ext/fiber/parent_fiber'
require_relative 'core_ext/fiber/storage'

# `extend` this module on your class/module to get per-thread class attribute
# accessors. Example:
#
# class MyClass
#   extend ThreadAttrAccessor
#
#   thread_attr_accessor :setting
# end
#
# MyClass.setting = :original
#
# threads = [
#   Thread.new { MyClass.setting = :foo; puts MyClass.setting },
#   Thread.new { MyClass.setting = :bar; puts MyClass.setting },
# ]
#
# threads.each(&:join)
# MyClass.setting == :original # true
module ThreadAttrAccessor
  def self.thread_accessor_key(base, name)
    "#{base.name}.#{name}"
  end

  class FiberStorage
    attr_reader :fiber, :thread
    def initialize(fiber = Fiber.current, thread = Thread.current)
      @fiber  = fiber
      @thread = thread
    end

    def [](key)
      fiber.fiber_variable_get(key)
    end

    def []=(key, value)
      fiber.fiber_variable_set(key, value)
      if fiber.parent_fiber.nil?
        thread.thread_variable_set(key, value)
      end

      value
    end

    def has_key?(key)
      fiber.fiber_variable?(key)
    end
  end

  class ThreadStorage
    attr_reader :thread
    def initialize(thread)
      @thread = thread
    end

    def [](key)
      thread.thread_variable_get(key)
    end

    def []=(key, value)
      thread.thread_variable_set(key, value)
    end

    def has_key?(key)
      !!thread.thread_variable_get(key)
    end
  end

  def self.search_in_ancestor_threads(key)
    fiber  = Fiber.current
    thread = Thread.current

    until fiber.nil?
      storage = FiberStorage.new(fiber, thread)

      if storage.has_key?(key)
        return storage[key]
      else
        fiber = fiber.parent_fiber
      end
    end

    until thread.nil?
      storage = ThreadStorage.new(thread)

      if storage.has_key?(key)
        return storage[key]
      else
        thread = thread.parent_thread
      end
    end

    nil
  end

  def self.extended(base)
    mod = Module.new

    unless base.const_defined?(:ThreadAttributeAccessors, false)
      base.const_set(:ThreadAttributeAccessors, mod)
      base.extend(mod)
    end
  end

  def thread_attr_writer(*names, private: false, **opts)
    mod = const_get(:ThreadAttributeAccessors)

    names.each do |name|
      thread_key = ThreadAttrAccessor.thread_accessor_key(self, name)

      mod.send(:define_method, "#{name}=") do |value|
        FiberStorage.new[thread_key] = value
        value
      end

      if private
        mod.send :private, "#{name}="
      end
    end
  end

  def thread_attr_reader(*names, default: nil, inherit: false, private: false, **opts)
    if default && inherit
      get_default = ->(thread_key) {
        ThreadAttrAccessor.search_in_ancestor_threads(thread_key) ||
        default.call
      }
    elsif inherit
      get_default = ThreadAttrAccessor.method(:search_in_ancestor_threads)
    elsif default
      get_default = ->(*) { default.call }
    end

    if get_default
      get_value = ->(thread_key) {
        storage = FiberStorage.new
        storage[thread_key] ||= get_default.call(thread_key)
      }
    else
      get_value = ->(thread_key) {
        FiberStorage.new[thread_key]
      }
    end

    mod = const_get(:ThreadAttributeAccessors)

    names.each do |name|
      thread_key = ThreadAttrAccessor.thread_accessor_key(self, name)

      mod.send(:define_method, name) do
        get_value.call(thread_key)
      end

      if private
        mod.send :private, name
      end
    end
  end

  def thread_attr_accessor(*names, private: false, **opts)
    private_reader = private.to_s == "reader" || private == true
    private_writer = private.to_s == "writer" || private == true

    thread_attr_reader(*names, private: private_reader, **opts)
    thread_attr_writer(*names, private: private_writer, **opts)
  end
end
