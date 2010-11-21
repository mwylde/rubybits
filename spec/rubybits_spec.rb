require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Structure" do
	it "should allow definition of a format with unsigned fields" do
		class TestFormat1 < RubyBits::Structure
			unsigned :field1,  8, "Field1"
			unsigned :field2,  4, "Field2"
			unsigned :flag,    1,  "Flag"
			unsigned :field3,  16, "Field3"
		end
	end
	
	it "should allow accessing fields created" do
		class TestFormat2 < RubyBits::Structure
			unsigned :field1,  8, "Field1"
			unsigned :field2,  4, "Field2"
			unsigned :flag,    1,  "Flag"
			unsigned :field3,  16, "Field3"
		end
		
		tf = TestFormat2.new
		tf.field1 = 0x40
		tf.field1.should == 0x40
	end
	
	it "should allow initialization with data" do
		class TestFormat3 < RubyBits::Structure
			unsigned :field1,  8,  "Field1"
			unsigned :field2,  4,  "Field2"
			unsigned :field3,  4,  "Flag"
			unsigned :field4,  16, "Field3"
		end
		
		tf = TestFormat3.new(:field1 => 0x40, :field2 => 4, :field3 => 8, :field4 => 0x41BB)
		tf.field1.should == 0x40
		tf.field2.should == 4
		tf.field3.should == 8
		tf.field4.should == 0x41BB
	end
	
	it "should allow creation of bitstrings from structure spec" do
		class TestFormat4 < RubyBits::Structure
			unsigned :field1,  8,  "Field1"
			unsigned :field2,  4,  "Field2"
			unsigned :field3,  4,  "Flag"
			unsigned :field4,  16, "Field3"
		end
		
		tf = TestFormat4.new(:field1 => 0x40, :field2 => 4, :field3 => 8, :field4 => 0x41BB)
		tf.to_s.should== [0x40, 4*16+8, 0x41, 0xBB].pack("cccc")
	end
end


