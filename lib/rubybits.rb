# Provides various utilities for working with binary formats.
module RubyBits
	# Raised when you set a field to a value that is invalid for the type of
	# the field (i.e., too large or the wrong type)
	class FieldValueException < Exception; end
		
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
			FIELD_TYPES = {
				:unsigned => {
					:validator => proc{|val, size, options| val.is_a?(Fixnum) && val < 2**size},
					:unpack => proc {|s, offset, length, options|
						number = 0
						s_iter = s.bytes
						byte = 0
						# advance the iterator by the number of whole or partial bytes in the offset (offset div 8)
						((offset.to_f/8).ceil).times{|i| byte = s_iter.next}
						
						length.times{|bit|
							byte = s_iter.next if offset % 8 == 0
							src_bit = (7-offset%8)
							number |= (1 << (length-1-bit)) if (byte & (1 << src_bit)) > 0
							#puts "Reading: #{src_bit} from #{"%08b" % byte} => #{(byte & (1 << src_bit)) > 0 ? 1 : 0}"
							offset += 1
						}
						number
					}
				},
				:signed => {
					:validator => proc{|val, size, options| val.is_a?(Fixnum) && val.abs < 2**(size-1)},
					:unpack => proc{|s, offset, length, options|
						number = 0
						s_iter = s.bytes
						byte = 0
						# advance the iterator by the number of whole bytes in the offset (offset div 8)
						((offset.to_f/8).ceil).times{|i| byte = s_iter.next}
						# is this a positive number? yes if the most significant bit is 0
						byte = s_iter.next if offset % 8 == 0
						pos = byte & (1 << offset%8) == 0
						
						length.times{|bit|
							byte = s_iter.next if offset % 8 == 0 && bit > 7
							src_bit = (7-offset%8)
							number |= (1 << (length-1-bit)) if ((byte & (1 << src_bit)) > 0) ^ (!pos)
							offset += 1
						}
						number += 1
						puts "Pos #{pos}, number: #{number}"
						pos ? number : -number
					}
				},
				:variable => {
					:validator => proc{|val, size, options| val.is_a?(String)},
					:unpack => proc{|s, offset, length, options|
						output = []
						s_iter = s.bytes
						byte = 0
						# advance the iterator by the number of whole bytes in the offset (offset div 8)
						((offset.to_f/8).ceil).times{|i| byte = s_iter.next}
						length.times{|bit|
							byte = s_iter.next if offset % 8 == 0
							output << 0 if bit % 8 == 0
							
							src_bit = (7-offset%8)
							output[-1] |= (1 << (7-bit%8)) if (byte & (1 << src_bit)) > 0
							offset += 1
						}
						output.pack("c*")
					}
				}
			}
			FIELD_TYPES.each{|kind, field|
				define_method kind do |name, size, description, *options|
					field(kind, name, size, description, field[:validator], options[0])
				end
			}
			
			define_method :variable do |name, description, *options|
				field(:variable, name, nil, description, FIELD_TYPES[:variable][:validator], options[0])
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
			
			# Determines whether a string is a valid message
			# @param string [String] a binary string to be tested
			# @return [Boolean] whether the string is in fact a valid message
			def valid_message? string
				!!from_string(string)[0]
			end
			
			# Parses a message from the binary string assuming that the message starts at the first byte
			# of the string
			# @param string [String] a binary string to be interpreted
			# @return [Array<Structure, string>] a pair with the first element being a structure object with 
			# 	the data from the input string (or nil if not a valid structure) and the second being the
			# 	left-over bytes from the string (those after the message or the entire string if no valid
			# 	message was found)
			def from_string(string)
				message = self.new
				iter = 0
				checksum = nil
				fields.each{|field|
					kind, name, size, description, options = field
					options ||= {}
					size = (kind == :variable) ? message.send(options[:length]) : size
					size *= 8 if options[:unit] == :byte
					begin
						value = FIELD_TYPES[kind][:unpack].call(string, iter, size, options)
						message.send("#{name}=", value)
						checksum = value if checksum_field && name == checksum_field[0]
					rescue StopIteration, FieldValueException => e
						return [nil, string]
					end
					iter += size
				}
				# if there's a checksum, make sure the provided one is valid
				return [nil, string] unless message.checksum == checksum if checksum_field
				[message, string[((iter/8.0).ceil)..-1]]
			end
			
			# Parses out all of the messages in a given string assuming that the first message
			# starts at the first byte, and there are no bytes between messages (though messages
			# are not allowed to span bytes; i.e., all messages must be byte-aligned).
			# @param string [String] a binary string containing the messages to be parsed
			# @return [Array<Array<Structure>, String>] a pair with the first element being an
			# 	array of messages parsed out of the string and the second being whatever part of
			# 	the string was left over after parsing.
			def parse(string)
				messages = []
				last_message = true
				while last_message
					last_message, string = from_string(string)
					puts "Found message: #{last_message.to_s.bytes.to_a}, string=#{string.bytes.to_a.inspect}"
					messages << last_message if last_message
				end
				[messages, string]
			end

			private
			def field kind, name, size, description, validator, options
				@_fields ||= []
				@_fields << [kind, name, size, description, options]
				self.class_eval do
					define_method "#{name}=" do |val|
						raise FieldValueException unless validator.call(val, size, options)
						self.instance_variable_set("@__#{name}", val)
						@_checksum_cached = false
					end
				end
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
				options ||= {}
				case kind
				when :variable
					data ||= ""
					size = options[:length] && self.send(options[:length]) ? self.send(options[:length]) : data.size
					size *= 8 if options[:unit] == :byte
					byte_iter = data.bytes
					if offset % 8 == 0
						buffer += data.bytes.to_a + [0] * (size - data.size)
					else
						size.times{|i|
							byte = byte_iter.next rescue 0
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
			buffer.pack("c*")	
		end
	end
	
end