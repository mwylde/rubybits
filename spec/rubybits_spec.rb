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
	
	it "should allow signed integers" do
		class TestFormat6 < RubyBits::Structure
			signed :field1, 8, "Field1"
			signed :field2, 4, "Field2"
			signed :field3, 4, "Field3"
		end
		
		tf = TestFormat6.new(:field1 => -10, :field2 => -4, :field3 => -8)
		tf.to_s.bytes.to_a.should == [0b11110110, 0b11001000]
	end
	
	it "should calculate checksum correctly" do
		class TestFormat7 < RubyBits::Structure
			unsigned :field1,  8,  "Field1"
			unsigned :field2,  4,  "Field2"
			unsigned :field3,  4,  "Flag"
			unsigned :field4,  16, "Field3"
			unsigned :checksum, 8, "Checksum (sum of all previous fields)"
			
			checksum :checksum do |bytes|
				bytes[0..-2].inject{|sum, byte| sum += byte} & 255
			end
		end
		
		tf = TestFormat7.new(:field1 => 0x77, :field2 => 0x06, :field3 => 0x0F, :field4 => 0x726b)
		tf.to_s.bytes.to_a.should == "work".bytes.to_a << ((0x77 + 0x6F + 0x72 + 0x6B) & 255)
	end
	
	it "should calculate checksum when accessed" do
		class TestFormat8 < RubyBits::Structure
			unsigned :field1,  8,  "Field1"
			unsigned :field2,  4,  "Field2"
			unsigned :field3,  4,  "Flag"
			unsigned :field4,  16, "Field3"
			unsigned :checksum, 8, "Checksum (sum of all previous fields)"
			
			checksum :checksum do |bytes|
				bytes[0..-2].inject{|sum, byte| sum += byte} & 255
			end
		end
		
		tf = TestFormat8.new(:field1 => 0x77, :field2 => 0x06, :field3 => 0x0F, :field4 => 0x726b)
		tf.checksum.should == (0x77 + 0x6F + 0x72 + 0x6B) & 255
	end
	
	it "should allow variable length fields" do
		class TestFormat9 < RubyBits::Structure
			unsigned :field1,   8, "Field1"
			unsigned :field2,   4, "Field2"
			unsigned :field3,   4, "Flag"
			variable :field4,      "text"
			unsigned :checksum, 8, "Checksum (sum of all previous fields)"
			
			checksum :checksum do |bytes|
				bytes[0..-2].inject{|sum, byte| sum += byte} & 255
			end
		end
		
		tf = TestFormat9.new(:field1 => 0x77, :field2 => 0x06, :field3 => 0x0F, :field4 => "hello")
		checksum = (0x77 + 0x6F + "hello".bytes.to_a.reduce(:+)) & 255
		tf.checksum.should == checksum
		
		tf.to_s.bytes.to_a.should == [0x77, 0x6F] + "hello".bytes.to_a << checksum
	end
	
	it "should allow variable length fields that are not byte aligned" do
		class TestFormat10 < RubyBits::Structure
			unsigned :field1,   8, "Field1"
			unsigned :field2,   4, "Field2"
			unsigned :field3,   4, "Flag"
			unsigned :field4,   6, "Not byte aligned"
			variable :text,        "text"
			unsigned :checksum, 8, "Checksum (sum of all previous fields)"
			
			checksum :checksum do |bytes|
				bytes[0..-2].inject{|sum, byte| sum += byte} & 255
			end
		end
		
		string = [119, 111, 201, 133, 137, 140]
		tf = TestFormat10.new(:field1 => 0x77, :field2 => 0x06, :field3 => 0x0F, :field4 => 0x32, :text => "abc")
		checksum = string.reduce(:+) & 255
		tf.checksum.should == checksum
		
		tf.to_s.bytes.to_a.should == [119, 111, 201, 133, 137, 141, 36]
	end
	
end

