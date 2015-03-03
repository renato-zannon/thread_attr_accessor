# Ruby doesn't provide a standard way to look up a thread's parent

class Thread
  module ParentThread
    attr_reader :parent_thread

    def initialize(*args, **opts, &block)
      @parent_thread = Thread.current
      super
    end
  end

  prepend ParentThread

  # For the currently running threads, assume they were created by the main
  # thread - which should be true during the system initialization
  list.each do |thread|
    next if thread == Thread.main

    if thread.parent_thread.nil?
      thread.instance_eval { @parent_thread = Thread.main }
    end
  end
end
