# frozen_string_literal: true

require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../lib/sensething'
require 'pathname'

describe Sysfs::Hwmon do # rubocop:disable Metrics/BlockLength
  describe '#parse_attr_by_name' do # rubocop:disable Metrics/BlockLength
    it 'should parse voltage input' do
      Pathname.any_instance.stubs(:realpath).returns Pathname.new('/real/path')
      Pathname.any_instance.stubs(:file?).returns true

      in0_input = Sysfs::Hwmon.parse_attr_by_name('/hwmon0/in0_input')
      assert_kind_of Sysfs::Attribute, in0_input
      assert_equal 'mV', in0_input.unit
      assert_equal '/real/path', in0_input.path.to_s
    end

    it 'should parse voltage min' do
      Pathname.any_instance.stubs(:realpath).returns Pathname.new('/real/path')
      Pathname.any_instance.stubs(:file?).returns true

      in0_min = Sysfs::Hwmon.parse_attr_by_name('/hwmon0/in0_min')
      assert_kind_of Sysfs::Attribute, in0_min
      assert_equal 'mV', in0_min.unit
      assert_equal '/real/path', in0_min.path.to_s
    end

    it 'should parse voltage max' do
      Pathname.any_instance.stubs(:realpath).returns Pathname.new('/real/path')
      Pathname.any_instance.stubs(:file?).returns true

      in0_max = Sysfs::Hwmon.parse_attr_by_name('/hwmon0/in0_max')
      assert_kind_of Sysfs::Attribute, in0_max
      assert_equal 'mV', in0_max.unit
      assert_equal '/real/path', in0_max.path.to_s
    end

    it 'should parse voltage label' do
      Pathname.any_instance.stubs(:realpath).returns Pathname.new('/real/path')
      Pathname.any_instance.stubs(:file?).returns true

      in0_label = Sysfs::Hwmon.parse_attr_by_name('/hwmon0/in0_label')
      assert_kind_of Sysfs::Attribute, in0_label
      assert_nil in0_label.unit
      assert_equal '/real/path', in0_label.path.to_s
    end
  end
end
