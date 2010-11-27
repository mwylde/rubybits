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
		
		tf = TestFormat6.new(:field1 => -10, :field2 => -4, :field3 => -7)
		tf.to_s.bytes.to_a.should == [0b11110110, 0b11001001]
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
	
	it "should allow variable length fields whose lengths are specified by another field" do
		class TestFormat11 < RubyBits::Structure
			unsigned :field1,   8, "Field1"
			unsigned :field2,   4, "Field2"
			unsigned :field3,   4, "Flag"
			variable :text,        "text", :length => :field2
			unsigned :checksum, 8, "Checksum (sum of all previous fields)"
			
			checksum :checksum do |bytes|
				bytes[0..-2].inject{|sum, byte| sum += byte} & 255
			end
		end
		
		tf = TestFormat11.new(:field1 => 0x77, :field2 => 0x04, :field3 => 0x0F, :text => "abc")
		checksum = (0x77 + 0x4F + "abc".bytes.to_a.reduce(:+)) & 255
		tf.checksum.should == checksum
		
		tf.to_s.bytes.to_a.should == [0x77, 0x4F, 0x61, 0x62, 0x63, 0, checksum]
	end
	
	it "should fail when setting an invalid value for a field" do
		class TestFormat12 < RubyBits::Structure
			unsigned :field1,   8,  "Field1"
			unsigned :field2,   4,  "Field2"
			unsigned :field3,   16, "Flag"
			variable :text,         "text"
		end
		
		expect {TestFormat12.new(:field1 => 257, :field2 => 0x4, :field3 => 500)}.to raise_error(RubyBits::FieldValueException)
		tf = TestFormat12.new
		expect {tf.field2 = 0x44}.to raise_error(RubyBits::FieldValueException)
		expect {tf.field3 = 0x44122}.to raise_error(RubyBits::FieldValueException)
		expect {tf.text = 55}.to raise_error(RubyBits::FieldValueException)
	end
end

describe "parsing" do
	it "should correctly determine a valid message" do
		class TestFormat13 < RubyBits::Structure
			unsigned :field1,   8,  "Field1"
			unsigned :field2,   4,  "Field2"
			unsigned :field3,   4,  "Field3"
			signed   :field4,   8,  "Field4"
			unsigned :field5,  16,  "Short field"
		end
		TestFormat13.valid_message?([0x34, 0x41, 0b11001001, 0x44, 0x55].pack("c*")).should == true
		TestFormat13.valid_message?([0x44, 0x99, 0x44, 0x11, 0x12, 0x55, 0x11].pack("c*")).should == false
		TestFormat13.valid_message?([0x11, 0x11, 0x44, 0x11, 0x44].pack("c*")).should == false
		TestFormat13.valid_message?("").should == false
		
		tf = TestFormat13.from_string([0x34, 0x41, 0b11001001, 0x55, 0x11].pack("c*"))

		tf.field1.should == 0x34
		tf.field2.should == 0x04
		tf.field3.should == 0x01
		tf.field4.should == -55
		tf.field5.should == 0x5511
	end
	it "should correctly determine a valid message with variable length fields" do
		class TestFormat14 < RubyBits::Structure
			unsigned :field1,   8, "Field1"
			unsigned :size,     4, "Length"
			unsigned :field3,   4, "Field3"
			variable :text,        "text", :length => :size, :unit => :byte
		end
		TestFormat14.valid_message?([0x44, 0x3F].pack("cc") + "abc").should == true
		TestFormat14.valid_message?([0x33, 0x1C].pack("cc") + "ab").should == false
		TestFormat14.valid_message?([0x11, 0x5C].pack("cc") + "abc").should == false
		
		tf = TestFormat14.from_string([0x34, 0x3F].pack("c*") + "abc")
		tf.field1.should == 0x34
		tf.size.should == 0x03
		tf.field3.should == 0x0F
		tf.text.should == "abc"
	end
	it "should correctly determine a valid message with variable length fields and checksum" do
		class TestFormat15 < RubyBits::Structure
			unsigned :field1,   8, "Field1"
			unsigned :size,     4, "size"
			variable :text,        "text", :length => :size, :unit => :byte
			unsigned :checksum, 8, "checksum"
		
			checksum :checksum do |bytes|
				bytes.reduce(:+) & 255
			end
		end
		
		TestFormat15.valid_message?([0x5C, 0x36, 0x16, 0x26, 0x3F, 0xE0].pack("c*")).should == true
		TestFormat15.valid_message?([0x5C, 0x36, 0x16, 0x26, 0x3F, 0xD0].pack("c*")).should == false
		TestFormat15.valid_message?([0x5C, 0x36, 0x16, 0x26, 0x30, 0xE0].pack("c*")).should == false
		
		tf = TestFormat15.from_string([0x5C, 0x36, 0x16, 0x26, 0x3F, 0xE0].pack("c*"))
		tf.field1.should == 0x5C
		tf.size.should == 3
		tf.text.should == "abc"
		tf.checksum.should == 254
	end
#	it "should parse fix-width format" do 
#		class TestFormat15 < RubyBits::Structure
#			unsigned :field1,   8,  "Field1"
#			unsigned :field2,   4,  "Field2"
#			unsigned :field3,   4,  "Field3"
#			signed   :field4,   8,  "Field4"
#		end
#
#		tf = TestFormat15.parse([0x34, 0x41, 0b11001001].pack("c*"))
#		tf.field1.should == 0x34
#		tf.field2.should == 0x04
#		tf.field3.should == 0x01
#		tf.field4.should == -55
#	end
end