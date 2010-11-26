# Provides various utilities for working with binary formats.
module RubyBits
	# You can subclass RubyBits::Strcuture to define new binary formats. This
	# can be used for lots of purposes: reading binary data, communicating in
	# binary formats (like TCP/IP, http, etc).
	# 
	# @example
	# 	class NECProjectorFormat < RubyBits::Structure
	# 	  unsigned :id1,     1.byte,    "Identification data assigned to each command"
	# 	  unsigned :id2,     1.byte,    "Identification data assigned to each command"
	# 	  unsigned :p_id,    1.byte,    "Projector ID"
	# 	  unsigned :m_code,  4.bits,    "Model code for projector"
	# 	  unsigned :len,     12.bits,   "Length of data in bytes"
	# 	  variable :data,    1.byte,    "Packet data", :length => :len
	# 	  unsigned :checksum,1.byte,    "Checksum"
	# 
	# 	  checksum :checksum do |bytes|
	# 	    bytes[0..-2].inject{|sum, byte| sum += byte} & 255
	# 	  end
	#   end
	#  	
	#   NECProjectorFormat.parse(buffer)
	#   # => [<NECProjectorFormat>, <NECProjectorFormat>]
	#   
	#   NECProjectorFormat.new(:id1 => 0x44, :id2 => 2, :p_id => 0, :m_code => 0, :len => 5, :data => "hello").to_s.bytes.to_a
	#   # => [0x44, 0x2, 0x05, 0x00, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x5F]
	class Structure < Object
		class << self
			[:unsigned, :signed, :text].each{|kind|
				define_method kind do |name, size, description, *options|
					field(kind, name, size, description, options)
				end
			}
			
			define_method :variable do |name, description, *options|
				field(:variable, name, nil, description, options)
			end
			
			# Sets the checksum field. Setting a checksum field alters the functionality
			# in several ways: the checksum is automatically calculated and set, and #parse
			# will only consider a bitstring to be a valid instance of the structure if it
			# has a checksum appropriate to its data.
			# @param field [Symbol] the field that contains the checksum data
			# @yield [bytes] block that should calculate the checksum given bytes, which is
			# 	an array of bytes representing the full structure, with the checksum field
			# 	set to 0
			def checksum field, &block
				@_checksum_field = [field, block]
				self.class_eval %{
					def #{field}
						calculate_checksum unless @_calculating_checksum || @_checksum_cached
						@__#{field}
					end
				}
			end
			
			# A list of the fields in the class
			def fields; @_fields; end
			
			# The checksum field
			def checksum_field; @_checksum_field; end

			private
			def field kind, name, size, description, options
				@_fields ||= []
				@_fields << [kind, name, size, description, options]
				self.class_eval %{
					def #{name}= val
						@__#{name} = val
						@_checksum_cached = false
					end
				}
				unless checksum_field && checksum_field[0] == name
					self.class_eval %{
						def #{name}
							@__#{name}
						end
					}
				end
			end
		end
		
		# Creates a new instance of the class. You can pass in field names to initialize to
		# set their values.
		# @example
		# 	MyStructure.new(:field1 => 44, :field2 => 0x70, :field3 => "hello")
		def initialize(values={})
			values.each{|key, value|
				self.send "#{key}=", value
			}
			@_checksum_cached = false
		end
				
		# Returns a binary string representation of the structure according to the fields defined
		# and their current values.
		# @return [String] bit string representing struct
		def to_s
			if self.class.checksum_field && !@_checksum_cached
				self.calculate_checksum
			end
			to_s_without_checksum
		end
		
		# Calculates and sets the checksum bit according to the checksum field defined by #checksum
		def calculate_checksum
			if self.class.checksum_field
				@_calculating_checksum = true
				self.send("#{self.class.checksum_field[0]}=", 0)
				checksum = self.class.checksum_field[1].call(self.to_s_without_checksum.bytes.to_a)
				self.send("#{self.class.checksum_field[0]}=", checksum)
				@_checksum_cached = true
				@_calculating_checksum = false
			end
		end
		
		protected				
		# Returns the input number with the specified bit set to the specified value
		# @param byte [Fixnum] Number to be modified
		# @param bit [Fixnum] Bit number to be set 
		# @param value [Fixnum: {0, 1}] Value to set (either 0 or 1)
		# @return [Fixnum] byte with bit set to value
		def set_bit(byte, bit, value)
			#TODO: this can probably be made more efficient
			byte & (1<<bit) > 0 == value > 0 ? byte : byte ^ (1<<bit)
		end
		
		# Returns the value at position bit of byte
		# @param number [Fixnum] Number to be queried
		# @param bit [Fixnum] bit of interest
		# @return [Fixnum: {0, 1}] 0 or 1, depending on the value of the bit at position bit of number
		def get_bit(number, bit)
			number & (1<<bit) > 0 ? 1 : 0
		end
		
		def to_s_without_checksum
			offset = 0
			buffer = []
			# This method works by iterating through each bit of each field and setting the bits in
			# the current output byte appropriately.
			self.class.fields.each{|field|
				kind, name, size, description, options = field
				data = self.send(name)
				case kind
				when :variable
					data ||= ""
					if offset % 8 == 0
						buffer += data.bytes.to_a
					else
						data.each_byte{|byte|
							8.times{|bit|
								buffer << 0 if offset % 8 == 0
								buffer[-1] |= get_bit(byte, 7-bit) << 7-(offset % 8)
								offset += 1
							}
						}
					end
					
				else
					data ||= 0
					size.times do |bit|
						buffer << 0 if offset % 8 == 0
						buffer[-1] |= get_bit(data, size-bit-1) << 7-(offset % 8)
						offset += 1
					end
				end
			}
			#if self.class.to_s == "TestFormat10"
			#	puts buffer.collect{|x| "%08b" % x}.inspect
			#	puts [119, 111, 201, 133, 137, 142, 72].collect{|x| "%08b" % x}.inspect
			#end
			buffer.pack("c*")	
		end
	end
	
end