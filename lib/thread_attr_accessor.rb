require_relative "thread_attr_accessor/version"
require_relative 'core_ext/thread/parent_thread'

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

  def self.search_in_ancestor_threads(key)
    ancestor = Thread.current.parent_thread

    until ancestor.nil? || (ancestor_value = ancestor[key])
      ancestor = ancestor.parent_thread
    end

    ancestor_value
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
        Thread.current.thread_variable_set(thread_key, value)
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
        if Thread.current.thread_variable?(thread_key)
          Thread.current.thread_variable_get(thread_key)
        else
          default_value = get_default.call(thread_key)
          Thread.current.thread_variable_set(thread_key, default_value)
        end
      }
    else
      get_value = ->(thread_key) {
        Thread.current.thread_variable_get(thread_key)
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
