require 'spec_helper'
require 'securerandom'
require 'thread'

describe ThreadAttrAccessor do
  let(:target) do
    Module.new do
      def self.name
        @name ||= SecureRandom.uuid
      end

      extend ThreadAttrAccessor
    end
  end

  it "returns a default value when no value was set" do
    target.module_eval do
      thread_attr_accessor :setting, default: -> { :default_setting }
    end

    value_on_thread = Thread.new {
      target.setting = :other_setting
      target.setting
    }.value

    expect(target.setting).to  eq(:default_setting)
    expect(value_on_thread).to eq(:other_setting)
  end

  it "isolates writes to the thread" do
    target.module_eval do
      thread_attr_accessor :setting
    end

    target.setting = :original_setting

    value_on_thread = Thread.new {
      target.setting = :other_setting
      target.setting
    }.value

    expect(target.setting).to  eq(:original_setting)
    expect(value_on_thread).to eq(:other_setting)
  end

  shared_examples "inheritance context" do |name, new_context|
    it "allows inheritance between #{name}s" do
      target.module_eval do
        thread_attr_accessor :setting, inherit: true
      end

      target.setting = :original_setting
      value_on_new_context = new_context.call { target.setting }

      expect(value_on_new_context).to eq(:original_setting)
    end

    it "allows overrides on child #{name}s, without overwriting the parent" do
      target.module_eval do
        thread_attr_accessor :setting, inherit: true
      end

      target.setting = :original_setting

      initial_value_on_new_context, value_on_new_context = new_context.call {
        initial = target.setting
        target.setting = :new_setting
        [initial, target.setting]
      }

      expect(target.setting).to          eq(:original_setting)
      expect(initial_value_on_new_context).to eq(:original_setting)
      expect(value_on_new_context).to         eq(:new_setting)
    end

    it "returns the default value on child #{name}s if nothing was set on the parent" do
      target.module_eval do
        thread_attr_accessor :setting, inherit: true, default: -> { :default_setting }
      end

      value_on_new_context = new_context.call { target.setting }

      expect(value_on_new_context).to eq(:default_setting)
    end

    it "prefers the value set on a parent to the default value" do
      target.module_eval do
        thread_attr_accessor :setting, inherit: true, default: -> { :default_setting }
      end

      target.setting = :original_setting
      value_on_new_context = new_context.call { target.setting }

      expect(value_on_new_context).to eq(:original_setting)
    end

    it "continues to return the default if a child writes the value" do
      target.module_eval do
        thread_attr_accessor :setting, inherit: true, default: -> { :default_setting }
      end

      new_context.call { target.setting = :new_setting }

      expect(target.setting).to eq(:default_setting)
    end
  end

  context "inheritance between threads" do
    include_examples "inheritance context", "thread", ->(&block) {
      Thread.new(&block).value
    }
  end

  context "inheritance between fibers" do
    include_examples "inheritance context", "fiber", ->(&block) {
      Fiber.new(&block).resume
    }
  end
end
