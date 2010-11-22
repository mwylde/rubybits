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
		
		tf = TestFormat3.new(:field1 => 0x77, :field2 => 0x06, :field3 => 0x0F, :field4 => 0x726b)
		tf.field1.should == 0x77
		tf.field2.should == 0x06
		tf.field3.should == 0x0F
		tf.field4.should == 0x726b
	end
	
	it "should allow creation of bitstrings from structure spec" do
		class TestFormat4 < RubyBits::Structure
			unsigned :field1,  8,  "Field1"
			unsigned :field2,  4,  "Field2"
			unsigned :field3,  4,  "Flag"
			unsigned :field4,  16, "Field3"
		end
		
		tf = TestFormat4.new(:field1 => 0x77, :field2 => 0x06, :field3 => 0x0F, :field4 => 0x726b)
		tf.to_s.should == "work"
	end
	
	it "should allow weird field sizes" do
		class TestFormat5 < RubyBits::Structure
			unsigned :field1,  5,  "Field1"
			unsigned :field2,  3,  "Field2"
			unsigned :field3,  6,  "Flag"
			unsigned :field4,  4, "Field3"
			unsigned :field5, 11, "Field5"
			unsigned :field6,  2, "Field6"
		end
		
		tf = TestFormat5.new(:field1 => 0b11010, :field2 => 0b001, :field3 => 0b101010, :field4 => 0b1011, :field5 => 0b11101010001, :field6 => 0b11)
		tf.to_s.bytes.to_a.should == [0b11010001, 0b10101010, 0b11111010, 0b10001110]
	end
end

