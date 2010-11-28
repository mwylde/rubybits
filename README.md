# RubyBits

RubyBits is a library that makes dealing with binary formats easier. In
particular, it provides the Structure class, which allows for easy parsing
and creation of binary strings according to specific formats. More usage
information can be found in [the docs](http://rdoc.info/github/mwylde/rubybits/master/frames) or by looking
at the specs.

You can install via rubygems with `gem install rubybits`.

Example:

    class NECProjectorFormat < RubyBits::Structure
      unsigned :id1,     8,    "Identification data assigned to each command"
      unsigned :id2,     8,    "Identification data assigned to each command"
      unsigned :p_id,    8,    "Projector ID"
      unsigned :m_code,  4,    "Model code for projector"
      unsigned :len,     12,   "Length of data in bytes"
      variable :data,    8,    "Packet data", :length => :len, :unit => :byte
      unsigned :checksum,8,    "Checksum"

      checksum :checksum do |bytes|
        bytes[0..-2].inject{|sum, byte| sum += byte} & 255
      end
    end

    NECProjectorFormat.parse(buffer)
      => [[<NECProjectorFormat>, <NECProjectorFormat>], rest]

    NECProjectorFormat.new(:id1 => 0x44, :id2 => 2, :p_id => 0, :m_code => 0, :len => 5, :data => "hello").to_s.bytes.to_a
      => [0x44, 0x2, 0x05, 0x00, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x5F]